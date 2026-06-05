import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

/// High-performance local storage service using Hive (Step 1.5)
/// Prep for Step 40 (Offline POS & Billing Mode)
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;
  static const String boxName = 'fufaji_offline_vault';
  late Box _box;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox(boxName);
      _isInitialized = true;
      debugPrint('[StorageService] Hive Offline Vault initialized.');
    } catch (e) {
      debugPrint('[StorageService] Hive initialization failed: $e');
    }
  }

  /// Saves any data type supported by Hive
  Future<void> put(String key, dynamic value) async {
    if (!_isInitialized) await init();
    await _box.put(key, value);
  }

  /// Retrieves data from the vault
  dynamic get(String key, {dynamic defaultValue}) {
    if (!_isInitialized) return defaultValue;
    return _box.get(key, defaultValue: defaultValue);
  }

  /// Checks if a key exists
  bool hasKey(String key) {
    if (!_isInitialized) return false;
    return _box.containsKey(key);
  }

  /// Deletes a specific entry
  Future<void> delete(String key) async {
    if (!_isInitialized) return;
    await _box.delete(key);
  }

  /// Clears all offline data
  Future<void> clearAll() async {
    if (!_isInitialized) return;
    await _box.clear();
  }

  /// Bulk save for high-speed inventory sync
  Future<void> putAll(Map<String, dynamic> entries) async {
    if (!_isInitialized) await init();
    await _box.putAll(entries);
  }

  /// Uploads an image to Firebase Storage (Cloud fallback)
  Future<String?> uploadImage(File file, String folder) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final ref = _firebaseStorage.ref().child(folder).child(fileName);
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('[StorageService] Firebase upload failed: $e');
      return null;
    }
  }
}
