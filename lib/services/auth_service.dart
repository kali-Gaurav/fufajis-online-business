import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsignin;
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'employee_auth_service.dart';
import 'owner_auth_service.dart';
import 'session_service.dart';
import '../models/employee_model.dart';
import '../models/owner_model.dart';
import 'api_client.dart';

enum AuthResultStatus { ownerAccess, employeeAccess, deliveryAgentAccess, customerAccess, unauthorized, error }

class AuthResult {
  final AuthResultStatus status;
  final Owner? owner;
  final Employee? employee;
  final String? message;

  AuthResult({required this.status, this.owner, this.employee, this.message});
}

class AuthService extends ChangeNotifier {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final gsignin.GoogleSignIn _googleSignIn = gsignin.GoogleSignIn.instance;

  String? _currentSessionId;
  bool _isSessionRevoked = false;

  String? get currentSessionId => _currentSessionId;
  bool get isSessionRevoked => _isSessionRevoked;

  void resetSessionRevoked() {
    _isSessionRevoked = false;
    notifyListeners();
  }

  /// Unified Operational Sign-In (Owner, Admin, Employee, Delivery Agent)
  /// Uses ID + Credential (Password/PIN) via secure Cloud Function
  Future<AuthResult> signInOperationalUser(String loginId, String credential, String expectedRole) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('verifyStaffCredentials');
      final result = await callable.call({
        'loginId': loginId,
        'pin': credential, // The backend field is named 'pin', but it accepts a password as well
        'role': expectedRole,
      });

      final customToken = result.data['token'] as String?;
      if (customToken == null) {
        return AuthResult(status: AuthResultStatus.error, message: 'Invalid response from server.');
      }

      final UserCredential userCredential = await _auth.signInWithCustomToken(customToken);
      final User? user = userCredential.user;
      if (user == null) {
        return AuthResult(status: AuthResultStatus.error, message: 'Custom token sign-in failed.');
      }

      _isSessionRevoked = false;
      _currentSessionId = await SessionService().createSession(user.uid);
      SessionService().listenToSession(_currentSessionId!, _handleSessionRevocation);
      notifyListeners();

      // Return appropriate status based on role
      if (expectedRole == 'owner' || expectedRole == 'admin') {
        return AuthResult(status: AuthResultStatus.ownerAccess);
      } else if (expectedRole == 'employee') {
        return AuthResult(status: AuthResultStatus.employeeAccess);
      } else if (expectedRole == 'deliveryAgent') {
        return AuthResult(status: AuthResultStatus.deliveryAgentAccess);
      }

      return AuthResult(status: AuthResultStatus.unauthorized, message: 'Unknown role.');
    } on FirebaseFunctionsException catch (e) {
      return AuthResult(status: AuthResultStatus.error, message: e.message ?? 'Authentication failed.');
    } catch (e) {
      return AuthResult(status: AuthResultStatus.error, message: e.toString());
    }
  }

  /// Handle Google Sign-In and check authorization level
  Future<AuthResult> signInWithGoogle() async {
    try {
      final gsignin.GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) {
        return AuthResult(status: AuthResultStatus.error, message: 'Google sign-in cancelled');
      }

      final gsignin.GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final authorization = await googleUser.authorizationClient.authorizeScopes(['email', 'profile', 'openid']);
      final String accessToken = authorization.accessToken;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null || user.email == null) {
        await _googleSignIn.signOut();
        await _auth.signOut();
        return AuthResult(
          status: AuthResultStatus.error,
          message: 'Failed to retrieve email from Google',
        );
      }

      String email = user.email!;

      // 1. Sync Custom Claims from Backend
      try {
        await ApiClient().post('/admin/claims/sync');
      } catch (e) {
        debugPrint('Error syncing custom claims: $e');
        // Continue and try to refresh token anyway
      }

      // 2. Force refresh token to load newly set claims
      final IdTokenResult tokenResult = await user.getIdTokenResult(true);
      final Map<String, dynamic>? claims = tokenResult.claims;
      final String? role = claims?['role'] as String?;

      if (role == null) {
        await _googleSignIn.signOut();
        await _auth.signOut();
        return AuthResult(
          status: AuthResultStatus.unauthorized,
          message: 'Your email is not authorized for access.',
        );
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
      return AuthResult(
        status: AuthResultStatus.unauthorized,
        message: 'Unauthorized or deactivated account.',
      );
    } catch (e) {
      debugPrint('Error during Google Sign In: $e');
      return AuthResult(status: AuthResultStatus.error, message: e.toString());
    }
  }

  /// Sign in with Apple ID (iOS/macOS only — Task 34).
  Future<AuthResult> signInWithApple() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return AuthResult(
        status: AuthResultStatus.error,
        message: 'Apple Sign-In is only available on iOS/macOS.',
      );
    }
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user;
      if (user == null) {
        return AuthResult(status: AuthResultStatus.error, message: 'Apple Sign-In failed.');
      }

      final email = user.email ?? appleCredential.email;
      if (email == null || email.isEmpty) {
        await _auth.signOut();
        return AuthResult(
          status: AuthResultStatus.unauthorized,
          message: 'Apple account has no associated email.',
        );
      }

      // Sync claims and resolve role (same as Google flow)
      try {
        await ApiClient().post('/admin/claims/sync');
      } catch (_) {}

      final tokenResult = await user.getIdTokenResult(true);
      final role = tokenResult.claims?['role'] as String?;

      if (role == null) {
        await _auth.signOut();
        return AuthResult(
          status: AuthResultStatus.unauthorized,
          message: 'Apple account not authorized.',
        );
      }

      if (role == 'owner') {
        final owner = await OwnerAuthService.verifyOwnerAccess(email);
        if (owner != null) {
          _isSessionRevoked = false;
          _currentSessionId = await SessionService().createSession(user.uid);
          SessionService().listenToSession(_currentSessionId!, _handleSessionRevocation);
          notifyListeners();
          return AuthResult(status: AuthResultStatus.ownerAccess, owner: owner);
        }
      } else if (role == 'employee') {
        final employee = await EmployeeAuthService.verifyEmployeeAccess(email, user.uid);
        if (employee != null) {
          _isSessionRevoked = false;
          _currentSessionId = await SessionService().createSession(user.uid);
          SessionService().listenToSession(_currentSessionId!, _handleSessionRevocation);
          notifyListeners();
          return AuthResult(status: AuthResultStatus.employeeAccess, employee: employee);
        }
      }

      await _auth.signOut();
      return AuthResult(
        status: AuthResultStatus.unauthorized,
        message: 'Unauthorized or deactivated account.',
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult(status: AuthResultStatus.error, message: 'Apple Sign-In cancelled.');
      }
      return AuthResult(
        status: AuthResultStatus.error,
        message: 'Apple Sign-In error: ${e.message}',
      );
    } catch (e) {
      return AuthResult(status: AuthResultStatus.error, message: e.toString());
    }
  }

  /// Whether the current device supports Apple Sign-In.
  static bool get isAppleSignInAvailable => Platform.isIOS || Platform.isMacOS;

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
          currentUser.displayName ?? currentUser.email ?? 'Self',
        );
      }
      _currentSessionId = null;
    }
    await _googleSignIn.signOut();
    await _auth.signOut();
    notifyListeners();
  }
}
