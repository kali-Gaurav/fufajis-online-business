import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import '../utils/app_theme.dart';

class VoiceSearchDialog extends StatefulWidget {
  const VoiceSearchDialog({super.key});

  @override
  State<VoiceSearchDialog> createState() => _VoiceSearchDialogState();
}

class _VoiceSearchDialogState extends State<VoiceSearchDialog> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = 'Listening...';
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _startListening();
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('STT Status: $status');
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          if (_lastWords.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) Navigator.pop(context, _lastWords);
            });
          }
        }
      },
      onError: (error) => debugPrint('STT Error: $error'),
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          setState(() {
            _lastWords = result.recognizedWords;
            _text = _lastWords;
          });
        },
        localeId: 'hi_IN', // Set to Hindi for Fufaji's audience
      );
    } else {
      setState(() {
        _isListening = false;
        _text = "Voice search unavailable";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'बोलिए...',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Speak now to search products',
              style: TextStyle(fontSize: 14, color: AppTheme.grey600),
            ),
            const SizedBox(height: 40),
            Material(
              elevation: _isListening ? 12.0 : 4.0,
              shape: const CircleBorder(),
              child: CircleAvatar(
                backgroundColor: _isListening
                    ? AppTheme.primary
                    : AppTheme.grey300,
                radius: _isListening ? 45 : 40,
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.grey800,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
