import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';

/// Structured S3 folder/key layout for the Fufaji bucket.
///
/// Centralizing key construction here keeps uploads organized and makes
/// it easy to apply per-folder lifecycle rules (e.g. auto-expire
/// `backups/`) without scattering string paths across the app.
///
/// All paths are relative S3 keys — pass the result to
/// [S3StorageService.uploadBytes] / [S3StorageService.getPresignedUrl].
class S3Paths {
  S3Paths._();

  /// users/{uid}/avatar/{fileName}
  static String userAvatar(String uid, String fileName) => 'users/$uid/avatar/$fileName';

  /// products/{productId}/images/{fileName}
  static String productImage(String productId, String fileName) =>
      'products/$productId/images/$fileName';

  /// vendors/{vendorId}/banners/{fileName}
  static String vendorBanner(String vendorId, String fileName) =>
      'vendors/$vendorId/banners/$fileName';

  /// vendors/{vendorId}/logo/{fileName}
  static String vendorLogo(String vendorId, String fileName) => 'vendors/$vendorId/logo/$fileName';

  /// orders/{orderId}/delivery-proof/{fileName}
  static String deliveryProof(String orderId, String fileName) =>
      'orders/$orderId/delivery-proof/$fileName';

  /// orders/{orderId}/bills/{fileName}
  static String bill(String orderId, String fileName) => 'orders/$orderId/bills/$fileName';

  /// orders/{orderId}/invoices/{fileName}
  static String invoice(String orderId, String fileName) => 'orders/$orderId/invoices/$fileName';

  /// marketing/{campaignId}/{fileName}
  static String marketingAsset(String campaignId, String fileName) =>
      'marketing/$campaignId/$fileName';

  /// users/{uid}/kyc/{docType}/{fileName}
  static String kycDocument(String uid, String docType, String fileName) =>
      'users/$uid/kyc/$docType/$fileName';

  /// backups/{date}/{fileName} — e.g. backups/2026-06-12/export.json
  static String backup(String date, String fileName) => 'backups/$date/$fileName';
}

/// Service to manage AWS S3 Object Storage via presigned URLs.
///
/// SECURITY: The app never holds AWS S3 access/secret keys. Instead, it
/// asks the `getS3UploadUrl` / `getS3DownloadUrl` Cloud Functions for a
/// short-lived presigned URL, then performs a plain HTTP PUT/GET directly
/// against S3 using that URL.
///
/// Non-admin users are restricted (server-side) to keys under
/// `uploads/{uid}/...`.
class S3StorageService {
  static final S3StorageService _instance = S3StorageService._internal();
  factory S3StorageService() => _instance;
  S3StorageService._internal();

  final Dio _dio = Dio();

  /// Always true — server decides if S3 is actually configured.
  bool get isConfigured => true;

  /// Builds a key scoped to the current user's uploads folder, e.g.
  /// `uploads/{uid}/bills/2026-06-12.jpg`. Falls back to a generic prefix
  /// if no user is signed in (admin flows should pass their own keys).
  String scopedKey(String relativePath) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return relativePath;
    return 'uploads/$uid/$relativePath';
  }

  /// Uploads a local file to S3. [s3Key] should typically be produced via
  /// [scopedKey] unless the caller is an admin.
  Future<String?> uploadFile(
    String filePath,
    String s3Key, {
    String contentType = 'application/octet-stream',
  }) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      return await uploadBytes(bytes, s3Key, contentType: contentType);
    } catch (e) {
      debugPrint('[S3] Upload failed: $e');
      return null;
    }
  }

  /// Uploads raw bytes to S3 via a presigned PUT URL.
  Future<String?> uploadBytes(
    Uint8List bytes,
    String s3Key, {
    String contentType = 'application/octet-stream',
  }) async {
    try {
      final result = await ApiClient().post('/storage/upload-url', <String, dynamic>{
        'key': s3Key,
        'contentType': contentType,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final uploadUrl = data['uploadUrl'] as String?;
      final publicUrl = data['publicUrl'] as String?;

      if (uploadUrl == null) {
        debugPrint('[S3] No upload URL returned');
        return null;
      }

      await _dio.put(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            Headers.contentLengthHeader: bytes.length,
            Headers.contentTypeHeader: contentType,
          },
        ),
      );

      debugPrint('[S3] Upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('[S3] Upload failed: $e');
      return null;
    }
  }

  /// Generates a temporary signed URL for downloading a private object.
  Future<String?> getPresignedUrl(String s3Key, {int expires = 3600}) async {
    try {
      final result = await ApiClient().post('/storage/download-url', <String, dynamic>{
        'key': s3Key,
        'expiresIn': expires,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      return data['downloadUrl'] as String?;
    } catch (e) {
      debugPrint('[S3] Failed to generate presigned URL: $e');
      return null;
    }
  }

  /// Deletes an object from the S3 bucket. Admin-only (enforced server-side).
  Future<bool> deleteFile(String s3Key) async {
    try {
      await ApiClient().post('/storage/delete', <String, dynamic>{'key': s3Key});
      debugPrint('[S3] Deleted: $s3Key');
      return true;
    } catch (e) {
      debugPrint('[S3] Delete failed: $e');
      return false;
    }
  }
}
