import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/cart_item.dart';
import 'logging_service.dart';

/// Backend Inventory Service
/// Handles all inventory operations via Supabase Edge Functions
/// Implements atomic operations: reserve, confirm, cancel
class BackendInventoryService {
  // Supabase Edge Function URLs
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'https://your-project.supabase.co');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
      defaultValue: ''); // Use auth token from Firebase

  static const Duration apiTimeout = Duration(seconds: 30);

  final http.Client _httpClient;

  BackendInventoryService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Reserve inventory for checkout
  /// Returns reservation ID if successful
  /// Throws exception if insufficient stock
  Future<String> reserveInventory({
    required String productId,
    required int quantity,
    required String orderSessionId,
    String? userId,
  }) async {
    try {
      final url = Uri.parse('$supabaseUrl/functions/v1/reserve-inventory');

      final response = await _httpClient
          .post(
            url,
            headers: _getHeaders(),
            body: jsonEncode({
              'productId': productId,
              'quantity': quantity,
              'orderSessionId': orderSessionId,
              'userId': userId,
            }),
          )
          .timeout(apiTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        LoggingService.info(
          'BackendInventoryService: Reserve successful',
          data: {
            'productId': productId,
            'quantity': quantity,
            'reservationId': data['reservationId'],
          },
        );
        return data['reservationId'] as String;
      }

      // Handle specific error codes
      final errorCode = data['errorCode'] as String?;
      if (errorCode == 'INSUFFICIENT_STOCK') {
        throw InsufficientStockException(
          productId: productId,
          requestedQuantity: quantity,
          message: data['error'] as String? ?? 'Out of stock',
        );
      } else if (errorCode == 'PRODUCT_NOT_FOUND') {
        throw ProductNotFoundException(
          productId: productId,
          message: data['error'] as String? ?? 'Product not found',
        );
      }

      throw InventoryServiceException(
        message: data['error'] as String? ?? 'Reserve failed',
        errorCode: errorCode,
        statusCode: response.statusCode,
      );
    } on InventoryServiceException {
      rethrow;
    } catch (e) {
      LoggingService.error('BackendInventoryService: Reserve error', e);
      throw InventoryServiceException(
        message: 'Failed to reserve inventory: $e',
        statusCode: 500,
      );
    }
  }

  /// Confirm reservation after payment
  /// Moves inventory from reserved to sold
  /// Idempotent: safe to call multiple times
  Future<void> confirmReservation({
    required String reservationId,
    required String orderId,
    String? userId,
  }) async {
    try {
      final url = Uri.parse('$supabaseUrl/functions/v1/confirm-inventory');

      final response = await _httpClient
          .post(
            url,
            headers: _getHeaders(),
            body: jsonEncode({
              'reservationId': reservationId,
              'orderId': orderId,
              'userId': userId,
            }),
          )
          .timeout(apiTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        LoggingService.info(
          'BackendInventoryService: Confirm successful',
          data: {'reservationId': reservationId, 'orderId': orderId},
        );
        return;
      }

      // Handle specific error codes
      final errorCode = data['errorCode'] as String?;
      if (errorCode == 'RESERVATION_EXPIRED') {
        throw ReservationExpiredException(
          reservationId: reservationId,
          message: data['error'] as String? ?? 'Reservation expired',
        );
      } else if (errorCode == 'RESERVATION_NOT_FOUND') {
        // Idempotent: treat as success
        LoggingService.info(
          'BackendInventoryService: Confirm - reservation not found (already confirmed)',
          data: {'reservationId': reservationId},
        );
        return;
      }

      throw InventoryServiceException(
        message: data['error'] as String? ?? 'Confirm failed',
        errorCode: errorCode,
        statusCode: response.statusCode,
      );
    } on InventoryServiceException {
      rethrow;
    } catch (e) {
      LoggingService.error('BackendInventoryService: Confirm error', e);
      throw InventoryServiceException(
        message: 'Failed to confirm reservation: $e',
        statusCode: 500,
      );
    }
  }

  /// Cancel reservation
  /// Returns inventory from reserved back to available
  /// Idempotent: safe to call multiple times
  Future<void> cancelReservation({
    required String reservationId,
    String? userId,
  }) async {
    try {
      final url = Uri.parse('$supabaseUrl/functions/v1/cancel-inventory');

      final response = await _httpClient
          .post(
            url,
            headers: _getHeaders(),
            body: jsonEncode({
              'reservationId': reservationId,
              'userId': userId,
            }),
          )
          .timeout(apiTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        LoggingService.info(
          'BackendInventoryService: Cancel successful',
          data: {'reservationId': reservationId},
        );
        return;
      }

      // For cancel, most errors should be treated as idempotent success
      if (response.statusCode == 404 ||
          data['errorCode'] == 'RESERVATION_NOT_FOUND') {
        LoggingService.info(
          'BackendInventoryService: Cancel - reservation not found (already cancelled)',
          data: {'reservationId': reservationId},
        );
        return;
      }

      throw InventoryServiceException(
        message: data['error'] as String? ?? 'Cancel failed',
        errorCode: data['errorCode'] as String?,
        statusCode: response.statusCode,
      );
    } on InventoryServiceException {
      rethrow;
    } catch (e) {
      LoggingService.error('BackendInventoryService: Cancel error', e);
      throw InventoryServiceException(
        message: 'Failed to cancel reservation: $e',
        statusCode: 500,
      );
    }
  }

  /// Build headers for API requests
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $anonKey',
    };
  }
}

// ============================================================================
// Custom Exceptions
// ============================================================================

class InventoryServiceException implements Exception {
  final String message;
  final String? errorCode;
  final int statusCode;

  InventoryServiceException({
    required this.message,
    this.errorCode,
    required this.statusCode,
  });

  @override
  String toString() => 'InventoryServiceException: $message (code: $errorCode)';
}

class InsufficientStockException extends InventoryServiceException {
  final String productId;
  final int requestedQuantity;

  InsufficientStockException({
    required this.productId,
    required this.requestedQuantity,
    String? message,
  }) : super(
          message: message ?? 'Insufficient stock for product $productId',
          errorCode: 'INSUFFICIENT_STOCK',
          statusCode: 409,
        );
}

class ProductNotFoundException extends InventoryServiceException {
  final String productId;

  ProductNotFoundException({
    required this.productId,
    String? message,
  }) : super(
          message: message ?? 'Product $productId not found',
          errorCode: 'PRODUCT_NOT_FOUND',
          statusCode: 404,
        );
}

class ReservationExpiredException extends InventoryServiceException {
  final String reservationId;

  ReservationExpiredException({
    required this.reservationId,
    String? message,
  }) : super(
          message: message ?? 'Reservation $reservationId has expired',
          errorCode: 'RESERVATION_EXPIRED',
          statusCode: 410,
        );
}
