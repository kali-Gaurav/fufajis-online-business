import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Step 25: Voice-Powered Product Seeding
/// Uses STT and Gemini to auto-populate product creation forms.
class VoiceProductSeedingService {
  final SpeechToText _speech = SpeechToText();

  Future<void> startVoiceSeeding(Function(String) onResult) async {
    bool available = await _speech.initialize();
    if (available) {
      _speech.listen(onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      });
    }
  }

  Future<Map<String, dynamic>> parseProductData(String voiceInput) async {
    // Logic to call Gemini API and parse voice text to JSON
    // { "name": "Apples", "price": 150, "quantity": 20 }
    return {"name": "Detected Product", "price": 0.0};
  }
}
