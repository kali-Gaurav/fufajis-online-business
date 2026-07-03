/// Base Exception class for all application errors
abstract class AppException implements Exception {
  final String message;
  final String code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException(this.message, this.code, {this.originalError, this.stackTrace});

  @override
  String toString() => '$runtimeType[$code]: $message';
}

/// Thrown when input validation fails
class ValidationError extends AppException {
  ValidationError(String message, {super.originalError, super.stackTrace})
    : super(message, 'VALIDATION_ERROR');
}

/// Thrown when a user lacks required permissions
class PermissionError extends AppException {
  PermissionError(String message, {super.originalError, super.stackTrace})
    : super(message, 'PERMISSION_DENIED');
}

/// Thrown when network connectivity fails or timeouts occur
class NetworkError extends AppException {
  NetworkError(String message, {super.originalError, super.stackTrace})
    : super(message, 'NETWORK_ERROR');
}

/// Thrown for database operations (Firestore, Postgres, SQLite)
class DatabaseError extends AppException {
  DatabaseError(String message, {super.originalError, super.stackTrace})
    : super(message, 'DATABASE_ERROR');
}

/// Thrown for Cloud Storage or local file operations
class StorageError extends AppException {
  StorageError(String message, {super.originalError, super.stackTrace})
    : super(message, 'STORAGE_ERROR');
}

/// Thrown for AI service failures (Bedrock, Gemini)
class AIError extends AppException {
  AIError(String message, {super.originalError, super.stackTrace})
    : super(message, 'AI_SERVICE_ERROR');
}

/// Thrown during payment gateway interactions
class PaymentError extends AppException {
  PaymentError(String message, {super.originalError, super.stackTrace})
    : super(message, 'PAYMENT_ERROR');
}

/// Thrown when a service circuit breaker is open
class CircuitBreakerOpenError extends AppException {
  final String serviceName;
  CircuitBreakerOpenError(this.serviceName, String message, {super.originalError, super.stackTrace})
    : super(message, 'CIRCUIT_OPEN');
}

/// Helper to map raw exceptions to domain exceptions
class ErrorMapper {
  static AppException map(dynamic error, StackTrace? stackTrace) {
    if (error is AppException) return error;

    final errStr = error.toString().toLowerCase();

    if (errStr.contains('permission-denied') || errStr.contains('unauthorized')) {
      return PermissionError(error.toString(), originalError: error, stackTrace: stackTrace);
    }

    if (errStr.contains('network') || errStr.contains('socket') || errStr.contains('timeout')) {
      return NetworkError(
        'Network connectivity issue',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errStr.contains('firestore') || errStr.contains('postgres') || errStr.contains('sqlite')) {
      return DatabaseError(
        'Database operation failed',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Default fallback
    return AppExceptionWrapper(
      'An unexpected error occurred: ${error.toString()}',
      originalError: error,
      stackTrace: stackTrace,
    );
  }
}

class AppExceptionWrapper extends AppException {
  AppExceptionWrapper(String message, {super.originalError, super.stackTrace})
    : super(message, 'UNKNOWN_ERROR');
}
