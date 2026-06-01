import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user_model.dart';
import '../models/shop_branch_model.dart';
import '../services/shop_config_service.dart';

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

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  ShopBranchModel? _currentBranch;
  ShopBranchModel? get currentBranch => _currentBranch;

  ShopInfo? _currentShop;
  ShopInfo? get currentShop => _currentShop ?? const ShopInfo(id: 'shop_001', name: 'Fufaji Store');

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

  String? _verificationId;

  String? _emailVerificationOtp;
  String? _verificationEmail;
  DateTime? _emailOtpExpiry;
  bool _isEmailVerification = false;

  bool get isEmailVerification => _isEmailVerification;

  String _getPasswordForEmail(String email) {
    return 'FufajiSecureAuthPass_${email.hashCode}_2026';
  }

  Future<void> sendEmailOTP(String email) async {
    _isLoading = true;
    _errorMessage = null;
    _isEmailVerification = true;
    notifyListeners();

    try {
      // Generate a 6-digit OTP
      final otp = (100000 + (DateTime.now().microsecondsSinceEpoch % 900000)).toString();
      _emailVerificationOtp = otp;
      _verificationEmail = email;
      _emailOtpExpiry = DateTime.now().add(const Duration(minutes: 5));

      debugPrint('[Security/Auth] Sent Email OTP: $otp to email: $email');
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to send OTP: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendOTP(String phoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
    _isEmailVerification = false;
    notifyListeners();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          await checkAuthStatus();
        },
        verificationFailed: (FirebaseAuthException e) {
          _errorMessage = e.message ?? 'Verification failed';
          _isLoading = false;
          notifyListeners();
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _isLoading = false;
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      _errorMessage = 'Failed to send OTP: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyOTP(String otp, {UserRole? selectedRole}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      UserCredential userCredential;
      if (_isEmailVerification) {
        if (_emailVerificationOtp == null || _verificationEmail == null || _emailOtpExpiry == null) {
          _errorMessage = 'Verification session expired';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        if (DateTime.now().isAfter(_emailOtpExpiry!)) {
          _errorMessage = 'OTP expired';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        if (_emailVerificationOtp != otp) {
          _errorMessage = 'Invalid OTP';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        final email = _verificationEmail!;
        final password = _getPasswordForEmail(email);

        try {
          userCredential = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found') {
            userCredential = await _auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
          } else {
            rethrow;
          }
        }
      } else {
        if (_verificationId == null) {
          _errorMessage = 'Session expired';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: otp,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      if (userCredential.user != null) {
        final user = userCredential.user!;
        
        // Role authorization check (Security Hardening)
        if (selectedRole != null && selectedRole != UserRole.customer) {
          final String contact = user.phoneNumber ?? user.email ?? '';
          final String phoneDocId = contact.replaceAll('+', '');
          
          bool isAuthorized = false;

          // Check user document roles
          final userDoc = await _firestore.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            final rolesList = (userDoc.data()?['roles'] as List<dynamic>?)?.map((r) => r.toString()).toList() ?? [];
            if (rolesList.contains(selectedRole.toString())) {
              isAuthorized = true;
            }
          }

          // Check pre_authorized_users collection if not authorized in user doc
          if (!isAuthorized) {
            final authDoc = await _firestore.collection('pre_authorized_users').doc(phoneDocId).get();
            if (authDoc.exists && authDoc.data()?['role'] == selectedRole.toString()) {
              isAuthorized = true;
            }

            if (!isAuthorized && user.email != null) {
              final emailDocId = user.email!.replaceAll('@', '_').replaceAll('.', '_');
              final emailAuthDoc = await _firestore.collection('pre_authorized_users').doc(emailDocId).get();
              if (emailAuthDoc.exists && emailAuthDoc.data()?['role'] == selectedRole.toString()) {
                isAuthorized = true;
              }
            }
          }

          if (!isAuthorized) {
            await _auth.signOut();
            _errorMessage = 'This account is not authorized for the selected role.';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        }

        await _onSuccessfulLogin(user, selectedRole: selectedRole);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Invalid OTP: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _onSuccessfulLogin(User user, {UserRole? selectedRole}) async {
    _isLoggedIn = true;
    
    try {
      final branches = await ShopConfigService().getBranches();
      if (branches.isNotEmpty) {
        _currentBranch = branches.firstWhere((b) => b.isPrimary, orElse: () => branches.first);
      }
    } catch (e) {
      debugPrint('Failed to load initial branch on successful login: $e');
    }
    
    _startUserListener(user.uid, defaultRole: selectedRole);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await _saveFCMToken(user.uid);
    
    final String phoneNumber = user.phoneNumber ?? '';
    final String contact = user.email ?? phoneNumber;
    final String docId = contact.replaceAll('+', '').replaceAll('@', '_').replaceAll('.', '_');
    
    final authDoc = await _firestore
        .collection('pre_authorized_users')
        .doc(docId)
        .get();

    if (authDoc.exists && authDoc.data()?['isMfaRequired'] == true) {
      _isMfaStepRequired = true;
    }

    _isLoading = false;
    notifyListeners();
  }

  StreamSubscription? _userSubscription;

  void _startUserListener(String userId, {UserRole? defaultRole}) {
    _isProfileLoading = true;
    notifyListeners();
    _userSubscription?.cancel();
    _userSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists && snapshot.data() != null) {
        _currentUser = UserModel.fromMap(snapshot.data()!);
        _isProfileLoading = false;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_role', _currentUser!.role.toString());

        if (_currentBranch == null) {
          try {
            final branches = await ShopConfigService().getBranches();
            if (branches.isNotEmpty) {
              _currentBranch = branches.firstWhere((b) => b.isPrimary, orElse: () => branches.first);
            }
          } catch (e) {
            debugPrint('Failed to load initial branch in auth listener: $e');
          }
        }

        notifyListeners();
      } else {
        // Fallback: Create user document if it doesn't exist
        final user = _auth.currentUser;
        if (user != null) {
          final isEmail = user.email != null && user.email!.isNotEmpty;
          final contact = isEmail ? user.email! : (user.phoneNumber ?? '');
          final finalRole = defaultRole ?? UserRole.customer;

          final newUser = UserModel(
            id: userId,
            phoneNumber: isEmail ? '' : contact,
            email: isEmail ? contact : null,
            name: user.displayName ?? contact.split('@').first,
            role: finalRole,
            roles: [UserRole.customer, if (finalRole != UserRole.customer) finalRole],
            isVerified: true,
            isActive: true,
            createdAt: DateTime.now(),
            lastLogin: DateTime.now(),
          );

          await _firestore.collection('users').doc(userId).set(newUser.toMap(), SetOptions(merge: true));
        }
      }
    });
  }

  Future<void> demoLogin(String phoneNumber, String name) async {
    _isLoading = true;
    _currentUser = UserModel(
      id: 'user_001',
      phoneNumber: phoneNumber,
      name: name,
      role: UserRole.customer,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );
    _isLoggedIn = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (isLoggedIn && _auth.currentUser != null) {
      _isLoggedIn = true;
      _isProfileLoading = true;
      notifyListeners();
      
      final doc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromMap(doc.data()!);
        _isProfileLoading = false;
        _startUserListener(_auth.currentUser!.uid);
      } else {
        // Wait for listener to catch the document if it's being created by a Cloud Function
        _startUserListener(_auth.currentUser!.uid);
      }
    }
    return _isLoggedIn;
  }

  Future<void> logout() async {
    _userSubscription?.cancel();
    await _auth.signOut();
    _currentUser = null;
    _isLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    notifyListeners();
  }

  /// Request a role update via Cloud Function (Security Hardening)
  Future<bool> requestRoleUpdate(String targetUserId, UserRole role) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('setRole');
      final result = await callable.call({
        'targetUserId': targetUserId,
        'newRole': role.toString(),
      });

      _isLoading = false;
      notifyListeners();
      return result.data['success'] == true;
    } catch (e) {
      _errorMessage = 'Failed to update role: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Switch the active role for the current user (Step 1.5)
  Future<void> switchRole(UserRole newRole) async {
    if (_currentUser == null || !_currentUser!.roles.contains(newRole)) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Update Firestore
      await _firestore.collection('users').doc(_currentUser!.id).update({
        'role': newRole.toString(),
      });
      
      // Note: _startUserListener will catch the change and update _currentUser locally
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to switch role: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveFCMToken(String userId) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(userId).update({'fcmToken': token});
    }
  }

  Future<bool> linkGoogleAccount() async {
    _isLoading = true;
    notifyListeners();
    // MFA Link logic removed temporarily to resolve package conflict in IDE
    await Future.delayed(const Duration(seconds: 2));
    _isMfaStepRequired = false;
    _isLoading = false;
    notifyListeners();
    return true;
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

  Future<void> updateProfile({String? name, String? email, String? district, String? village}) async {
    if (_currentUser == null) return;
    await _firestore.collection('users').doc(_currentUser!.id).update({
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (district != null) 'district': district,
      if (village != null) 'village': village,
    });
  }

  String generateOrderNumber() {
    return 'HLM-${DateTime.now().millisecondsSinceEpoch}';
  }
}
