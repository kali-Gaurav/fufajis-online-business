import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';
import '../models/user_model.dart';
import '../models/shop_branch_model.dart';
import '../services/customer_state.dart';
import 'package:fufajis_online/services/api_client.dart';
import '../services/trusted_device_service.dart';
import '../services/account_linking_service.dart';
import '../services/user_service.dart';
import '../services/cart_sync_service.dart';
import '../services/session_service.dart';
import '../services/audit_service.dart';
import '../services/security_event_service.dart';
import '../services/device_security_service.dart';
import '../services/update_service.dart';
import '../services/mfa_service.dart';

class ShopInfo {
  final String id;
  final String name;
  const ShopInfo({required this.id, required this.name});
}

class AuthProvider with ChangeNotifier {
  static final AuthProvider instance = AuthProvider._internal();
  factory AuthProvider() => instance;
  AuthProvider._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final LocalAuthentication _localAuth = LocalAuthentication();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  CustomerState _customerState = CustomerState.guest;
  CustomerState get customerState => _customerState;

  final TrustedDeviceService _trustedDeviceService = TrustedDeviceService();
  final AccountLinkingService _accountLinkingService = AccountLinkingService();
  final UserService _userService = UserService();
  final CartSyncService _cartSyncService = CartSyncService();
  final MfaService _mfaService = MfaService();
  
  List<Map<String, dynamic>> _recentAccounts = [];
  List<Map<String, dynamic>> get recentAccounts => _recentAccounts;

  ShopBranchModel? _currentBranch;
  ShopBranchModel? get currentBranch => _currentBranch;

  ShopInfo? _currentShop;
  ShopInfo? get currentShop =>
      _currentShop ?? const ShopInfo(id: 'shop_001', name: 'Fufaji Store');

  void setCurrentBranch(ShopBranchModel? branch) {
    _currentBranch = branch;
    notifyListeners();
  }

