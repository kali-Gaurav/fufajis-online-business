import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class TrustedDeviceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  static Future<String> getDeviceId() async {
    String newId = '';
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await _deviceInfoPlugin.androidInfo;
      newId = androidInfo.id;
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await _deviceInfoPlugin.iosInfo;
      newId = iosInfo.identifierForVendor ?? DateTime.now().millisecondsSinceEpoch.toString();
    } else {
      newId = DateTime.now().millisecondsSinceEpoch.toString();
    }
    return newId;
  }

  static Future<String> getDeviceName() async {
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await _deviceInfoPlugin.androidInfo;
      return '${androidInfo.manufacturer} ${androidInfo.model}';
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await _deviceInfoPlugin.iosInfo;
      return iosInfo.name;
    }
    return 'Unknown Device';
  }

  Future<void> registerDevice(String uid) async {
    final deviceId = await getDeviceId();
    final deviceName = await getDeviceName();

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId)
        .set({
      'deviceId': deviceId,
      'deviceName': deviceName,
      'lastLogin': FieldValue.serverTimestamp(),
      'trusted': true,
      'addedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> isDeviceTrusted(String uid) async {
    final deviceId = await getDeviceId();
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(deviceId)
          .get();

      if (doc.exists && doc.data()?['trusted'] == true) {
        // Update last login
        await doc.reference.update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> getMyDevices(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> revokeDevice(String uid, String deviceId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId)
        .delete();
  }
}
