import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/khata_transaction.dart';

class KhataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Adds a credit entry (customer owes more) or a payment entry (customer paid back)
  Future<void> addKhataTransaction(KhataTransaction tx) async {
    final userRef = _db.collection('users').doc(tx.userId);
    
    await _db.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw Exception('User not found');

      final currentBalance = (userDoc.data()?['creditBalance'] ?? 0.0).toDouble();
      double newBalance = currentBalance;

      if (tx.type == KhataTransactionType.credit) {
        newBalance += tx.amount;
      } else {
        newBalance -= tx.amount;
      }

      // Update balance
      transaction.update(userRef, {'creditBalance': newBalance});

      // Record transaction
      final txRef = _db.collection('khata_transactions').doc(tx.id);
      transaction.set(txRef, tx.toMap());
    });
  }

  Stream<List<KhataTransaction>> getCustomerKhataStream(String userId) {
    return _db.collection('khata_transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => KhataTransaction.fromMap(doc.data())).toList());
  }

  Future<double> getCustomerTotalCredit(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return (doc.data()?['creditBalance'] ?? 0.0).toDouble();
  }
}
