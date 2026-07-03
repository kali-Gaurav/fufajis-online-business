import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'supabase_service.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SupabaseService _supabase = SupabaseService();

  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // --- Users ---
  Future<void> createUser(UserModel user) async {
    try {
      // 1. Write to Firestore (Primary)
      await _db.collection('users').doc(user.id).set(user.toMap());
      debugPrint('[UserService] User created in Firestore: ${user.id}');

      // 2. Dual-write to Supabase (Secondary)
      try {
        await _supabase.createUserProfile(
          userId: user.id,
          phone: user.phoneNumber,
          email: user.email,
          name: user.name,
          role: user.role.toString().split('.').last,
          avatarUrl: user.profileImage,
        );
        debugPrint('[UserService] User dual-write to Supabase successful');
      } catch (sbErr) {
        debugPrint('[UserService] Supabase dual-write failed: $sbErr');
      }
    } catch (e) {
      debugPrint('[UserService] ERROR creating user: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('[UserService] ERROR getting user: $e');
      return null;
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      // 1. Update Firestore
      await _db.collection('users').doc(userId).update(data);

      // 2. Update Supabase
      try {
        final Map<String, dynamic> sbData = {};
        if (data.containsKey('name')) sbData['name'] = data['name'];
        if (data.containsKey('email')) sbData['email'] = data['email'];
        if (data.containsKey('phoneNumber')) sbData['phone'] = data['phoneNumber'];
        if (data.containsKey('profileImage')) sbData['avatar_url'] = data['profileImage'];
        if (data.containsKey('role')) {
          sbData['role'] = data['role'].toString().split('.').last;
        }

        if (sbData.isNotEmpty) {
          await _supabase.updateUserProfile(userId, sbData);
        }
      } catch (sbErr) {
        debugPrint('[UserService] Supabase update failed: $sbErr');
      }
    } catch (e) {
      debugPrint('[UserService] ERROR updating user: $e');
      rethrow;
    }
  }

  // --- Auto Account Creation ---
  Future<UserModel> createCustomerFromOTP(String uid, String phone) async {
    final user = UserModel(
      id: uid,
      phoneNumber: phone,
      role: UserRole.customer,
      roles: [UserRole.customer],
      isVerified: true,
      guestMigrated: true,
      linkedProviders: ['phone'],
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );
    await createUser(user);
    return user;
  }

  Future<UserModel> createCustomerFromGoogle(User firebaseUser) async {
    final user = UserModel(
      id: firebaseUser.uid,
      phoneNumber: firebaseUser.phoneNumber ?? '',
      email: firebaseUser.email,
      name: firebaseUser.displayName,
      profileImage: firebaseUser.photoURL,
      role: UserRole.customer,
      roles: [UserRole.customer],
      isVerified: true,
      linkedProviders: firebaseUser.providerData.map((e) => e.providerId).toList(),
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );
    await createUser(user);
    return user;
  }

  Future<UserModel> ensureUserDocExists(User firebaseUser) async {
    UserModel? existing = await getUser(firebaseUser.uid);
    if (existing != null) {
      // Update last login
      await updateUser(firebaseUser.uid, {'lastLogin': FieldValue.serverTimestamp()});
      return existing.copyWith(lastLogin: DateTime.now());
    }

    // Determine creation strategy based on providers
    final providers = firebaseUser.providerData.map((e) => e.providerId).toList();
    if (providers.contains('google.com')) {
      return await createCustomerFromGoogle(firebaseUser);
    } else {
      return await createCustomerFromOTP(firebaseUser.uid, firebaseUser.phoneNumber ?? '');
    }
  }

  // --- Authorization & RBAC ---
  Future<void> authorizeUser(
    String phoneNumber,
    UserRole role,
    String name,
    String authorizedBy,
  ) async {
    final docId = phoneNumber.replaceAll('+', '');
    await _db.collection('pre_authorized_users').doc(docId).set({
      'phoneNumber': phoneNumber,
      'role': role.toString(),
      'name': name,
      'authorizedBy': authorizedBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getAuthorization(String phoneNumber) async {
    final docId = phoneNumber.replaceAll('+', '');
    final doc = await _db.collection('pre_authorized_users').doc(docId).get();
    return doc.exists ? doc.data() : null;
  }

  Stream<List<Map<String, dynamic>>> getAuthorizedRidersStream() {
    return _db
        .collection('pre_authorized_users')
        .where('role', isEqualTo: UserRole.deliveryAgent.toString())
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> deauthorizeUser(String phoneNumber) async {
    final docId = phoneNumber.replaceAll('+', '');
    await _db.collection('pre_authorized_users').doc(docId).delete();
  }

  /// Permanently delete the user account and all associated data.
  Future<void> deleteUserAccount(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
    } catch (e) {
      debugPrint('[UserService] deleteUserAccount failed: $e');
      rethrow;
    }
  }
}
