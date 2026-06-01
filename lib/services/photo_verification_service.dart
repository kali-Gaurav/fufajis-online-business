import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class PhotoVerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a daily freshness shelf photo for a product
  Future<String?> uploadShelfPhoto({
    required String productId,
    required File imageFile,
  }) async {
    try {
      final now = DateTime.now();
      final path = 'products/$productId/shelf_${now.millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(path);
      
      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Update product's main image or verification fields in Firestore
      await _firestore.collection('products').doc(productId).update({
        'shelfPhotoUrl': downloadUrl,
        'shelfPhotoUpdatedAt': Timestamp.fromDate(now),
      });

      return downloadUrl;
    } catch (e) {
      debugPrint('[PhotoVerificationService] Error uploading shelf photo: $e');
      return null;
    }
  }

  /// Checks if a product was verified today (within 24 hours)
  bool isVerifiedFresh(DateTime? lastUpdated) {
    if (lastUpdated == null) return false;
    final difference = DateTime.now().difference(lastUpdated);
    return difference.inHours < 24;
  }
}
