// ============================================================
//  GuestProvider — Local-only guest mode for Fufaji Store
//
//  ARCHITECTURE:
//  • No Firebase user is ever created for a guest.
//  • All state lives in SharedPreferences (key-prefixed "guest_").
//  • Guest can browse, search, and add to a temporary local cart.
//  • Any protected action (order, wallet, history) calls
//    triggerVerificationWall() — caller should navigate to
//    /auth/verification-wall.
//  • After real login (OTP or Google), call migrateGuestCart()
//    to merge local items into the verified customer's Firestore cart.
// ============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/cart_item_model.dart';

class GuestProvider extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────
  static final GuestProvider _instance = GuestProvider._internal();
  factory GuestProvider() => _instance;
  GuestProvider._internal();

  // ── Storage keys ───────────────────────────────────────────
  static const String _keyGuestId       = 'guest_id';
  static const String _keyGuestCart     = 'guest_cart';
  static const String _keyGuestLang     = 'guest_language';
  static const String _keyGuestTheme    = 'guest_theme';
  static const String _keyIsGuestMode   = 'guest_mode_active';

  // ── State ──────────────────────────────────────────────────
  String? _guestId;
  bool _isGuestMode = false;
  List<CartItemModel> _guestCart = [];
  String _language = 'Hindi';
  String _theme = 'Light';

  // ── Getters ────────────────────────────────────────────────
  String? get guestId     => _guestId;
  bool get isGuestMode    => _isGuestMode;
  List<CartItemModel> get guestCart => List.unmodifiable(_guestCart);
  String get language     => _language;
  String get theme        => _theme;

  int get guestCartItemCount =>
      _guestCart.fold(0, (sum, item) => sum + item.quantity);

  double get guestCartTotal =>
      _guestCart.fold(0.0, (sum, item) => sum + item.totalPrice.toDouble());

  // ── Initialise (call once at app start) ────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    _isGuestMode = prefs.getBool(_keyIsGuestMode) ?? false;

    if (_isGuestMode) {
      // Restore or generate guest ID
      _guestId = prefs.getString(_keyGuestId);
      if (_guestId == null || _guestId!.isEmpty) {
        _guestId = const Uuid().v4();
        await prefs.setString(_keyGuestId, _guestId!);
      }

      // Restore cart
      final cartJson = prefs.getString(_keyGuestCart);
      if (cartJson != null) {
        try {
          final List decoded = json.decode(cartJson) as List;
          _guestCart = decoded
              .map((e) => CartItemModel.fromMap(e as Map<String, dynamic>))
              .toList();
        } catch (_) {
          _guestCart = [];
        }
      }

      _language = prefs.getString(_keyGuestLang) ?? 'Hindi';
      _theme    = prefs.getString(_keyGuestTheme) ?? 'Light';
    }

    notifyListeners();
  }

  // ── Enter guest mode ───────────────────────────────────────
  Future<void> enterGuestMode() async {
    final prefs = await SharedPreferences.getInstance();

    _guestId = const Uuid().v4();
    _isGuestMode = true;
    _guestCart = [];

    await prefs.setBool(_keyIsGuestMode, true);
    await prefs.setString(_keyGuestId, _guestId!);
    await prefs.remove(_keyGuestCart);

    debugPrint('[GuestProvider] Entered guest mode. guestId=$_guestId');
    notifyListeners();
  }

  // ── Cart operations ────────────────────────────────────────

  Future<void> addToGuestCart(CartItemModel item) async {
    final idx = _guestCart.indexWhere((c) => c.productId == item.productId);
    if (idx >= 0) {
      _guestCart[idx] = _guestCart[idx].copyWith(
        quantity: _guestCart[idx].quantity + item.quantity,
      );
    } else {
      _guestCart.add(item);
    }
    await _persistCart();
    notifyListeners();
  }

  Future<void> removeFromGuestCart(String productId) async {
    _guestCart.removeWhere((c) => c.productId == productId);
    await _persistCart();
    notifyListeners();
  }

  Future<void> updateGuestCartQuantity(String productId, int qty) async {
    final idx = _guestCart.indexWhere((c) => c.productId == productId);
    if (idx >= 0) {
      if (qty <= 0) {
        _guestCart.removeAt(idx);
      } else {
        _guestCart[idx] = _guestCart[idx].copyWith(quantity: qty);
      }
      await _persistCart();
      notifyListeners();
    }
  }

  Future<void> clearGuestCart() async {
    _guestCart = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyGuestCart);
    notifyListeners();
  }

  // ── Cart migration after verification ─────────────────────
  /// Returns the guest cart items so the caller (CartProvider) can
  /// merge them into Firestore, then clears the local guest cart.
  Future<List<CartItemModel>> extractAndClearForMigration() async {
    final items = List<CartItemModel>.from(_guestCart);
    await clearGuestCart();
    return items;
  }

  // ── Preferences ────────────────────────────────────────────
  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGuestLang, lang);
    notifyListeners();
  }

  Future<void> setTheme(String theme) async {
    _theme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGuestTheme, theme);
    notifyListeners();
  }

  // ── Exit / clear guest mode (called after real login) ──────
  Future<void> exitGuestMode() async {
    _isGuestMode = false;
    _guestId = null;
    // Do NOT clear cart here — caller should call
    // extractAndClearForMigration() first if they want cart items.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGuestMode, false);
    await prefs.remove(_keyGuestId);
    notifyListeners();
  }

  // ── Internal helpers ───────────────────────────────────────
  Future<void> _persistCart() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_guestCart.map((c) => c.toMap()).toList());
    await prefs.setString(_keyGuestCart, encoded);
  }

  // ── Protected-action guard ─────────────────────────────────
  /// Returns true if the user is a guest and should see the
  /// verification wall before proceeding.
  bool requiresVerification() => _isGuestMode;
}
