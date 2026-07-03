import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'signed_url_service.dart';

/// Service for uploading delivery proof photos to Supabase Storage
/// and marking deliveries as completed.
///
/// Usage:
///   final result = await DeliveryProofService().uploadDeliveryProof(
///     deliveryId: 'delivery_123',
///     photoFile: File('/path/to/proof.jpg'),
///   );
class DeliveryProofService {
  static final DeliveryProofService _instance = DeliveryProofService._internal();
  factory DeliveryProofService() => _instance;
  DeliveryProofService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SignedUrlService _signedUrlService = SignedUrlService();

  /// Uploads a delivery proof photo and marks delivery as completed.
  ///
  /// Parameters:
  ///   - deliveryId: The delivery identifier
  ///   - photoFile: The photo file to upload
  ///
  /// Returns: Signed URL for the uploaded proof
  ///
  /// Side effects:
  ///   - Uploads to: storage.delivery-proofs/{deliveryId}/proof.jpg
  ///   - Updates: Firestore deliveries/{deliveryId} → proofPhotoUrl
  ///   - Updates: Firestore deliveries/{deliveryId} → status = 'delivered'
  Future<String?> uploadDeliveryProof({required String deliveryId, required File photoFile}) async {
    try {
      debugPrint('[DeliveryProofService] Starting proof upload for delivery: $deliveryId');

      // Firebase Storage path
      final storagePath = 'delivery-proofs/$deliveryId/proof.jpg';
      final storageRef = _storage.ref().child(storagePath);

      // Upload file to Firebase Storage
      final uploadTask = await storageRef.putFile(
        photoFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'deliveryId': deliveryId,
            'proofType': 'delivery_photo',
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('[DeliveryProofService] Upload complete. URL: $downloadUrl');

      // Get delivery details for reference
      final deliveryDoc = await _firestore.collection('deliveries').doc(deliveryId).get();

      if (!deliveryDoc.exists) {
        debugPrint('[DeliveryProofService] Delivery not found: $deliveryId');
        return downloadUrl; // Still return URL even if delivery not found
      }

      // Update delivery status to 'delivered'
      await _firestore
          .collection('deliveries')
          .doc(deliveryId)
          .update({
            'proofPhotoUrl': downloadUrl,
            'status': 'delivered',
            'deliveredAt': FieldValue.serverTimestamp(),
            'proofUploadedAt': FieldValue.serverTimestamp(),
          })
          .catchError((e) {
            debugPrint('[DeliveryProofService] Firestore update error: $e');
          });

      // Cache the signed URL
      await _cacheStorageReference(
        bucket: 'delivery-proofs',
        path: '$deliveryId/proof.jpg',
        signedUrl: downloadUrl,
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      // Trigger order completion notification
      await _triggerOrderCompletionNotification(deliveryId);

      return downloadUrl;
    } catch (e) {
      debugPrint('[DeliveryProofService] Error uploading delivery proof: $e');
      return null;
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
      debugPrint('[DeliveryProofService] Error caching storage reference: $e');
    }
  }

  /// Internal: Trigger order completion notification
  ///
  /// Creates notifications for customer and updates order status
  Future<void> _triggerOrderCompletionNotification(String deliveryId) async {
    try {
      // Get delivery to find associated orderId
      final deliveryDoc = await _firestore.collection('deliveries').doc(deliveryId).get();

      if (!deliveryDoc.exists) return;

      final deliveryData = deliveryDoc.data();
      final orderId = deliveryData?['orderId'] as String?;
      final customerId = deliveryData?['customerId'] as String?;

      if (orderId == null) return;

      // Update order status
      await _firestore
          .collection('orders')
          .doc(orderId)
          .update({'status': 'delivered', 'deliveredAt': FieldValue.serverTimestamp()})
          .catchError((e) {
            debugPrint('[DeliveryProofService] Error updating order: $e');
          });

      // Create customer notification
      if (customerId != null) {
        await _firestore.collection('customer_notifications').add({
          'customerId': customerId,
          'orderId': orderId,
          'type': 'order_delivered',
          'title': 'Order Delivered',
          'body': 'Your order #$orderId has been delivered.',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('[DeliveryProofService] Error triggering completion notification: $e');
    }
  }

  /// Upload multiple proof photos (for batch deliveries)
  ///
  /// Useful when a rider has multiple deliveries to complete
  Future<Map<String, String?>> uploadMultipleProofs({
    required Map<String, File> deliveryIdToFile,
  }) async {
    final results = <String, String?>{};

    for (final entry in deliveryIdToFile.entries) {
      final deliveryId = entry.key;
      final photoFile = entry.value;

      final url = await uploadDeliveryProof(deliveryId: deliveryId, photoFile: photoFile);
      results[deliveryId] = url;
    }

    return results;
  }

  /// Get delivery proof URL if it exists
  Future<String?> getDeliveryProofUrl(String deliveryId) async {
    try {
      final doc = await _firestore.collection('deliveries').doc(deliveryId).get();

      if (!doc.exists) return null;

      return doc.data()?['proofPhotoUrl'] as String?;
    } catch (e) {
      debugPrint('[DeliveryProofService] Error getting proof URL: $e');
      return null;
    }
  }

  /// Delete a delivery proof
  Future<bool> deleteDeliveryProof(String deliveryId) async {
    try {
      debugPrint('[DeliveryProofService] Deleting proof for delivery: $deliveryId');

      final storagePath = 'delivery-proofs/$deliveryId/proof.jpg';
      final storageRef = _storage.ref().child(storagePath);

      // Delete from storage
      await storageRef.delete();

      // Clear from Firestore
      await _firestore.collection('deliveries').doc(deliveryId).update({
        'proofPhotoUrl': FieldValue.delete(),
        'proofUploadedAt': FieldValue.delete(),
      });

      return true;
    } catch (e) {
      debugPrint('[DeliveryProofService] Error deleting delivery proof: $e');
      return false;
    }
  }
}
