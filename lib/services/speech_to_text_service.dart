import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/foundation.dart';

class SpeechToTextService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) => debugPrint('STT Error: $error'),
      onStatus: (status) => debugPrint('STT Status: $status'),
    );
    return _isInitialized;
  }

  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onError,
  }) async {
    final available = await initialize();
    if (available) {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
    } else {
      onError('Speech recognition not available');
    }
  }

  Future<String> stopListening() async {
    await _speech.stop();
    return ''; // SpeechToText usually provides results via callback
  }

  bool get isListening => _speech.isListening;
}
