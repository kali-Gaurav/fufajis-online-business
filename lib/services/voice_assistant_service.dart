import 'package:flutter/material.dart';
import 'package:fufajis_online/services/voice_command_executor.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'voice_command_service.dart';

/// High-end Voice Assistant Service for Fufaji Online.
/// Handles Speech-to-Text (STT), Natural Language Understanding (NLU),
/// Command Execution, and Text-to-Speech (TTS) feedback.
class VoiceAssistantService extends ChangeNotifier {
  static final VoiceAssistantService _instance = VoiceAssistantService._internal();
  factory VoiceAssistantService() => _instance;
  VoiceAssistantService._internal() {
    _initSTT();
    _initTTS();
  }

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final VoiceCommandService _commandService = VoiceCommandService();

  bool _isListening = false;
  String _lastWords = '';
  String _statusMessage = 'Speak now...';
  bool _isInitialized = false;

  bool get isListening => _isListening;
  String get lastWords => _lastWords;
  String get statusMessage => _statusMessage;

  Future<void> _initSTT() async {
    _isInitialized = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          _isListening = false;
          notifyListeners();
        }
      },
      onError: (error) {
        _statusMessage = 'Error: ${error.errorMsg}';
        _isListening = false;
        notifyListeners();
      },
    );
  }

  Future<void> _initTTS() async {
    await _tts.setLanguage("hi-IN"); // Hindi (India)
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _tts.speak(text);
  }

  Future<void> startListening({required BuildContext context}) async {
    if (!_isInitialized) await _initSTT();

    if (_isInitialized) {
      _isListening = true;
      _lastWords = '';
      _statusMessage = 'Listening...';
      notifyListeners();

      await _speech.listen(
        onResult: (result) async {
          _lastWords = result.recognizedWords;
          if (result.finalResult) {
            _isListening = false;
            _statusMessage = 'Processing...';
            notifyListeners();
            await _processSpeech(_lastWords, context);
          } else {
            notifyListeners();
          }
        },
        localeId: 'hi_IN',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      );
    }
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _isListening = false;
    notifyListeners();
  }

  Future<void> _processSpeech(String text, BuildContext context) async {
    if (text.trim().isEmpty) {
      _statusMessage = 'Say something...';
      notifyListeners();
      return;
    }

    try {
      // Parse the command
      final command = await _commandService.parse(text);

      if (command.type == VoiceCommandType.unknown) {
        _statusMessage = 'Samajh nahi aaya: "$text"';
        await speak("Maaf kijiye, mujhe samajh nahi aaya. Phir se boliye.");
        notifyListeners();
        return;
      }

      _statusMessage = command.confirmationText;
      notifyListeners();

      // Execute the command
      final response = await VoiceCommandExecutor.execute(command, context);

      // Give voice feedback
      await speak(response);

      _statusMessage = response;
      notifyListeners();

      // Close dialog or reset after success
      Future.delayed(const Duration(seconds: 2), () {
        _lastWords = '';
        _statusMessage = 'Ready';
        notifyListeners();
      });
    } catch (e) {
      _statusMessage = 'Error: $e';
      await speak("Kuch galati ho gayi. Phir se koshish karein.");
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}
