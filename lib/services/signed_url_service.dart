import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Service for managing signed URLs with caching and expiry checking.
///
/// This service handles:
/// - Retrieving cached signed URLs from Firestore
/// - Checking expiry and refreshing expired URLs
/// - Calling Edge Functions for new signed URLs
/// - Caching new URLs for future use
///
/// Usage:
///   final url = await SignedUrlService().getSignedUrl(
///     bucket: 'product-images',
///     path: 'shop_123/prod_456/image.jpg',
///   );
class SignedUrlService {
  static final SignedUrlService _instance = SignedUrlService._internal();
  factory SignedUrlService() => _instance;
  SignedUrlService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // In-memory cache for signed URLs (valid for this session)
  final Map<String, CachedUrl> _memoryCache = {};

  /// Get a signed URL for a file, checking cache first.
  ///
  /// Flow:
  /// 1. Check in-memory cache (fastest)
  /// 2. Check Firestore cache (storage_references collection)
  /// 3. If cached URL is still valid (not expired), return it
  /// 4. If expired or not found, generate new signed URL
  /// 5. Cache the new URL and return it
  ///
  /// Parameters:
  ///   - bucket: Storage bucket name (e.g., 'product-images')
  ///   - path: File path in bucket (e.g., 'shop_123/prod_456/image.jpg')
  ///
  /// Returns: Signed URL (always valid) or null if generation fails
  Future<String?> getSignedUrl({
    required String bucket,
    required String path,
  }) async {
    try {
      final cacheKey = '$bucket/$path';
      debugPrint('[SignedUrlService] Fetching signed URL for: $cacheKey');

      // Check in-memory cache first (fastest path)
      if (_memoryCache.containsKey(cacheKey)) {
        final cached = _memoryCache[cacheKey]!;
        if (cached.isValid) {
          debugPrint('[SignedUrlService] Returning from memory cache');
          return cached.url;
        } else {
          _memoryCache.remove(cacheKey);
        }
      }

      // Check Firestore cache
      final cachedUrl = await _getCachedUrlFromFirestore(bucket, path);
      if (cachedUrl != null) {
        // Verify it's still valid before returning
        if (cachedUrl['expiresAt'] is Timestamp) {
          final expiresAt =
              (cachedUrl['expiresAt'] as Timestamp).toDate();
          if (DateTime.now().isBefore(expiresAt)) {
            debugPrint('[SignedUrlService] Returning from Firestore cache');
            final url = cachedUrl['signedUrl'] as String;

            // Also cache in memory for this session
            _memoryCache[cacheKey] = CachedUrl(
              url: url,
              expiresAt: expiresAt,
            );

            return url;
          }
        }
      }

      // No valid cached URL, generate new one
      debugPrint('[SignedUrlService] Generating new signed URL');
      final newUrl = await _generateSignedUrl(bucket, path);

      if (newUrl != null) {
        // Cache the new URL
        final expiryTime = DateTime.now().add(const Duration(hours: 24));
        await _cacheUrlInFirestore(
          bucket: bucket,
          path: path,
          signedUrl: newUrl,
          expiresAt: expiryTime,
        );

        // Also cache in memory
        _memoryCache[cacheKey] = CachedUrl(
          url: newUrl,
          expiresAt: expiryTime,
        );

        return newUrl;
      }

      return null;
    } catch (e) {
      debugPrint('[SignedUrlService] Error getting signed URL: $e');
      return null;
    }
  }

  /// Internal: Get cached URL from Firestore storage_references
  Future<Map<String, dynamic>?> _getCachedUrlFromFirestore(
    String bucket,
    String path,
  ) async {
    try {
      final query = await _firestore
          .collection('storage_references')
          .where('bucket', isEqualTo: bucket)
          .where('path', isEqualTo: path)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('[SignedUrlService] Error getting cached URL: $e');
      return null;
    }
  }

  /// Internal: Generate a new signed URL from Firebase Storage
  ///
  /// In production, this would call the Edge Function:
  ///   GET /functions/v1/get_storage_signed_url?bucket=...&path=...
  ///
  /// For now, we use Firebase Storage's built-in download URL
  /// (Note: These are public URLs, not time-limited signed URLs)
  Future<String?> _generateSignedUrl(String bucket, String path) async {
    try {
      // Firebase Storage path construction
      final fullPath = '$bucket/$path';
      final ref = _storage.ref(fullPath);

      // Get download URL (public, permanent)
      // In production with Supabase, use the Edge Function instead
      final downloadUrl = await ref.getDownloadURL();

      debugPrint('[SignedUrlService] Generated URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('[SignedUrlService] Error generating signed URL: $e');

      // Fallback: Return null - caller should handle gracefully
      return null;
    }
  }

  /// Internal: Cache a signed URL in Firestore
  Future<void> _cacheUrlInFirestore({
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
      debugPrint('[SignedUrlService] Error caching URL: $e');
    }
  }

  /// Refresh a signed URL (invalidate cache and generate new one)
  ///
  /// Use this when you need a fresh URL (e.g., if the current URL stops working)
  Future<String?> refreshSignedUrl({
    required String bucket,
    required String path,
  }) async {
    try {
      final cacheKey = '$bucket/$path';

      // Remove from memory cache
      _memoryCache.remove(cacheKey);

      // Remove from Firestore cache
      await _firestore
          .collection('storage_references')
          .where('bucket', isEqualTo: bucket)
          .where('path', isEqualTo: path)
          .get()
          .then((query) {
        for (final doc in query.docs) {
          doc.reference.delete();
        }
      });

      // Generate and cache new URL
      return await getSignedUrl(bucket: bucket, path: path);
    } catch (e) {
      debugPrint('[SignedUrlService] Error refreshing signed URL: $e');
      return null;
    }
  }

  /// Clear expired URLs from cache
  ///
  /// Should be called periodically to clean up Firestore
  Future<void> clearExpiredUrls() async {
    try {
      final now = Timestamp.now();

      await _firestore
          .collection('storage_references')
          .where('expiresAt', isLessThan: now)
          .get()
          .then((query) {
        for (final doc in query.docs) {
          doc.reference.delete();
        }
      });

      debugPrint('[SignedUrlService] Cleared expired URLs');
    } catch (e) {
      debugPrint('[SignedUrlService] Error clearing expired URLs: $e');
    }
  }

  /// Clear all cached URLs for a specific bucket
  Future<void> clearBucketCache(String bucket) async {
    try {
      // Remove from memory cache
      _memoryCache.removeWhere((key, _) => key.startsWith('$bucket/'));

      // Remove from Firestore
      await _firestore
          .collection('storage_references')
          .where('bucket', isEqualTo: bucket)
          .get()
          .then((query) {
        for (final doc in query.docs) {
          doc.reference.delete();
        }
      });

      debugPrint('[SignedUrlService] Cleared cache for bucket: $bucket');
    } catch (e) {
      debugPrint('[SignedUrlService] Error clearing bucket cache: $e');
    }
  }
}

/// Internal: Representation of a cached URL in memory
class CachedUrl {
  final String url;
  final DateTime expiresAt;

  CachedUrl({required this.url, required this.expiresAt});

  bool get isValid => DateTime.now().isBefore(expiresAt);
}
