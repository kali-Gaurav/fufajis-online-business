import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'employee_auth_service.dart';
import 'owner_auth_service.dart';
import 'session_service.dart';
import '../models/employee_model.dart';
import '../models/owner_model.dart';

enum AuthResultStatus {
  ownerAccess,
  employeeAccess,
  unauthorized,
  error,
}

class AuthResult {
  final AuthResultStatus status;
  final Owner? owner;
  final Employee? employee;
  final String? message;

  AuthResult({required this.status, this.owner, this.employee, this.message});
}

class AuthService extends ChangeNotifier {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  String? _currentSessionId;
  bool _isSessionRevoked = false;

  String? get currentSessionId => _currentSessionId;
  bool get isSessionRevoked => _isSessionRevoked;

  void resetSessionRevoked() {
    _isSessionRevoked = false;
    notifyListeners();
  }

  /// Handle Google Sign-In and check authorization level
  Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult(status: AuthResultStatus.error, message: 'Sign in aborted by user');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null || user.email == null) {
         await _googleSignIn.signOut();
         await _auth.signOut();
         return AuthResult(status: AuthResultStatus.error, message: 'Failed to retrieve email from Google');
      }

      String email = user.email!;

      // 1. Sync Custom Claims from Backend
      try {
        final HttpsCallable syncClaims = FirebaseFunctions.instance.httpsCallable('syncUserClaims');
        await syncClaims.call();
      } catch (e) {
        print('Error syncing custom claims: $e');
        // Continue and try to refresh token anyway
      }

      // 2. Force refresh token to load newly set claims
      final IdTokenResult tokenResult = await user.getIdTokenResult(true);
      final Map<String, dynamic>? claims = tokenResult.claims;
      final String? role = claims?['role'] as String?;

      if (role == null) {
        await _googleSignIn.signOut();
        await _auth.signOut();
        return AuthResult(status: AuthResultStatus.unauthorized, message: 'Your email is not authorized for access.');
      }

      // 3. Handle Owner Access
      if (role == 'owner') {
        Owner? owner = await OwnerAuthService.verifyOwnerAccess(email);
        if (owner != null) {
          // Initialize Session
          _isSessionRevoked = false;
          _currentSessionId = await SessionService().createSession(user.uid);
          SessionService().listenToSession(_currentSessionId!, () {
            _handleSessionRevocation();
          });
          notifyListeners();
          return AuthResult(status: AuthResultStatus.ownerAccess, owner: owner);
        }
      }

      // 4. Handle Employee Access
      else if (role == 'employee') {
        Employee? employee = await EmployeeAuthService.verifyEmployeeAccess(email, user.uid);
        if (employee != null) {
          // Initialize Session
          _isSessionRevoked = false;
          _currentSessionId = await SessionService().createSession(user.uid);
          SessionService().listenToSession(_currentSessionId!, () {
            _handleSessionRevocation();
          });
          notifyListeners();
          return AuthResult(status: AuthResultStatus.employeeAccess, employee: employee);
        }
      }

      // 5. Fallback if claims set but Firestore verification failed (e.g. deactivated employee)
      await _googleSignIn.signOut();
      await _auth.signOut();
      return AuthResult(status: AuthResultStatus.unauthorized, message: 'Unauthorized or deactivated account.');

    } catch (e) {
      print('Error during Google Sign In: $e');
      return AuthResult(status: AuthResultStatus.error, message: e.toString());
    }
  }

  void _handleSessionRevocation() async {
    SessionService().stopSessionListener();
    _currentSessionId = null;
    _isSessionRevoked = true;
    await _googleSignIn.signOut();
    await _auth.signOut();
    notifyListeners();
  }

  Future<void> signOut() async {
    SessionService().stopSessionListener();
    if (_currentSessionId != null) {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await SessionService().revokeSession(
          _currentSessionId!,
          currentUser.uid,
          currentUser.displayName ?? currentUser.email ?? 'Self'
        );
      }
      _currentSessionId = null;
    }
    await _googleSignIn.signOut();
    await _auth.signOut();
    notifyListeners();
  }
}
