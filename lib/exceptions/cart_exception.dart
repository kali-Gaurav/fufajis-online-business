/// Exception thrown during cart operations
class CartException implements Exception {
  final String message;
  final dynamic originalError;

  CartException(this.message, {this.originalError});

  @override
  String toString() => 'CartException: $message';
}
