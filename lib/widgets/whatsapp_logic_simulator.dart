import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../utils/app_theme.dart';

class WhatsAppLogicSimulator extends StatefulWidget {
  const WhatsAppLogicSimulator({super.key});

  @override
  State<WhatsAppLogicSimulator> createState() => _WhatsAppLogicSimulatorState();
}

class _WhatsAppLogicSimulatorState extends State<WhatsAppLogicSimulator> {
  final TextEditingController _messageController = TextEditingController();
  String _response = '';
  bool _isProcessing = false;

  Future<void> _simulate() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
      _response = 'Processing command...';
    });

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final result = await productProvider.processWhatsAppMessage(_messageController.text);

    setState(() {
      _response = result;
      _isProcessing = false;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WhatsApp Command Simulator',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Simulate how your shop responds to WhatsApp messages.',
              style: TextStyle(fontSize: 12, color: AppTheme.grey600),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. ADD 20 apples 150\nUPDATE potato 50\nDELETE banana',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _simulate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Send Message'),
              ),
            ),
            if (_response.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Shop Response:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _response,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void showWhatsAppSimulator(BuildContext context) {
  showDialog(context: context, builder: (context) => const WhatsAppLogicSimulator());
}
