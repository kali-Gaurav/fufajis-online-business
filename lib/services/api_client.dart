import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ApiResult {
  final dynamic data;
  ApiResult(this.data);
}

/// Main API Client for the Fufaji Online Business platform.
/// Handles authentication, base URL injection, and error handling.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  
  /// Factory constructor to support legacy ApiClient() calls while maintaining a singleton.
  factory ApiClient() => _instance;

  ApiClient._internal();

  /// Static access to the singleton instance.
  static ApiClient get instance => _instance;

  final http.Client _client = http.Client();

  Future<ApiResult> post(String path, [Map<String, dynamic>? data]) async {
    final baseUrl = AppConfig.apiBaseUrl;
    if (baseUrl.isEmpty) {
      throw Exception('API_BASE_URL is not configured in AppConfig.');
    }

    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$cleanPath');

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    debugPrint('[ApiClient] POST $uri');
    final response = await _client.post(
      uri,
      headers: headers,
      body: data != null ? jsonEncode(data) : null,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final responseBody = response.body;
      if (responseBody.isEmpty) {
        return ApiResult(null);
      }
      try {
        final decoded = jsonDecode(responseBody);
        // If the backend returns a wrapper { "data": ... }, return that data.
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          return ApiResult(decoded['data']);
        }
        return ApiResult(decoded);
      } catch (e) {
        return ApiResult(responseBody);
      }
    } else {
      throw Exception(
        'API Request failed with status ${response.statusCode}: ${response.body}',
      );
    }
  }

  Future<ApiResult> get(String path) async {
    final baseUrl = AppConfig.apiBaseUrl;
    if (baseUrl.isEmpty) {
      throw Exception('API_BASE_URL is not configured in AppConfig.');
    }

    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$cleanPath');

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    debugPrint('[ApiClient] GET $uri');
    final response = await _client.get(uri, headers: headers);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final responseBody = response.body;
      if (responseBody.isEmpty) {
        return ApiResult(null);
      }
      try {
        final decoded = jsonDecode(responseBody);
        // If the backend returns a wrapper { "data": ... }, return that data.
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          return ApiResult(decoded['data']);
        }
        return ApiResult(decoded);
      } catch (e) {
        return ApiResult(responseBody);
      }
    } else {
      throw Exception(
        'API Request failed with status ${response.statusCode}: ${response.body}',
      );
    }
  }
}
