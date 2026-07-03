/// Payment result model for handling payment outcomes
class PaymentResult {
  final PaymentStatus status;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? errorCode;
  final String? errorMessage;
  final String? walletName;
  final DateTime? timestamp;

  PaymentResult({
    required this.status,
    this.paymentId,
    this.orderId,
    this.signature,
    this.errorCode,
    this.errorMessage,
    this.walletName,
    this.timestamp,
  });

  /// Creates a successful payment result
  factory PaymentResult.success({required String paymentId, String? orderId, String? signature}) {
    return PaymentResult(
      status: PaymentStatus.success,
      paymentId: paymentId,
      orderId: orderId,
      signature: signature,
      timestamp: DateTime.now(),
    );
  }

  /// Creates a failed payment result
  factory PaymentResult.failed({
    required String errorCode,
    required String errorMessage,
    String? orderId,
  }) {
    return PaymentResult(
      status: PaymentStatus.failed,
      errorCode: errorCode,
      errorMessage: errorMessage,
      orderId: orderId,
      timestamp: DateTime.now(),
    );
  }

  /// Creates a cancelled payment result
  factory PaymentResult.cancelled({String? orderId}) {
    return PaymentResult(
      status: PaymentStatus.cancelled,
      orderId: orderId,
      timestamp: DateTime.now(),
    );
  }

  /// Creates an external wallet result
  factory PaymentResult.externalWallet({required String walletName, String? orderId}) {
    return PaymentResult(
      status: PaymentStatus.externalWallet,
      walletName: walletName,
      orderId: orderId,
      timestamp: DateTime.now(),
    );
  }

  /// Converts to map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'status': status.toString(),
      'paymentId': paymentId,
      'orderId': orderId,
      'signature': signature,
      'errorCode': errorCode,
      'errorMessage': errorMessage,
      'walletName': walletName,
      'timestamp': timestamp?.toIso8601String(),
    };
  }

  /// Creates from map (Firestore document)
  factory PaymentResult.fromMap(Map<String, dynamic> map) {
    return PaymentResult(
      status: PaymentStatus.values.firstWhere(
        (e) => e.toString() == map['status'] as String?,
        orElse: () => PaymentStatus.unknown,
      ),
      paymentId: map['paymentId'] as String?,
      orderId: map['orderId'] as String?,
      signature: map['signature'] as String?,
      errorCode: map['errorCode'] as String?,
      errorMessage: map['errorMessage'] as String?,
      walletName: map['walletName'] as String?,
      timestamp: map['timestamp'] != null ? DateTime.tryParse(map['timestamp'] as String) : null,
    );
  }

  /// Check if payment was successful
  bool get isSuccess => status == PaymentStatus.success;

  /// Check if payment failed
  bool get isFailed => status == PaymentStatus.failed;

  /// Check if payment was cancelled
  bool get isCancelled => status == PaymentStatus.cancelled;

  /// Check if external wallet was selected
  bool get isExternalWallet => status == PaymentStatus.externalWallet;

  @override
  String toString() {
    return 'PaymentResult(status: $status, paymentId: $paymentId, orderId: $orderId, error: $errorMessage)';
  }
}

/// Payment status enum
enum PaymentStatus { success, failed, cancelled, externalWallet, unknown }
