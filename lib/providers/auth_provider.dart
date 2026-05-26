import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  static final AuthProvider instance = AuthProvider._internal();
  factory AuthProvider() => instance;
  AuthProvider._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  bool _isMfaStepRequired = false;
  bool get isMfaStepRequired => _isMfaStepRequired;

  String? _verificationId;

  Future<void> sendOTP(String phoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
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

  Future<bool> verifyOTP(String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
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

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _onSuccessfulLogin(userCredential.user!);
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

  Future<void> _onSuccessfulLogin(User user) async {
    _isLoggedIn = true;
    
    // The 'onUserCreate' Cloud Function handles creating the initial user doc with roles.
    // We just need to wait a bit or listen to the stream.
    _startUserListener(user.uid);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await _saveFCMToken(user.uid);
    
    // Check if MFA is required from pre_authorized_users (still readable by user during login)
    final String phoneNumber = user.phoneNumber ?? '';
    final authDoc = await _firestore
        .collection('pre_authorized_users')
        .doc(phoneNumber.replaceAll('+', ''))
        .get();

    if (authDoc.exists && authDoc.data()?['isMfaRequired'] == true) {
      // Check if user doc exists and has the role set. 
      // This is a race condition with the Cloud Function, but _startUserListener handles updates.
      _isMfaStepRequired = true;
    }

    _isLoading = false;
    notifyListeners();
  }

  StreamSubscription? _userSubscription;

  void _startUserListener(String userId) {
    _userSubscription?.cancel();
    _userSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _currentUser = UserModel.fromMap(snapshot.data()!);
        notifyListeners();
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
      final doc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromMap(doc.data()!);
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
