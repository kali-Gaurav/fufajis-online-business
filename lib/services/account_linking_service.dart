import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountLinkResult {
  final bool linked;
  final bool merged;
  final String primaryUid;

  AccountLinkResult({
    required this.linked,
    required this.merged,
    required this.primaryUid,
  });
}

class AccountLinkingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> checkPhoneExists(String phone) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phone)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> checkEmailExists(String email) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<AccountLinkResult> linkCredentials(User user, AuthCredential credential) async {
    try {
      final updatedUser = await user.linkWithCredential(credential);
      
      // Update linked providers list in firestore
      final List<String> providers = updatedUser.user?.providerData.map((e) => e.providerId).toList() ?? ['phone'];
      
      await _firestore.collection('users').doc(user.uid).update({
        'linkedProviders': providers,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return AccountLinkResult(
        linked: true,
        merged: false,
        primaryUid: user.uid,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        // We need to merge accounts manually if already in use, or handle it in UI
        return AccountLinkResult(
          linked: false,
          merged: false,
          primaryUid: user.uid,
        );
      }
      rethrow;
    }
  }

  // Merges secondaryUid data into primaryUid and deletes secondaryUid
  Future<void> mergeAccounts(String primaryUid, String secondaryUid) async {
    // 1. Move orders
    final ordersSnapshot = await _firestore.collection('orders').where('customerId', isEqualTo: secondaryUid).get();
    for (var doc in ordersSnapshot.docs) {
      await doc.reference.update({'customerId': primaryUid});
    }

    // 2. Transfer wallet balance & points
    final primaryDoc = await _firestore.collection('users').doc(primaryUid).get();
    final secondaryDoc = await _firestore.collection('users').doc(secondaryUid).get();

    if (primaryDoc.exists && secondaryDoc.exists) {
      final pData = primaryDoc.data()!;
      final sData = secondaryDoc.data()!;
      
      final pWallet = (pData['walletBalance'] ?? 0.0).toDouble();
      final sWallet = (sData['walletBalance'] ?? 0.0).toDouble();
      
      final pPoints = pData['rewardPoints'] ?? 0;
      final sPoints = sData['rewardPoints'] ?? 0;

      await primaryDoc.reference.update({
        'walletBalance': pWallet + sWallet,
        'rewardPoints': pPoints + sPoints,
      });
    }

    // 3. Delete secondary account document
    await _firestore.collection('users').doc(secondaryUid).delete();
  }
}
