import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/foundation.dart';

/// SpeechToTextService — thin wrapper over the `speech_to_text` plugin tuned
/// for Fufaji's voice ordering.
///
/// Key capabilities:
///   • Live partial results (real-time transcription as the user speaks)
///   • Long-form dictation mode for long product lists (extended listen/pause)
///   • Hindi (hi_IN) default with English (en_IN) switch — Hinglish friendly
///   • Robust error handling with timeout protection
///   • Automatic locale detection and validation
///
/// Public API is kept backward-compatible with existing callers
/// (voice_command_fab, voice_search_dialog, voice_product_add_screen, etc.).
class SpeechToTextService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  String _lastRecognizedWords = '';
  String? _lastError;
  List<String> _availableLocales = [];

  // Available Locales
  static const String localeHindi = 'hi_IN';
  static const String localeEnglish = 'en_IN';

  // Timeout constants
  static const Duration initializeTimeout = Duration(seconds: 10);

  String _currentLocale = localeHindi;
  String get currentLocale => _currentLocale;
  String? get lastError => _lastError;

  bool get isAvailable => _isInitialized;
  bool get isListening => _speech.isListening;

  /// Initialize speech recognition with timeout protection.
  /// Returns true if initialized successfully, false otherwise.
  /// If initialization fails, check [lastError] for details.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _lastError = null;
      final initialized = await _speech
          .initialize(
            onError: (error) =>
                _lastError = '[STT Error] ${error.errorMsg}',
            onStatus: (status) =>
                debugPrint('[STT] Status: $status'),
          )
          .timeout(
            initializeTimeout,
            onTimeout: () {
              _lastError = 'Speech recognition initialization timed out';
              debugPrint(_lastError!);
              return false;
            },
          );

      _isInitialized = initialized;

      // Pre-fetch available locales for later validation
      if (_isInitialized) {
        try {
          final locales = await _speech.locales();
          _availableLocales = locales.map((l) => l.localeId).toList();
          debugPrint('[STT] Available locales: $_availableLocales');
        } catch (e) {
          debugPrint('[STT] Failed to fetch locales: $e');
        }
      } else if (_lastError == null) {
        _lastError = 'Speech recognition not available on this device';
        debugPrint(_lastError!);
      }

      return _isInitialized;
    } catch (e) {
      _lastError = 'Speech initialization exception: $e';
      debugPrint(_lastError!);
      _isInitialized = false;
      return false;
    }
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

  /// Start listening with robust error handling.
  ///
  /// [onResult] fires once with the FINAL transcript.
  /// [onPartialResult] fires repeatedly with the LIVE (in-progress) transcript —
  /// drive your on-screen live transcription from this.
  /// [continuous] / [longForm] extend the listen + pause windows so a user can
  /// dictate a long list ("do kilo aloo, paanch pyaaz, ek packet doodh ...")
  /// without the recognizer cutting off mid-sentence.
  /// [overrideLocale] lets you request a specific locale; falls back to current
  /// locale if requested one isn't available.
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
      final error = _lastError ?? 'Speech recognition not available';
      debugPrint('[STT] Cannot start listening: $error');
      onError?.call(error);
      return;
    }

    _lastRecognizedWords = '';
    var localeId = overrideLocale ?? _currentLocale;

    // Validate locale is available; fallback if not
    if (_availableLocales.isNotEmpty && !_availableLocales.contains(localeId)) {
      debugPrint('[STT] Locale $localeId not available. Available: $_availableLocales');
      // Fallback: try English if Hindi isn't available
      if (_availableLocales.contains(localeEnglish)) {
        localeId = localeEnglish;
        debugPrint('[STT] Falling back to English');
      } else if (_availableLocales.isNotEmpty) {
        localeId = _availableLocales.first;
        debugPrint('[STT] Falling back to ${_availableLocales.first}');
      }
    }

    final extended = continuous || longForm;
    debugPrint('[STT] Starting listen: locale=$localeId extended=$extended');

    try {
      await _speech.listen(
        onResult: (result) {
          _lastRecognizedWords = result.recognizedWords;
          if (result.finalResult) {
            debugPrint('[STT] Final result: "$_lastRecognizedWords"');
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
      _lastError = '[STT] Listen exception: $e';
      debugPrint(_lastError!);
      onError?.call(_lastError!);
    }
  }

  /// Stop and return the best transcript captured so far.
  Future<String> stopListening() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
        debugPrint('[STT] Stopped listening');
      }
    } catch (e) {
      _lastError = '[STT] Stop exception: $e';
      debugPrint(_lastError!);
    }
    return _lastRecognizedWords;
  }

  /// Cancel without returning a result.
  Future<void> cancel() async {
    try {
      if (_speech.isListening) {
        await _speech.cancel();
        debugPrint('[STT] Cancelled listening');
      }
    } catch (e) {
      _lastError = '[STT] Cancel exception: $e';
      debugPrint(_lastError!);
    }
  }

  /// Reset the service (useful for testing or after errors).
  void reset() {
    _isInitialized = false;
    _lastRecognizedWords = '';
    _lastError = null;
    _availableLocales = [];
    _currentLocale = localeHindi;
    debugPrint('[STT] Service reset');
  }
}
