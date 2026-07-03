import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

/// API Service for admin operations.
class AdminApiService {
  static const String _baseUrl = 'https://fufaji-backend.onrender.com/api/admin';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get ID token for authorization.
  Future<String> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AdminApiException('User not authenticated');
    }

    final idToken = await user.getIdToken();
    if (idToken == null) {
      throw AdminApiException('Failed to get ID token');
    }

    return idToken;
  }

  /// Make HTTP request with auth header.
  Future<Map<String, dynamic>> _request({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    try {
      final idToken = await _getIdToken();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      };

      Uri url = Uri.parse('$_baseUrl$endpoint');
      if (queryParams != null) {
        url = url.replace(queryParameters: queryParams);
      }

      late http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(url, headers: headers).timeout(
                const Duration(seconds: 30),
              );
          break;
        case 'POST':
          response = await http.post(
                url,
                headers: headers,
                body: json.encode(body ?? {}),
              ).timeout(
                const Duration(seconds: 30),
              );
          break;
        case 'PUT':
          response = await http.put(
                url,
                headers: headers,
                body: json.encode(body ?? {}),
              ).timeout(
                const Duration(seconds: 30),
              );
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers).timeout(
                const Duration(seconds: 30),
              );
          break;
        default:
          throw AdminApiException('Unsupported HTTP method: $method');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw AdminApiException('API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (e is AdminApiException) rethrow;
      throw AdminApiException('API call failed: $e');
    }
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    return await _request(method: 'POST', endpoint: endpoint, body: body);
  }

  Future<Map<String, dynamic>> getDashboardMetrics() async {
    return await _request(method: 'GET', endpoint: '/dashboard/metrics');
  }

  Future<Map<String, dynamic>> getProducts({
    int page = 1,
    int limit = 20,
    String? searchQuery,
    String? categoryId,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (searchQuery != null) 'search': searchQuery,
      if (categoryId != null) 'category': categoryId,
    };
    return await _request(method: 'GET', endpoint: '/products', queryParams: queryParams);
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> product) async {
    return await _request(method: 'POST', endpoint: '/products', body: product);
  }

  Future<Map<String, dynamic>> updateProduct(String productId, Map<String, dynamic> updates) async {
    return await _request(method: 'PUT', endpoint: '/products/$productId', body: updates);
  }

  Future<void> deleteProduct(String productId) async {
    await _request(method: 'DELETE', endpoint: '/products/$productId');
  }

  Future<Map<String, dynamic>> getInventory({int page = 1, int limit = 20, String? status}) async {
    final queryParams = {'page': page.toString(), 'limit': limit.toString(), if (status != null) 'status': status};
    return await _request(method: 'GET', endpoint: '/inventory', queryParams: queryParams);
  }

  Future<Map<String, dynamic>> adjustInventory({
    required String productId,
    required int quantity,
    required String reason,
    String? employeeId,
    String? orderId,
  }) async {
    return await _request(method: 'POST', endpoint: '/inventory/adjust', body: {
      'productId': productId,
      'quantity': quantity,
      'reason': reason,
      'employeeId': employeeId,
      'orderId': orderId,
    });
  }

  Future<Map<String, dynamic>> getOrders({int page = 1, int limit = 20, String? status}) async {
    final queryParams = {'page': page.toString(), 'limit': limit.toString(), if (status != null) 'status': status};
    return await _request(method: 'GET', endpoint: '/orders', queryParams: queryParams);
  }

  Future<Map<String, dynamic>> packOrder(String orderId, List<Map<String, dynamic>> items, String? employeeId) async {
    return await _request(method: 'POST', endpoint: '/orders/$orderId/pack', body: {
      'items': items,
      'employeeId': employeeId,
    });
  }

  Future<Map<String, dynamic>> getAnalytics({required String timeRange, String? metric}) async {
    final queryParams = {'timeRange': timeRange, if (metric != null) 'metric': metric};
    return await _request(method: 'GET', endpoint: '/reports/analytics', queryParams: queryParams);
  }

  Future<Map<String, dynamic>> getAuditLogs({int page = 1, int limit = 50, String? entityType, String? action}) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (entityType != null) 'entityType': entityType,
      if (action != null) 'action': action,
    };
    return await _request(method: 'GET', endpoint: '/audit-logs', queryParams: queryParams);
  }
}

class AdminApiException implements Exception {
  final String message;
  AdminApiException(this.message);
  @override
  String toString() => 'AdminApiException: $message';
}
