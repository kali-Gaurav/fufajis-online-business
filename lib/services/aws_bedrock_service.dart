import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// AWS Bedrock Service for Advanced AI capabilities and Model Redundancy.
/// Powers high-reasoning tasks and serves as a failover for Gemini.
///
/// SECURITY: The AWS Bedrock bearer token is never bundled in the app.
/// Requests are proxied through the `/ai/bedrock` Lambda route, which
/// holds the real credential server-side.
class AWSBedrockService {
  static final AWSBedrockService _instance = AWSBedrockService._internal();
  factory AWSBedrockService() => _instance;
  AWSBedrockService._internal();

  /// Always true — the server decides if Bedrock is actually configured.
  bool get isConfigured => true;

  /// High-reasoning content generation using Anthropic Claude 3 (via Bedrock)
  Future<String?> generateComplexReasoning(String prompt, {int maxTokens = 1000}) async {
    try {
      final result = await ApiClient().post('/ai/bedrock', <String, dynamic>{
        'prompt': prompt,
        'maxTokens': maxTokens,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      return data['text'] as String?;
    } catch (e) {
      debugPrint('[Bedrock] Exception: $e');
      return null;
    }
  }

  /// Specialized Bill Parsing (Failover for Gemini).
  ///
  /// Encodes the image as base64 and asks Bedrock to extract structured
  /// fields (vendor, total, date, line items) as JSON. Returns null if
  /// Bedrock is unavailable or the response isn't valid JSON.
  Future<Map<String, dynamic>?> parseComplexBill(Uint8List imageBytes) async {
    try {
      final b64 = base64Encode(imageBytes);
      final prompt =
          'You are given a base64-encoded image of a purchase bill/receipt. '
          'Extract the following as strict JSON with keys: vendor, date, total, '
          'items (array of {name, quantity, price}). Respond with JSON only.\n\n'
          'IMAGE_BASE64:$b64';

      final text = await generateComplexReasoning(prompt, maxTokens: 1500);
      if (text == null) return null;

      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;

      final jsonStr = text.substring(jsonStart, jsonEnd + 1);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[Bedrock] Bill parsing failed: $e');
      return null;
    }
  }
}
