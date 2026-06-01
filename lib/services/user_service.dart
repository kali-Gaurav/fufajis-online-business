import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // --- Users ---
  Future<void> createUser(UserModel user) async {
    try {
      await _db.collection('users').doc(user.id).set(user.toMap());
      debugPrint('[UserService] User created: ${user.id}');
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
      await _db.collection('users').doc(userId).update(data);
    } catch (e) {
      debugPrint('[UserService] ERROR updating user: $e');
      rethrow;
    }
  }

  // --- Authorization & RBAC ---
  Future<void> authorizeUser(String phoneNumber, UserRole role, String name, String authorizedBy) async {
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
}
