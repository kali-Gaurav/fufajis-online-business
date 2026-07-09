import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/runtime_config_service.dart';

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

  Future<http.Response> _makeRequest(
      Future<http.Response> Function(Map<String, String> headers) requestFunc) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    var response = await requestFunc(headers);

    // Auto-refresh token on 401
    if (response.statusCode == 401 && user != null) {
      debugPrint('[ApiClient] 401 received, forcing token refresh...');
      final newToken = await user.getIdToken(true);
      if (newToken != null) {
        headers['Authorization'] = 'Bearer $newToken';
        response = await requestFunc(headers);
      }
    }

    return response;
  }

  Future<ApiResult> post(String path, [Map<String, dynamic>? data]) async {
    final baseUrl = RuntimeConfig.instance.apiBaseUrl;
    if (baseUrl.isEmpty) {
      throw Exception('API_BASE_URL is not configured in AppConfig.');
    }

    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$cleanPath');

    debugPrint('[ApiClient] POST $uri');
    final response = await _makeRequest((headers) => _client.post(
          uri,
          headers: headers,
          body: data != null ? jsonEncode(data) : null,
        ));

    return _processResponse(response);
  }

  Future<ApiResult> get(String path) async {
    final baseUrl = RuntimeConfig.instance.apiBaseUrl;
    if (baseUrl.isEmpty) {
      throw Exception('API_BASE_URL is not configured in AppConfig.');
    }

    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$cleanPath');

    debugPrint('[ApiClient] GET $uri');
    final response = await _makeRequest((headers) => _client.get(uri, headers: headers));

    return _processResponse(response);
  }

  Future<ApiResult> patch(String path, [Map<String, dynamic>? data]) async {
    final baseUrl = RuntimeConfig.instance.apiBaseUrl;
    if (baseUrl.isEmpty) {
      throw Exception('API_BASE_URL is not configured in AppConfig.');
    }

    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$cleanPath');

    debugPrint('[ApiClient] PATCH $uri');
    final response = await _makeRequest((headers) => _client.patch(
          uri,
          headers: headers,
          body: data != null ? jsonEncode(data) : null,
        ));

    return _processResponse(response);
  }

  Future<ApiResult> delete(String path) async {
    final baseUrl = RuntimeConfig.instance.apiBaseUrl;
    if (baseUrl.isEmpty) {
      throw Exception('API_BASE_URL is not configured in AppConfig.');
    }

    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$cleanPath');

    debugPrint('[ApiClient] DELETE $uri');
    final response = await _makeRequest((headers) => _client.delete(uri, headers: headers));

    return _processResponse(response);
  }

  ApiResult _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final responseBody = response.body;
      if (responseBody.isEmpty) {
        return ApiResult(null);
      }
      try {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          return ApiResult(decoded['data']);
        }
        return ApiResult(decoded);
      } catch (e) {
        return ApiResult(responseBody);
      }
    } else {
      throw Exception('API Request failed with status ${response.statusCode}: ${response.body}');
    }
  }
}
