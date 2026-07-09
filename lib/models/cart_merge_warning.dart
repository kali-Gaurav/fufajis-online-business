/// Warning for items capped during cart merge due to insufficient stock
class CartMergeWarning {
  final String productId;
  final String productName;
  final int requestedQuantity;
  final int approvedQuantity;
  final int availableStock;

  CartMergeWarning({
    required this.productId,
    required this.productName,
    required this.requestedQuantity,
    required this.approvedQuantity,
    required this.availableStock,
  });

  /// How many items were removed due to stock limit
  int get itemsRemoved => requestedQuantity - approvedQuantity;

  /// Human-readable warning message
  String get message {
    return '$productName: You wanted $requestedQuantity but only $availableStock are available. '
        'Cart adjusted to $approvedQuantity.';
  }

  @override
  String toString() => message;
}
