import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class OwnerInitializationService {
  static final List<String> _primaryOwners = [
    '+918529841981',
    '+916376139270',
    '+919928528110',
  ];

  /// One-time setup to whitelist the provided owner numbers in Firestore.
  /// This ensures they are the only ones who can log in as 'shopOwner'.
  static Future<void> seedWhitelistedOwners() async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    for (var phone in _primaryOwners) {
      final docId = phone.replaceAll('+', '');
      final ref = firestore.collection('pre_authorized_users').doc(docId);

      batch.set(ref, {
        'phoneNumber': phone,
        'role': UserRole.shopOwner.toString(),
        'name': 'Fufaji Primary Owner',
        'authorizedBy': 'system_root',
        'createdAt': FieldValue.serverTimestamp(),
        'isMfaRequired': true, // Hardening requirement
      }, SetOptions(merge: true));
    }

    try {
      await batch.commit();
      debugPrint('[OwnerInit] Successfully seeded whitelisted owner numbers.');
    } catch (e) {
      debugPrint('[OwnerInit] Error seeding owners: $e');
    }
  }
}
