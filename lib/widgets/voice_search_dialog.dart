import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_assistant_service.dart';
import '../utils/app_theme.dart';

class VoiceSearchDialog extends StatefulWidget {
  const VoiceSearchDialog({super.key});

  @override
  State<VoiceSearchDialog> createState() => _VoiceSearchDialogState();
}

class _VoiceSearchDialogState extends State<VoiceSearchDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late VoiceAssistantService _voiceService;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();

    // Start listening automatically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voiceService = VoiceAssistantService();
      _voiceService.startListening(context: context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: VoiceAssistantService(),
      child: Consumer<VoiceAssistantService>(
        builder: (context, voiceService, child) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Fufaji Voice',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.grey400),
                        onPressed: () {
                          voiceService.stopListening();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildAnimatedMic(voiceService.isListening),
                  const SizedBox(height: 30),
                  Text(
                    voiceService.statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: voiceService.isListening ? AppTheme.primary : AppTheme.grey800,
                    ),
                  ),
                  if (voiceService.lastWords.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.grey100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '"${voiceService.lastWords}"',
                        style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                  const Text(
                    'Try: "Aloo add karo" or "Revenue batao"',
                    style: TextStyle(fontSize: 12, color: AppTheme.grey400),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedMic(bool isListening) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (isListening)
              ...List.generate(3, (index) {
                final double progress = (_controller.value + index / 3) % 1.0;
                return Container(
                  width: 80 + (progress * 80),
                  height: 80 + (progress * 80),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(1.0 - progress),
                      width: 2,
                    ),
                  ),
                );
              }),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isListening ? AppTheme.primary : AppTheme.grey300,
                shape: BoxShape.circle,
                boxShadow: [
                  if (isListening)
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Icon(isListening ? Icons.mic : Icons.mic_none, size: 40, color: Colors.white),
            ),
          ],
        );
      },
    );
  }
}
