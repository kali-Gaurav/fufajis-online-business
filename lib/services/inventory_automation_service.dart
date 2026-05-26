import 'package:cloud_firestore/cloud_firestore.dart';

/// Step 28: Low Stock Predictive Alerts
class InventoryAutomationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> checkAndAlertLowStock() async {
    final products = await _firestore.collection('products').where('stockQuantity', isLessThan: 5).get();
    for (var doc in products.docs) {
      // Trigger Notification to Owner
      print('Alert: ${doc['name']} is low on stock');
    }
  }
}
