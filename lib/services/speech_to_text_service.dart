import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/foundation.dart';

/// SpeechToTextService — thin wrapper over the `speech_to_text` plugin tuned
/// for Fufaji's voice ordering.
///
/// Key capabilities:
///   • Live partial results (real-time transcription as the user speaks)
///   • Long-form dictation mode for long product lists (extended listen/pause)
///   • Hindi (hi_IN) default with English (en_IN) switch — Hinglish friendly
///
/// Public API is kept backward-compatible with existing callers
/// (voice_command_fab, voice_search_dialog, voice_product_add_screen, etc.).
class SpeechToTextService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  String _lastRecognizedWords = '';

  // Available Locales
  static const String localeHindi = 'hi_IN';
  static const String localeEnglish = 'en_IN';

  String _currentLocale = localeHindi;
  String get currentLocale => _currentLocale;

  bool get isAvailable => _isInitialized;
  bool get isListening => _speech.isListening;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) => debugPrint('[STT] Error: ${error.errorMsg}'),
      onStatus: (status) => debugPrint('[STT] Status: $status'),
    );
    return _isInitialized;
  }

  void setLocale(String locale) {
    _currentLocale = locale;
  }

  /// Returns installed locale ids (e.g. ['hi_IN','en_IN']) — useful to verify
  /// the device actually supports Hindi dictation.
  Future<List<String>> availableLocales() async {
    await initialize();
    final locales = await _speech.locales();
    return locales.map((l) => l.localeId).toList();
  }

  /// Start listening.
  ///
  /// [onResult] fires once with the FINAL transcript.
  /// [onPartialResult] fires repeatedly with the LIVE (in-progress) transcript —
  /// drive your on-screen live transcription from this.
  /// [continuous] / [longForm] extend the listen + pause windows so a user can
  /// dictate a long list ("do kilo aloo, paanch pyaaz, ek packet doodh ...")
  /// without the recognizer cutting off mid-sentence.
  Future<void> startListening({
    required Function(String) onResult,
    Function(String)? onPartialResult,
    Function(String)? onError,
    String? overrideLocale,
    bool continuous = false,
    bool longForm = false,
  }) async {
    final available = await initialize();
    if (!available) {
      onError?.call('Speech recognition not available');
      return;
    }

    _lastRecognizedWords = '';
    final localeId = overrideLocale ?? _currentLocale;
    final extended = continuous || longForm;
    debugPrint('[STT] Listening locale=$localeId extended=$extended');

    try {
      await _speech.listen(
        onResult: (result) {
          _lastRecognizedWords = result.recognizedWords;
          if (result.finalResult) {
            onResult(result.recognizedWords);
          } else {
            onPartialResult?.call(result.recognizedWords);
          }
        },
        // Long lists need a generous window; short commands stay snappy.
        listenFor: Duration(seconds: extended ? 120 : 30),
        pauseFor: Duration(seconds: extended ? 6 : 4),
        localeId: localeId,
        // ignore: deprecated_member_use
        partialResults: true,
        // ignore: deprecated_member_use
        cancelOnError: true,
        // ignore: deprecated_member_use
        listenMode: extended ? ListenMode.dictation : ListenMode.confirmation,
      );
    } catch (e) {
      debugPrint('[STT] listen exception: $e');
      onError?.call('$e');
    }
  }

  /// Stop and return the best transcript captured so far.
  Future<String> stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('[STT] stop exception: $e');
    }
    return _lastRecognizedWords;
  }

  /// Cancel without returning a result.
  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (e) {
      debugPrint('[STT] cancel exception: $e');
    }
  }
}
