import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff_credential_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Note: This service is for admin/owner use to create credentials, or for edge functions to verify.
// In a highly secure environment, PIN verification is done strictly via Edge Functions.

class StaffCredentialService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'staff_credentials';

  Future<void> createCredential(StaffCredentialModel credential) async {
    await _firestore
        .collection(_collection)
        .doc(credential.userId)
        .set(credential.toMap());
  }

  Future<void> updatePin(String userId, String newPinHash) async {
    await _firestore
        .collection(_collection)
        .doc(userId)
        .update({'pinHash': newPinHash});
  }
  
  // NOTE: Clients should NOT call this to verify PINs directly.
  // Instead, the client calls a Cloud Function / Edge Function passing the ID+PIN.
  // The backend function reads this collection, verifies the hash, and mints a custom auth token.
}
