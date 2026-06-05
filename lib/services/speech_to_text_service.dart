import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/foundation.dart';

class SpeechToTextService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  String _lastRecognizedWords = '';
  
  // Available Locales
  static const String localeHindi = 'hi_IN';
  static const String localeEnglish = 'en_IN';
  
  String _currentLocale = localeHindi;
  String get currentLocale => _currentLocale;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) => debugPrint('STT Error: $error'),
      onStatus: (status) => debugPrint('STT Status: $status'),
    );
    return _isInitialized;
  }
  
  void setLocale(String locale) {
    _currentLocale = locale;
  }

  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onError,
    String? overrideLocale,
  }) async {
    final available = await initialize();
    if (available) {
      _lastRecognizedWords = '';
      
      final localeId = overrideLocale ?? _currentLocale;
      debugPrint('[STT] Listening with locale: $localeId');
      
      await _speech.listen(
        onResult: (result) {
          _lastRecognizedWords = result.recognizedWords;
          onResult(result.recognizedWords);
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
        localeId: localeId,
      );
    } else {
      onError('Speech recognition not available');
    }
  }

  Future<String> stopListening() async {
    await _speech.stop();
    return _lastRecognizedWords;
  }

  bool get isListening => _speech.isListening;
}
