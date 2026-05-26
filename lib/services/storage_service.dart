import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadImage(File image, String path) async {
    return uploadFile(image, path, extension: 'jpg');
  }

  Future<String?> uploadFile(
    File file,
    String path, {
    String extension = 'jpg',
  }) async {
    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final Reference ref = _storage.ref().child('$path/$fileName.$extension');
      
      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;
      
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> deleteImage(String url) async {
    try {
      final Reference ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
  }
}
