import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/gemini_service.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../utils/app_theme.dart';

class OneClickVoiceOrder extends StatefulWidget {
  const OneClickVoiceOrder({super.key});

  @override
  State<OneClickVoiceOrder> createState() => _OneClickVoiceOrderState();
}

class _OneClickVoiceOrderState extends State<OneClickVoiceOrder> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _text = 'Tap or Hold to Speak your order...';
  bool _isProcessing = false;

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => debugPrint('onStatus: $val'),
        onError: (val) => debugPrint('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _processOrder();
    }
  }

  Future<void> _processOrder() async {
    if (_text.isEmpty || _text == 'Tap or Hold to Speak your order...') return;

    setState(() => _isProcessing = true);

    try {
      final gemini = GeminiService();
      final items = await gemini.parseOneClickOrder(_text);

      if (mounted) {
        final cart = Provider.of<CartProvider>(context, listen: false);
        final products = Provider.of<ProductProvider>(context, listen: false).products;

        await cart.bulkAddByVoice(items, products);

        if (mounted) {
          // Click 2: Review and book the order (Go to Fast Checkout)
          Navigator.pop(context); // Close bottom sheet
          context.push('/customer/checkout');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing order: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showHowItWorks(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fastest 3-Step Process'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepRow('1', 'Say it: "2kg aloo, 1L milk..."'),
            const SizedBox(height: 12),
            _buildStepRow('2', 'Review Summary & Address'),
            const SizedBox(height: 12),
            _buildStepRow('3', 'Place Order!'),
            const SizedBox(height: 24),
            const Text(
              'No need to search, filter, or add to cart manually. Fufaji\'s AI does it all for you.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it!')),
        ],
      ),
    );
  }

  Widget _buildStepRow(String step, String text) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppTheme.primaryColor,
          child: Text(
            step,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Fufaji's Quick Order",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showHowItWorks(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Just say what you need",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.help_outline, size: 14, color: AppTheme.primaryColor),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (_isProcessing)
            const Column(
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                SizedBox(height: 16),
                Text(
                  "AI is adding items to your cart...",
                  style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w500),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: _listen,
              onLongPress: _listen,
              onLongPressUp: _listen,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _isListening
                      ? AppTheme.error.withOpacity(0.1)
                      : AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isListening ? AppTheme.error : AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  _isListening ? Icons.stop : Icons.mic,
                  size: 64,
                  color: _isListening ? AppTheme.error : AppTheme.primaryColor,
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            _text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontStyle: _isListening ? FontStyle.normal : FontStyle.italic,
              color: _isListening ? Colors.black87 : Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _text != 'Tap or Hold to Speak your order...' ? _processOrder : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Add to Cart', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

void showOneClickOrder(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const OneClickVoiceOrder(),
  );
}
