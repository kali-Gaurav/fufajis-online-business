import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/gemini_service.dart';
import '../providers/product_provider.dart';
import '../models/product_model.dart';
import '../utils/app_theme.dart';

class VoiceToStockDialog extends StatefulWidget {
  const VoiceToStockDialog({super.key});

  @override
  State<VoiceToStockDialog> createState() => _VoiceToStockDialogState();
}

class _VoiceToStockDialogState extends State<VoiceToStockDialog> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _text = 'Hold to speak (e.g. "Add 10kg apples at 150 rupees")';
  bool _isProcessing = false;

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) => setState(() => _text = val.recognizedWords));
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _processCommand();
    }
  }

  Future<void> _processCommand() async {
    if (_text.isEmpty || _text.contains('Hold to speak')) return;

    setState(() => _isProcessing = true);
    try {
      final gemini = GeminiService();
      final command = await gemini.parseVoiceInventoryCommand(_text);

      if (command != null && mounted) {
        final provider = Provider.of<ProductProvider>(context, listen: false);
        
        if (command['action'] == 'ADD') {
          final product = ProductModel(
            id: 'prod_voice_${DateTime.now().millisecondsSinceEpoch}',
            name: command['name'],
            description: "Added via Voice",
            price: (command['price'] as num).toDouble(),
            unit: command['unit'] ?? 'unit',
            category: 'other',
            shopId: provider.currentShopId ?? 'shop_001',
            shopName: "Fufaji's Online",
            imageUrl: '',
            stockQuantity: (command['quantity'] as num).toInt(),
            district: 'Jaipur',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await provider.addProduct(product);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Inventory updated: ${command['action']} ${command['name']}'), backgroundColor: AppTheme.success),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2, color: AppTheme.primary, size: 48),
            const SizedBox(height: 16),
            const Text('Voice Inventory Entry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            GestureDetector(
              onLongPress: _listen,
              onLongPressUp: _listen,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: _isListening ? Colors.red : AppTheme.primary,
                child: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 24),
            Text(_text, textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic)),
            if (_isProcessing) const Padding(padding: EdgeInsets.only(top: 24), child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