  void setCurrentShop(ShopInfo? shop) {
    _currentShop = shop;
    notifyListeners();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  bool _isProfileLoading = false;
  bool get isProfileLoading => _isProfileLoading;

  bool _isMfaStepRequired = false;
  bool get isMfaStepRequired => _isMfaStepRequired;

  bool _isDeviceVerificationRequired = false;
  bool get isDeviceVerificationRequired => _isDeviceVerificationRequired;

  bool _isPinRequired = false;
  bool get isPinRequired => _isPinRequired;

  String? _verificationId;

  // --- Security Helpers ---

  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios_device';
    }
    return 'unknown_device';
  }

  Future<String> getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return '${androidInfo.manufacturer} ${androidInfo.model}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.name;
    }
    return 'Unknown Device';
  }

  // --- Session tracking ---
  String? _currentSessionId;
  final SessionService _sessionService = SessionService();

  // --- Auth Methods ---

  Future<bool> loginWithEmailPassword(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (userCredential.user != null) {
        await _onSuccessfulLogin(userCredential.user!);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Login failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> sendOTP(String phoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          final userCredential = await _auth.signInWithCredential(credential);
          if (userCredential.user != null) await _onSuccessfulLogin(userCredential.user!);
        },
        verificationFailed: (FirebaseAuthException e) {
          _errorMessage = e.message;
          _isLoading = false;
          notifyListeners();
        },
        codeSent: (String vid, int? token) {
          _verificationId = vid;
          _isLoading = false;
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (String vid) => _verificationId = vid,
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendOTPForCheckout(String phoneNumber) async {
    return sendOTP(phoneNumber); // Re-use sendOTP but caller won't wait for auto login
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _errorMessage = 'Google sign-in cancelled';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        final user = userCredential.user!;
        final isAuthorized = await _checkRoleAuthorization(user.email ?? '', user.uid);
        if (!isAuthorized) {
          await logout();
          _errorMessage = 'Access Denied: Not authorized.';
          notifyListeners();
          return false;
        }
        if (_currentUser?.role == UserRole.shopOwner || _currentUser?.role == UserRole.admin) {
          final deviceId = await getDeviceId();
          final isApproved = _currentUser?.approvedDevices.any((d) => d.deviceId == deviceId && d.approved) ?? false;
          if (!isApproved) {
            _isDeviceVerificationRequired = true;
            notifyListeners();
            return true;
          }
          _isPinRequired = true;
          notifyListeners();
          return true;
        }
        await _onSuccessfulLogin(user);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Google Sign-In failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> checkAndLinkDuplicateAccount(User user) async {
    // If the user signed in with Google, check if phone number exists
    if (user.phoneNumber != null) {
      final existingUid = await _accountLinkingService.checkPhoneExists(user.phoneNumber!);
      if (existingUid != null && existingUid != user.uid) {
         await _accountLinkingService.mergeAccounts(existingUid, user.uid);
      }
    }
    // Also check email if signing in with phone, etc. 
    if (user.email != null) {
       final existingUid = await _accountLinkingService.checkEmailExists(user.email!);
       if (existingUid != null && existingUid != user.uid) {
          await _accountLinkingService.mergeAccounts(existingUid, user.uid);
       }
    }
  }

  Future<void> updateUserProfile({
    String? name,
    String? email,
    String? phone,
    String? avatar,
  }) async {
    if (_currentUser == null) return;

    final updatedData = <String, dynamic>{};
    if (name != null) updatedData['name'] = name;
    if (email != null) updatedData['email'] = email;
    if (phone != null) updatedData['phoneNumber'] = phone;
    if (avatar != null) updatedData['profileImage'] = avatar;

    if (updatedData.isEmpty) return;

    await _firestore.collection('users').doc(_currentUser!.id).update(updatedData);
    
    _currentUser = _currentUser!.copyWith(
      name: name ?? _currentUser!.name,
      email: email ?? _currentUser!.email,
      phoneNumber: phone ?? _currentUser!.phoneNumber,
      profileImage: avatar ?? _currentUser!.profileImage,
    );
    notifyListeners();
  }

  Future<bool> _checkRoleAuthorization(String email, String userId) async {
    final emailDocId = email.replaceAll('@', '_').replaceAll('.', '_');
    final authDoc = await _firestore.collection('pre_authorized_users').doc(emailDocId).get();
    if (authDoc.exists) {
      final userSnap = await _firestore.collection('users').doc(userId).get();
      if (!userSnap.exists) {
        final roleStr = authDoc.data()?['role'] ?? 'UserRole.customer';
        final role = UserRole.values.firstWhere((e) => e.toString() == roleStr, orElse: () => UserRole.customer);
        final newUser = UserModel(
          id: userId,
          phoneNumber: '',
          email: email,
          name: authDoc.data()?['name'] ?? email.split('@').first,
          role: role,
          roles: [UserRole.customer, role],
          isVerified: true,
          isActive: true,
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
        );
        await _firestore.collection('users').doc(userId).set(newUser.toMap());
        _currentUser = newUser;
      } else {
        _currentUser = UserModel.fromMap(userSnap.data()!);
      }
      return true;
    }
    return _currentUser?.role != UserRole.shopOwner && _currentUser?.role != UserRole.employee;
  }

  // Delegates to DeviceSecurityService (PBKDF2) — called from auth screens
  // that do NOT use SecurityPinScreen directly (e.g. inline PIN dialogs).
  Future<bool> verifyPin(String pin) async {
    if (_currentUser == null) return false;
    final email = _currentUser!.email;
    final valid = await DeviceSecurityService.validatePinLocally(pin, email);
    if (valid) {
      _isPinRequired = false;
      notifyListeners();
    } else {
      _errorMessage = 'Invalid PIN';
      notifyListeners();
    }
    return valid;
  }

  /// Called by SecurityPinScreen after creating a new PIN during first setup.
  Future<void> saveOwnerPin(String email, String pbkdf2Hash) async {
    try {
      final snap = await _firestore
          .collection('owners')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.update({
          'pinHash': pbkdf2Hash,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      // Also update users collection for cross-reference
      if (_currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_currentUser!.id)
            .update({'pinHash': pbkdf2Hash});
        _currentUser = _currentUser!.copyWith(pinHash: pbkdf2Hash);
      }
    } catch (e) {
      debugPrint('[AuthProvider] saveOwnerPin error: $e');
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Owner Dashboard',
      );
    } catch (e) {
      return false;
    }
  }

  Future<void> requestDeviceApproval() async {
    if (_currentUser == null) return;
    final deviceId = await getDeviceId();
    final deviceName = await getDeviceName();
    final newFingerprint = DeviceFingerprint(deviceId: deviceId, deviceName: deviceName, approved: false, registeredAt: DateTime.now());
    final updatedDevices = [..._currentUser!.approvedDevices, newFingerprint];
    await _firestore.collection('users').doc(_currentUser!.id).update({
      'approvedDevices': updatedDevices.map((d) => d.toMap()).toList(),
    });
    _isDeviceVerificationRequired = true;
    _errorMessage = 'Device approval requested.';
    notifyListeners();
  }

  /// SECURITY FIX: quickLogin no longer creates an anonymous Firebase user.
  /// Anonymous users could place orders without verification — a critical flaw.
  ///
  /// Quick login now means: enter guest mode via GuestProvider (local only).
  /// Use GuestProvider.enterGuestMode() from the UI layer.
  /// This method is kept as a no-op to avoid breaking callers gradually.
  @Deprecated('Use GuestProvider.enterGuestMode() instead')
  Future<bool> quickLogin(String name, String phone) async {
    _isLoading = false;
    _errorMessage =
        'Quick login now uses guest mode. Please use GuestProvider.enterGuestMode().';
    notifyListeners();
    return false;
  }

  Future<bool> verifyOTP(String otp, {UserRole? selectedRole}) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_verificationId == null) return false;
      final credential = PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: otp);
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _onSuccessfulLogin(userCredential.user!, selectedRole: selectedRole);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOTPAndAutoCreateAccount(String otp) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_verificationId == null) return false;
      final credential = PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: otp);
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        // Auto create account
        final userModel = await _userService.ensureUserDocExists(userCredential.user!);
        await _onSuccessfulLogin(userCredential.user!, selectedRole: userModel.role);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _onSuccessfulLogin(User user, {UserRole? selectedRole}) async {
    _isLoggedIn = true;
    _customerState = CustomerState.verifiedCustomer;
    _startUserListener(user.uid, defaultRole: selectedRole);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await _saveFCMToken(user.uid);

    // Register trusted device
    await _trustedDeviceService.registerDevice(user.uid);
    _customerState = CustomerState.trustedDevice;

    // Merge cart
    await _cartSyncService.mergeCarts(user.uid);

    // Create Firestore session (enables remote logout / session revocation)
    try {
      _currentSessionId = await _sessionService.createSession(user.uid);
      _sessionService.listenToSession(_currentSessionId!, () async {
        // Session was revoked remotely — force logout
        await logout();
        await SecurityEventService().logEvent(
          event: SecurityEventType.sessionRevoked,
          userId: user.uid,
        );
      });
    } catch (e) {
      debugPrint('[AuthProvider] Session creation failed: $e');
    }

    // Audit log
    final displayName = user.displayName ?? user.email ?? user.phoneNumber ?? user.uid;
    await AuditService().logLogin(user.uid, displayName);

    // Track App Version for adoption metrics
    unawaited(UpdateService().trackUserVersion(user.uid));

    _isLoading = false;
    notifyListeners();
  }

  StreamSubscription? _userSubscription;

  void _startUserListener(String userId, {UserRole? defaultRole}) {
    _isProfileLoading = true;
    notifyListeners();
    _userSubscription?.cancel();
    _userSubscription = _firestore.collection('users').doc(userId).snapshots().listen((snapshot) async {
      if (snapshot.exists) {
        _currentUser = UserModel.fromMap(snapshot.data()!);
        _saveRecentAccount(_currentUser!);
        _isProfileLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> _saveRecentAccount(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final recentStr = prefs.getString('recent_accounts');
    List<dynamic> accounts = recentStr != null ? jsonDecode(recentStr) : [];
    
    // Remove if exists
    accounts.removeWhere((a) => a['id'] == user.id);
    
    // Add to top
    accounts.insert(0, {
      'id': user.id,
      'name': user.name,
      'phoneNumber': user.phoneNumber,
    });
    
    // Keep max 3
    if (accounts.length > 3) accounts = accounts.sublist(0, 3);
    
    await prefs.setString('recent_accounts', jsonEncode(accounts));
    _recentAccounts = accounts.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<void> loadRecentAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final recentStr = prefs.getString('recent_accounts');
    if (recentStr != null) {
      final List<dynamic> accounts = jsonDecode(recentStr);
      _recentAccounts = accounts.map((e) => e as Map<String, dynamic>).toList();
      notifyListeners();
    }
  }

  Future<bool> checkAuthStatus() async {
    await loadRecentAccounts();
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('isLoggedIn') ?? false;
    
    if (loggedIn && _auth.currentUser != null) {
      _isLoggedIn = true;
      final isTrusted = await _trustedDeviceService.isDeviceTrusted(_auth.currentUser!.uid);
      _customerState = isTrusted ? CustomerState.trustedDevice : CustomerState.verifiedCustomer;
      
      _startUserListener(_auth.currentUser!.uid);
      return true;
    }
    
    // Determine guest state based on local cart
    final localCart = await _cartSyncService.loadLocalCart();
    _customerState = localCart.isNotEmpty ? CustomerState.guestWithCart : CustomerState.guest;
    
    return false;
  }

  Future<bool> signInWithApple() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Integration with sign_in_with_apple package
      // For now, simulating success for Release Hardening
      await Future.delayed(const Duration(seconds: 1));
      return true; 
    } catch (e) {
      debugPrint('Apple Sign In Error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final userId    = _currentUser?.id ?? _auth.currentUser?.uid;
    final userName  = _currentUser?.name ?? _auth.currentUser?.email ?? 'Unknown';

    // 1. Revoke Firestore session (triggers remote logout on other screens)
    if (_currentSessionId != null && userId != null) {
      try {
        await _sessionService.revokeSession(
            _currentSessionId!, userId, userName);
      } catch (e) {
        debugPrint('[AuthProvider] Session revoke error: $e');
      }
    }
    _sessionService.stopSessionListener();
    _currentSessionId = null;

    // 2. Revoke trusted device record
    if (_currentUser != null) {
      final deviceId = await DeviceSecurityService.getDeviceId();
      await _trustedDeviceService.revokeDevice(_currentUser!.id, deviceId);
    }

    // 3. Audit log before clearing user
    if (userId != null) {
      await AuditService().logLogout(userId, userName);
    }

    // 4. Clear Firebase auth
    _userSubscription?.cancel();
    await _googleSignIn.signOut();
    await _auth.signOut();

    // 5. Clear local state
    _currentUser     = null;
    _isLoggedIn      = false;
    _customerState   = CustomerState.guest;
    _isPinRequired   = false;
    _isDeviceVerificationRequired = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    // Note: Do NOT clear guest cart — it persists for browsing.

    notifyListeners();
  }

  Future<void> _saveFCMToken(String userId) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _firestore.collection('users').doc(userId).update({'fcmToken': token});
  }

  Future<bool> linkGoogleAccount() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _errorMessage = 'Google sign-in cancelled';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final result = await _accountLinkingService.linkCredentials(user, credential);
      _isLoading = false;
      _isMfaStepRequired = false;
      notifyListeners();
      return result.linked;
    } catch (e) {
      _errorMessage = 'Failed to link Google account: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile({String? name, String? email, String? district, String? village}) async {
    if (_currentUser == null) return;
    await _firestore.collection('users').doc(_currentUser!.id).update({
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (district != null) 'district': district,
      if (village != null) 'village': village,
    });
  }

  Future<bool> setMfaEnabled(bool enabled) async {
    if (_currentUser == null) return false;
    final mfaService = MfaService();
    final result = enabled 
        ? await mfaService.enableMfa(_currentUser!) 
        : await mfaService.disableMfa(_currentUser!);
    if (result.success) {
      _currentUser = _currentUser!.copyWith(mfaEnabled: enabled);
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> requestRoleUpdate(String targetUserId, UserRole role) async {
    try {
      final result = await ApiClient.instance.post('/admin/roles/set', {
        'targetUserId': targetUserId,
        'newRole': role.toString(),
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Address>> getAddresses() async {
    if (_currentUser == null) return [];
    final snapshot = await _firestore.collection('users').doc(_currentUser!.id).collection('addresses').get();
    return snapshot.docs.map((doc) => Address.fromMap(doc.data())).toList();
  }

  Future<void> setDefaultAddress(String addressId) async {
    if (_currentUser == null) return;
    final query = await _firestore.collection('users').doc(_currentUser!.id).collection('addresses').get();
    for (var doc in query.docs) {
      await doc.reference.update({'isDefault': doc.id == addressId});
    }
  }

  Future<void> deleteAddress(String addressId) async {
    if (_currentUser == null) return;
    await _firestore.collection('users').doc(_currentUser!.id).collection('addresses').doc(addressId).delete();
  }

  Future<void> addAddress(Address address) async {
    if (_currentUser == null) return;
    await _firestore.collection('users').doc(_currentUser!.id).collection('addresses').add(address.toMap());
  }

  Future<void> updateAddress(String addressId, Address address) async {
    if (_currentUser == null) return;
    await _firestore.collection('users').doc(_currentUser!.id).collection('addresses').doc(addressId).update(address.toMap());
  }

  Future<void> updateCreditBalance(double change) async {
    if (_currentUser == null) return;
    await _firestore.collection('users').doc(_currentUser!.id).update({'creditBalance': FieldValue.increment(change)});
  }


  // ── Session & Role helpers ─────────────────────────────────────────────────

  String? get currentSessionId =>
      _currentUser?.id != null ? 'session_${_currentUser!.id}' : null;

  /// Switch the active role for multi-role users.
  Future<void> switchRole(UserRole newRole) async {
    if (_currentUser == null) return;
    await _firestore
        .collection('users')
        .doc(_currentUser!.id)
        .update({'role': newRole.name});
    // Rebuild user model with new role
    _currentUser = _currentUser!.copyWith(role: newRole);
    notifyListeners();
  }

  /// Update rider/delivery agent online status in Firestore.
  Future<void> updateOnlineStatus(bool isOnline) async {
    if (_currentUser == null) return;
    try {
      await _firestore.collection('users').doc(_currentUser!.id).update({
        'isOnline': isOnline,
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[AuthProvider] updateOnlineStatus failed: $e');
    }
  }

  Future<bool> verifyMfaCode(String code) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _mfaService.verifyChallenge(_currentUser!, code);
      if (result.success) {
        _isMfaStepRequired = false;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Verification failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendMfaChallenge() async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _mfaService.sendChallenge(_currentUser!);
      _isLoading = false;
      _errorMessage = result.success ? null : result.message;
      notifyListeners();
      return result.success;
    } catch (e) {
      _errorMessage = 'Failed to resend code: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify phone OTP (alias for verifyOTP for clarity in phone auth flow)
  Future<bool> verifyPhoneOTP(String otp) async {
    return verifyOTP(otp);
  }

  /// Clear phone verification state for retry
  void clearPhoneVerification() {
    _verificationId = null;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

}
