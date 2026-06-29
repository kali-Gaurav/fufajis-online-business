import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Phone OTP Authentication Service for Fufaji
/// Handles phone number verification and OTP sign-in flows
class FirebasePhoneAuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _verificationId;
  int? _resendToken;
  String? _phoneNumber;

  bool _isLoading = false;
  String? _error;

  String? get verificationId => _verificationId;
  String? get phoneNumber => _phoneNumber;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Send OTP to phone number
  Future<void> sendOTP(String phoneNumber) async {
    try {
      _isLoading = true;
      _error = null;
      _phoneNumber = phoneNumber;
      notifyListeners();

      // Verify phone number format
      if (!phoneNumber.startsWith('+')) {
        throw Exception('Phone number must start with country code (+)');
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 120),
        verificationCompleted: _handleVerificationCompleted,
        verificationFailed: _handleVerificationFailed,
        codeSent: _handleCodeSent,
        codeAutoRetrievalTimeout: _handleCodeAutoRetrievalTimeout,
      );
    } catch (e) {
      _error = 'Failed to send OTP: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Resend OTP with exponential backoff
  Future<void> resendOTP(String phoneNumber) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 120),
        forceResendingToken: _resendToken,
        verificationCompleted: _handleVerificationCompleted,
        verificationFailed: _handleVerificationFailed,
        codeSent: _handleCodeSent,
        codeAutoRetrievalTimeout: _handleCodeAutoRetrievalTimeout,
      );
    } catch (e) {
      _error = 'Failed to resend OTP: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Verify OTP and sign in user
  Future<UserCredential?> verifyOTP(String otp) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (_verificationId == null) {
        throw Exception('Verification ID is null. Please send OTP first.');
      }

      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      _isLoading = false;
      notifyListeners();

      return userCredential;
    } on FirebaseAuthException catch (e) {
      _error = _handleAuthException(e);
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Failed to verify OTP: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Handle verification completed automatically
  Future<void> _handleVerificationCompleted(
      PhoneAuthCredential credential) async {
    try {
      await _auth.signInWithCredential(credential);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Auto-verification failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Handle verification failed
  void _handleVerificationFailed(FirebaseAuthException e) {
    _error = _handleAuthException(e);
    _isLoading = false;
    notifyListeners();
  }

  /// Handle code sent
  void _handleCodeSent(String verificationId, int? resendToken) {
    _verificationId = verificationId;
    _resendToken = resendToken;
    _isLoading = false;
    notifyListeners();
  }

  /// Handle code auto-retrieval timeout
  void _handleCodeAutoRetrievalTimeout(String verificationId) {
    _verificationId = verificationId;
  }

  /// Parse Firebase Auth exceptions to user-friendly messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Invalid OTP. Please check and try again.';
      case 'session-expired':
        return 'OTP session expired. Please request a new OTP.';
      case 'missing-phone-number':
        return 'Phone number is required.';
      case 'invalid-phone-number':
        return 'Invalid phone number format.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  /// Clear verification state
  void clearVerification() {
    _verificationId = null;
    _resendToken = null;
    _phoneNumber = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Get current user
  User? getCurrentUser() => _auth.currentUser;

  /// Check if user is authenticated
  bool isUserAuthenticated() => _auth.currentUser != null;

  /// Get current user token
  Future<String?> getUserToken({bool forceRefresh = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final idTokenResult = await user.getIdTokenResult(forceRefresh);
      return idTokenResult.token;
    } catch (e) {
      _error = 'Failed to get user token: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  /// Get custom claims from token
  Future<Map<String, dynamic>?> getCustomClaims() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Force refresh to get latest custom claims
      final idTokenResult = await user.getIdTokenResult(true);
      return idTokenResult.claims;
    } catch (e) {
      _error = 'Failed to get custom claims: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  /// Logout current user
  Future<void> logout() async {
    try {
      await _auth.signOut();
      clearVerification();
    } catch (e) {
      _error = 'Logout failed: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Delete user account
  Future<void> deleteUser() async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // Delete user document from Firestore first
      await _firestore.collection('users').doc(user.uid).delete();

      // Then delete auth user
      await user.delete();

      _isLoading = false;
      clearVerification();
    } catch (e) {
      _error = 'Failed to delete user: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Listen to auth state changes
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Listen to user changes
  Stream<User?> userChanges() => _auth.userChanges();

  /// Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      await user.updateProfile(
        displayName: displayName,
        photoURL: photoURL,
      );

      // Update Firestore document
      await _firestore.collection('users').doc(user.uid).update({
        if (displayName != null) 'name': displayName,
        if (photoURL != null) 'avatar': photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _error = 'Failed to update profile: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }
}
