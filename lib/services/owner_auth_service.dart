import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/owner_model.dart';
import 'device_security_service.dart';

enum OwnerLoginState { firstLogin, dailyLogin, newDevicePending, unauthorized }

class OwnerAuthService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if an email belongs to an owner
  static Future<Owner?> verifyOwnerAccess(String email) async {
    try {
      var snapshot = await _firestore
          .collection('owners')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Owner.fromJson(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error verifying owner access: $e');
      return null;
    }
  }

  /// Determine the state of the owner based on device
  static Future<OwnerLoginState> getOwnerLoginState(Owner owner) async {
    String deviceId = await DeviceSecurityService.getDeviceId();

    if (owner.approvedDevices.isEmpty) {
      return OwnerLoginState.firstLogin;
    }

    bool isApproved = owner.approvedDevices.any((d) => d.deviceId == deviceId && d.approved);

    if (isApproved) {
      return OwnerLoginState.dailyLogin;
    } else {
      return OwnerLoginState.newDevicePending;
    }
  }

  /// Register a device (either approved for first login, or pending for new device)
  static Future<void> registerDevice(String email, bool approved) async {
    String deviceId = await DeviceSecurityService.getDeviceId();
    String deviceName = await DeviceSecurityService.getDeviceName();

    Device newDevice = Device(deviceId: deviceId, deviceName: deviceName, approved: approved);

    // Get document ID
    var snapshot = await _firestore
        .collection('owners')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      String docId = snapshot.docs.first.id;
      await _firestore.collection('owners').doc(docId).update({
        'approvedDevices': FieldValue.arrayUnion([newDevice.toJson()]),
      });
    }
  }

  /// Complete first login setup (save PIN and Biometric preference)
  static Future<String> setupFirstLogin(String email, String pin, bool enableBiometrics) async {
    String pinHash = DeviceSecurityService.hashPin(pin);
    await DeviceSecurityService.storePinHashLocally(pinHash);

    var snapshot = await _firestore
        .collection('owners')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      String docId = snapshot.docs.first.id;
      await _firestore.collection('owners').doc(docId).update({
        'pinHash': pinHash,
        'biometricEnabled': enableBiometrics,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return pinHash;
  }

  /// Approve a pending owner device
  static Future<void> approveDevice(String email, String deviceId) async {
    var snapshot = await _firestore
        .collection('owners')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      var doc = snapshot.docs.first;
      var data = doc.data();
      var approvedDevices = List<Map<String, dynamic>>.from(
        data['approvedDevices'] as Iterable? ?? [],
      );

      for (var dev in approvedDevices) {
        if (dev['deviceId'] == deviceId) {
          dev['approved'] = true;
          break;
        }
      }

      await doc.reference.update({'approvedDevices': approvedDevices});
    }
  }

  /// Rename a device (updates deviceName in approvedDevices array)
  static Future<void> renameDevice(String email, String deviceId, String newName) async {
    var snapshot = await _firestore
        .collection('owners')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      var doc = snapshot.docs.first;
      var devices = List<Map<String, dynamic>>.from(
        (doc.data()['approvedDevices'] as Iterable?) ?? [],
      );

      for (var dev in devices) {
        if (dev['deviceId'] == deviceId) {
          dev['deviceName'] = newName;
          break;
        }
      }

      await doc.reference.update({'approvedDevices': devices});
    }
  }

  /// Remove/revoke a trusted or pending device completely
  static Future<void> removeDevice(String email, String deviceId) async {
    var snapshot = await _firestore
        .collection('owners')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      var doc = snapshot.docs.first;
      var data = doc.data();
      var approvedDevices = List<Map<String, dynamic>>.from(
        data['approvedDevices'] as Iterable? ?? [],
      );

      approvedDevices.removeWhere((dev) => dev['deviceId'] == deviceId);

      await doc.reference.update({'approvedDevices': approvedDevices});
    }
  }
}
