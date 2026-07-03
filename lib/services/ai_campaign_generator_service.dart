import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'gemini_service.dart';

class AiCampaignGeneratorService {
  static final AiCampaignGeneratorService _instance = AiCampaignGeneratorService._internal();
  factory AiCampaignGeneratorService() => _instance;
  AiCampaignGeneratorService._internal();

  /// Generates variations of campaign copy based on the goal, audience, and offer.
  Future<List<Map<String, String>>> generateCampaignCopy({
    required String goal,
    required String audience,
    required String offerDetails,
    String tone = 'Urgent and exciting',
    bool includeHindi = true,
  }) async {
    try {
      final prompt =
          '''
You are an expert growth marketer for "Fufaji", an Indian hyperlocal grocery and fast-delivery app.
I need 3 highly engaging, high-conversion push notification variations for a new marketing campaign.

Campaign Goal: $goal
Target Audience: $audience
Offer Details: $offerDetails
Tone: $tone

Requirements for each variation:
1. Title: Short, punchy, includes emojis (Max 40 chars)
2. Body: Engaging, clear CTA, highlights the value (Max 120 chars)
${includeHindi ? "3. The third variation MUST be in Hinglish (Hindi written in English alphabet) or Hindi." : ""}

Respond ONLY with a JSON array of objects. Format:
[
  { "title": "Title here 🚀", "body": "Body here! Tap to order." },
  { "title": "...", "body": "..." },
  { "title": "...", "body": "..." }
]
''';

      final responseText = await GeminiService.generateText(prompt);

      if (responseText.isNotEmpty) {
        // Simple extraction of the JSON part if the model added conversational text
        final jsonStart = responseText.indexOf('[');
        final jsonEnd = responseText.lastIndexOf(']') + 1;

        if (jsonStart != -1 && jsonEnd != -1) {
          final jsonString = responseText.substring(jsonStart, jsonEnd);
          final List<dynamic> parsedList = jsonDecode(jsonString) as List<dynamic>;
          return parsedList
              .map((e) => {'title': e['title'].toString(), 'body': e['body'].toString()})
              .toList();
        }
      }

      throw Exception("Failed to parse AI response.");
    } catch (e) {
      debugPrint('[AiCampaignGeneratorService] Error generating copy: $e');
      // Fallback
      return [
        {
          'title': 'Flash Deal Inside! ⚡',
          'body': 'Open now to claim your exclusive offer. Valid for a limited time only.',
        },
        {
          'title': '🛒 Stock up & Save',
          'body': 'Your favorite items are on sale. Tap to view deals tailored for you.',
        },
        {
          'title': 'Offer Miss Mat Karna! 🎁',
          'body': 'Khaas aapke liye zabardast deals. Abhi order karein aur bachat paayein!',
        },
      ];
    }
  }

  /// Suggests the best audience segment based on the offer
  Future<List<String>> suggestAudienceSegment(String offerDetails) async {
    try {
      final prompt =
          '''
You are an expert growth marketer. Based on this offer: "$offerDetails"
Which of these customer segments is BEST to target? Pick up to 2.
Available segments: ["all", "vip", "dormant", "new", "heavy_spenders", "deal_hunters"]

Respond ONLY with a JSON array of strings. Example: ["vip", "heavy_spenders"]
''';

      final responseText = await GeminiService.generateText(prompt);
      if (responseText.isNotEmpty) {
        final jsonStart = responseText.indexOf('[');
        final jsonEnd = responseText.lastIndexOf(']') + 1;
        if (jsonStart != -1 && jsonEnd != -1) {
          final List<dynamic> parsedList =
              jsonDecode(responseText.substring(jsonStart, jsonEnd)) as List<dynamic>;
          return parsedList.map((e) => e.toString()).toList();
        }
      }
      return ['all'];
    } catch (e) {
      return ['all'];
    }
  }
}
