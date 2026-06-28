import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee_model.dart';

class EmployeeAuthService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if an email belongs to an active employee and verify/bind their UID
  static Future<Employee?> verifyEmployeeAccess(String email, String uid) async {
    try {
      var snapshot = await _firestore
          .collection('employees')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        var doc = snapshot.docs.first;
        var data = Map<String, dynamic>.from(doc.data());

        // Bind UID on first successful sign in
        if (data['uid'] == null || data['uid'].toString().isEmpty) {
          await doc.reference.update({
            'uid': uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          data['uid'] = uid;
        }

        Employee employee = Employee.fromJson(data);

        // Verification check: UID matches, Email matches, and status is active
        if (employee.uid == uid && employee.email == email && employee.isActive) {
          return employee;
        }
      }
      return null;
    } catch (e) {
      print('Error verifying employee access: $e');
      return null;
    }
  }

  /// Listen to employee document changes for real-time revocation
  static Stream<Employee?> streamEmployeeStatus(String employeeId) {
    return _firestore
        .collection('employees')
        .where('employeeId', isEqualTo: employeeId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return Employee.fromJson(Map<String, dynamic>.from(snapshot.docs.first.data()));
      }
      return null;
    });
  }

  /// Returns a stream of all active employees for selection in dashboards
  static Stream<List<Employee>> streamActiveEmployees() {
    return _firestore
        .collection('employees')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Employee.fromJson(Map<String, dynamic>.from(doc.data())))
          .toList();
    });
  }
}
