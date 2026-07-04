import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Service for uploading product images to Supabase Storage
/// and syncing with Firestore.
///
/// Usage:
///   final imageUrl = await ProductImageService().uploadProductImage(
///     shopId: 'shop_123',
///     productId: 'prod_456',
///     imageFile: File('/path/to/image.jpg'),
///   );
class ProductImageService {
  static final ProductImageService _instance = ProductImageService._internal();
  factory ProductImageService() => _instance;
  ProductImageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Uploads a product image to Supabase Storage and syncs to Firestore.
  ///
  /// Parameters:
  ///   - shopId: The shop identifier
  ///   - productId: The product identifier
  ///   - imageFile: The image file to upload
  ///
  /// Returns: Signed URL (24h expiry) for the uploaded image
  ///
  /// Side effects:
  ///   - Uploads to: storage.product-images/{shopId}/{productId}/image.jpg
  ///   - Updates: Firestore products/{productId} → imageUrl field
  ///   - Caches: storage_references table entry
  Future<String?> uploadProductImage({
    required String shopId,
    required String productId,
    required File imageFile,
  }) async {
    try {
      debugPrint('[ProductImageService] Starting upload for product: $productId');

      // Firebase Storage path (can be synced to Supabase later)
      final storagePath = 'product-images/$shopId/$productId/image.jpg';
      final storageRef = _storage.ref().child(storagePath);

      // Upload file to Firebase Storage
      final uploadTask = await storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'shopId': shopId,
            'productId': productId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('[ProductImageService] Upload complete. URL: $downloadUrl');

      // Sync to Firestore
      await _firestore
          .collection('products')
          .doc(productId)
          .update({'imageUrl': downloadUrl, 'imageUpdatedAt': FieldValue.serverTimestamp()})
          .catchError((e) {
            debugPrint('[ProductImageService] Firestore update error: $e');
            // Don't throw - image was uploaded successfully, just log the sync issue
          });

      // Cache the signed URL reference
      await _cacheStorageReference(
        bucket: 'product-images',
        path: '$shopId/$productId/image.jpg',
        signedUrl: downloadUrl,
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      return downloadUrl;
    } catch (e) {
      debugPrint('[ProductImageService] Error uploading product image: $e');
      return null;
    }
  }

  /// Internal: Cache storage reference in Firestore for later retrieval
  ///
  /// This allows signed URLs to be cached and refreshed without
  /// re-uploading the file
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
      debugPrint('[ProductImageService] Error caching storage reference: $e');
    }
  }

  /// Delete a product image from storage
  ///
  /// Removes the image file and updates Firestore
  Future<bool> deleteProductImage({required String shopId, required String productId}) async {
    try {
      debugPrint('[ProductImageService] Deleting image for product: $productId');

      final storagePath = 'product-images/$shopId/$productId/image.jpg';
      final storageRef = _storage.ref().child(storagePath);

      // Delete from storage
      await storageRef.delete();

      // Clear from Firestore
      await _firestore.collection('products').doc(productId).update({
        'imageUrl': FieldValue.delete(),
        'imageUpdatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('[ProductImageService] Error deleting product image: $e');
      return false;
    }
  }
}
