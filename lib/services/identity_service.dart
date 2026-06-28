import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/contact_model.dart';

class IdentityService {
  static final IdentityService _instance = IdentityService._internal();
  factory IdentityService() => _instance;
  IdentityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches all contacts for a specific user from Firestore
  Future<List<ContactModel>> getContactsForUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ContactModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Adds a new contact to Firestore
  Future<bool> addContact(ContactModel contact) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('contacts')
          .doc();

      final contactData = contact.toMap();
      contactData['id'] = docRef.id;
      contactData['user_id'] = uid;
      contactData['created_at'] = DateTime.now().toIso8601String();

      await docRef.set(contactData);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Deletes a contact from Firestore
  Future<bool> deleteContact(String contactId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('contacts')
          .doc(contactId)
          .delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Stub: legacy method for tables setup
  Future<void> initializeTable() async {
    // No-op for Firestore
  }
}
