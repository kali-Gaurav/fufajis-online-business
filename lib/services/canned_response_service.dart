import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/canned_response_model.dart';

/// Task #66 — Canned Response Service
///
/// CRUD wrapper around the Firestore `canned_responses` collection.
/// Call [seedDefaults] once (idempotent) to populate sensible starter macros.
class CannedResponseService {
  static final CannedResponseService _instance =
      CannedResponseService._internal();
  factory CannedResponseService() => _instance;
  CannedResponseService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('canned_responses');

  // ─── Streams ────────────────────────────────────────────────────────────────

  /// Live stream of all canned responses, ordered for display.
  Stream<List<CannedResponseModel>> watchAll() {
    return _col
        .orderBy('sortOrder')
        .orderBy('title')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CannedResponseModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Live stream of canned responses for a specific category.
  Stream<List<CannedResponseModel>> watchByCategory(String category) {
    return _col
        .where('category', isEqualTo: category)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CannedResponseModel.fromMap(d.id, d.data()))
            .toList());
  }

  // ─── CRUD ────────────────────────────────────────────────────────────────────

  Future<void> add({
    required String title,
    required String text,
    String category = 'General',
    int sortOrder = 0,
  }) async {
    await _col.add(CannedResponseModel(
      id: '',
      title: title.trim(),
      text: text.trim(),
      category: category,
      sortOrder: sortOrder,
      createdAt: DateTime.now(),
    ).toMap());
  }

  Future<void> update(
    String id, {
    String? title,
    String? text,
    String? category,
    int? sortOrder,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title.trim();
    if (text != null) updates['text'] = text.trim();
    if (category != null) updates['category'] = category;
    if (sortOrder != null) updates['sortOrder'] = sortOrder;
    if (updates.isEmpty) return;
    await _col.doc(id).update(updates);
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  // ─── Seed defaults ──────────────────────────────────────────────────────────

  /// Idempotent: only writes if the collection is empty.
  Future<void> seedDefaults() async {
    final snap = await _col.limit(1).get();
    if (snap.docs.isNotEmpty) return; // already seeded

    final defaults = [
      // Greetings
      ('Greeting', 'Hello! Thank you for contacting Fufaji Support. How can I help you today? 😊', 'Greeting', 0),
      ('Welcome Back', 'Welcome back! Great to hear from you. What can we assist you with? 🙏', 'Greeting', 1),
      // Order
      ('Order Confirmed', 'Your order has been confirmed and is being prepared! 🛒✅', 'Order', 10),
      ('Order Status', 'I can check your order status right away. Could you please share your order number?', 'Order', 11),
      ('Packing In Progress', '📦 Great news! Your order is currently being packed and will be ready for dispatch soon.', 'Order', 12),
      // Delivery
      ('Out For Delivery', '🚚 Your order is out for delivery! It should reach you within the next 30-60 minutes.', 'Delivery', 20),
      ('Delivery Delay', '⏳ We apologize for the slight delay in your delivery. Our team is working to get it to you as soon as possible.', 'Delivery', 21),
      ('Delivered', '🎉 Your order has been delivered! Thank you for shopping with Fufaji. We hope you enjoy your purchase!', 'Delivery', 22),
      // Refund
      ('Refund Processed', '✅ Your refund has been processed and will reflect in your account within 3-5 business days.', 'Refund', 30),
      ('Refund Initiated', 'I have initiated a refund for your order. You will receive a confirmation shortly.', 'Refund', 31),
      // Stock
      ('Item Out of Stock', 'We apologize, but the item you ordered is currently out of stock. We are restocking soon and will notify you.', 'Stock', 40),
      ('Item Available', 'Great news! The item you were looking for is now back in stock. 🎊', 'Stock', 41),
      // General
      ('Cancellation Policy', 'Orders can be cancelled within 1 hour of placing. After dispatch, cancellations are not possible. Please contact us if you need help.', 'General', 50),
      ('Escalate to Manager', 'I will escalate your concern to our manager who will follow up with you shortly. We sincerely apologize for the inconvenience.', 'General', 51),
      ('Thank You', 'Thank you for your patience! Is there anything else I can help you with? 🙏', 'General', 52),
    ];

    final batch = _db.batch();
    for (final (title, text, category, sort) in defaults) {
      final ref = _col.doc();
      batch.set(ref, {
        'title': title,
        'text': text,
        'category': category,
        'sortOrder': sort,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
