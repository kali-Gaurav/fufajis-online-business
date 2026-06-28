import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class OwnerInitializationService {
  static List<String> get _primaryOwners {
    final ownersStr = const String.fromEnvironment('OWNER_PHONES', defaultValue: '');
    if (ownersStr.isEmpty) return [];
    return ownersStr.split(',').map((e) => e.trim()).toList();
  }

  /// One-time setup to whitelist the provided owner numbers in Firestore.
  /// This ensures they are the only ones who can log in as 'shopOwner'.
  static Future<void> seedWhitelistedOwners() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      debugPrint('[OwnerInit] Skipping seed: No authenticated user.');
      return;
    }

    final firestore = FirebaseFirestore.instance;
    // Only attempt if the user is likely an admin or an owner already
    // (This is still a bit loose, but better than trying as Guest)

    final batch = firestore.batch();

    for (var phone in _primaryOwners) {
      final docId = phone.replaceAll('+', '');
      final ref = firestore.collection('pre_authorized_users').doc(docId);

      batch.set(ref, {
        'phoneNumber': phone,
        'role': UserRole.owner.toString(),
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
