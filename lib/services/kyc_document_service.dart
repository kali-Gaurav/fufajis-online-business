import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'signed_url_service.dart';

/// Service for uploading KYC documents to Supabase Storage
/// and triggering KYC verification workflow.
///
/// Usage:
///   final result = await KYCDocumentService().uploadKYCDocument(
///     userId: 'user_123',
///     pdfFile: File('/path/to/kyc.pdf'),
///   );
class KYCDocumentService {
  static final KYCDocumentService _instance = KYCDocumentService._internal();
  factory KYCDocumentService() => _instance;
  KYCDocumentService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SignedUrlService _signedUrlService = SignedUrlService();

  /// Uploads a KYC document and initiates verification workflow.
  ///
  /// Parameters:
  ///   - userId: The user identifier
  ///   - pdfFile: The PDF file to upload
  ///
  /// Returns: Map containing signedUrl and expiryTime
  ///
  /// Side effects:
  ///   - Uploads to: storage.customer-documents/{userId}/kyc.pdf
  ///   - Updates: Firestore users/{userId} → kycDocumentUrl, kycDocumentStatus
  ///   - Triggers: KYC verification workflow (admin notification)
  Future<Map<String, dynamic>?> uploadKYCDocument({
    required String userId,
    required File pdfFile,
  }) async {
    try {
      debugPrint('[KYCDocumentService] Starting KYC document upload for user: $userId');

      // Firebase Storage path
      final storagePath = 'customer-documents/$userId/kyc.pdf';
      final storageRef = _storage.ref().child(storagePath);

      // Upload file to Firebase Storage
      final uploadTask = await storageRef.putFile(
        pdfFile,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'userId': userId,
            'documentType': 'kyc',
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('[KYCDocumentService] Upload complete. URL: $downloadUrl');

      // Update Firestore with document URL and pending status
      final now = DateTime.now();
      await _firestore.collection('users').doc(userId).update({
        'kycDocumentUrl': downloadUrl,
        'kycDocumentStatus': 'pending',
        'kycDocumentUploadedAt': FieldValue.serverTimestamp(),
      }).catchError((e) {
        debugPrint('[KYCDocumentService] Firestore update error: $e');
      });

      // Trigger KYC verification workflow via admin notification
      await _triggerKYCVerificationWorkflow(userId, downloadUrl);

      // Cache the signed URL
      final expiryTime = DateTime.now().add(const Duration(hours: 24));
      await _cacheStorageReference(
        bucket: 'customer-documents',
        path: '$userId/kyc.pdf',
        signedUrl: downloadUrl,
        expiresAt: expiryTime,
      );

      debugPrint('[KYCDocumentService] KYC verification workflow triggered');

      return {
        'signedUrl': downloadUrl,
        'expiryTime': expiryTime,
        'status': 'pending',
      };
    } catch (e) {
      debugPrint('[KYCDocumentService] Error uploading KYC document: $e');
      return null;
    }
  }

  /// Internal: Trigger KYC verification workflow
  ///
  /// Creates an admin task for verifying the uploaded KYC document
  Future<void> _triggerKYCVerificationWorkflow(
    String userId,
    String documentUrl,
  ) async {
    try {
      // Create notification for admins to verify KYC
      await _firestore.collection('admin_notifications').add({
        'type': 'kyc_verification_required',
        'userId': userId,
        'documentUrl': documentUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'priority': 'high',
      });

      // Create workflow task
      await _firestore.collection('kyc_verifications').add({
        'userId': userId,
        'documentUrl': documentUrl,
        'status': 'pending_review',
        'submittedAt': FieldValue.serverTimestamp(),
        'verifiedAt': null,
        'verifiedBy': null,
        'rejectionReason': null,
      });
    } catch (e) {
      debugPrint('[KYCDocumentService] Error triggering verification workflow: $e');
    }
  }

  /// Internal: Cache storage reference
  Future<void> _cacheStorageReference({
    required String bucket,
    required String path,
    required String signedUrl,
    required DateTime expiresAt,
  }) async {
    try {
      await _firestore.collection('storage_references').add({
        'bucket': bucket,
        'path': path,
        'signedUrl': signedUrl,
        'expiresAt': expiresAt,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[KYCDocumentService] Error caching storage reference: $e');
    }
  }

  /// Get the current KYC status for a user
  ///
  /// Returns the document URL, status, and upload timestamp
  Future<Map<String, dynamic>?> getKYCStatus(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      return {
        'kycDocumentUrl': data?['kycDocumentUrl'],
        'kycDocumentStatus': data?['kycDocumentStatus'],
        'kycDocumentUploadedAt': data?['kycDocumentUploadedAt'],
      };
    } catch (e) {
      debugPrint('[KYCDocumentService] Error getting KYC status: $e');
      return null;
    }
  }

  /// Delete a KYC document
  Future<bool> deleteKYCDocument(String userId) async {
    try {
      debugPrint('[KYCDocumentService] Deleting KYC document for user: $userId');

      final storagePath = 'customer-documents/$userId/kyc.pdf';
      final storageRef = _storage.ref().child(storagePath);

      // Delete from storage
      await storageRef.delete();

      // Clear from Firestore
      await _firestore.collection('users').doc(userId).update({
        'kycDocumentUrl': FieldValue.delete(),
        'kycDocumentStatus': 'not_submitted',
        'kycDocumentUploadedAt': FieldValue.delete(),
      });

      return true;
    } catch (e) {
      debugPrint('[KYCDocumentService] Error deleting KYC document: $e');
      return false;
    }
  }
}
