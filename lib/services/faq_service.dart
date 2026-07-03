import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/faq_article_model.dart';

/// Task #69 — FAQ Knowledgebase Service
///
/// Backs the `faq_articles` Firestore collection with:
/// • Full CRUD (owner/employee management)
/// • Idempotent default seeding (20 e-commerce FAQs)
/// • Offline keyword-based article matching for the AI auto-link feature
class FaqService {
  static final FaqService _instance = FaqService._internal();
  factory FaqService() => _instance;
  FaqService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('faq_articles');

  // ── Streams ─────────────────────────────────────────────────────────────

  /// All active articles for display, ordered by category then sortOrder.
  Stream<List<FaqArticleModel>> watchAll() {
    return _col
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs.map((d) => FaqArticleModel.fromMap(d.id, d.data())).toList());
  }

  /// Live stream for a specific category.
  Stream<List<FaqArticleModel>> watchByCategory(String category) {
    return _col
        .where('isActive', isEqualTo: true)
        .where('category', isEqualTo: category)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs.map((d) => FaqArticleModel.fromMap(d.id, d.data())).toList());
  }

  /// Admin stream (includes inactive articles for management UI).
  Stream<List<FaqArticleModel>> watchAdmin() {
    return _col
        .orderBy('category')
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs.map((d) => FaqArticleModel.fromMap(d.id, d.data())).toList());
  }

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> add({
    required String question,
    required String answer,
    String category = 'General',
    List<String> keywords = const [],
    int sortOrder = 0,
  }) async {
    final now = DateTime.now();
    await _col.add(
      FaqArticleModel(
        id: '',
        question: question.trim(),
        answer: answer.trim(),
        category: category,
        keywords: keywords,
        sortOrder: sortOrder,
        createdAt: now,
      ).toMap(),
    );
  }

  Future<void> update(
    String id, {
    String? question,
    String? answer,
    String? category,
    List<String>? keywords,
    int? sortOrder,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (question != null) updates['question'] = question.trim();
    if (answer != null) updates['answer'] = answer.trim();
    if (category != null) updates['category'] = category;
    if (keywords != null) updates['keywords'] = keywords;
    if (sortOrder != null) updates['sortOrder'] = sortOrder;
    if (isActive != null) updates['isActive'] = isActive;
    await _col.doc(id).update(updates);
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  /// Increment view count whenever an article is auto-linked in chat.
  Future<void> incrementViews(String id) async {
    await _col.doc(id).update({'views': FieldValue.increment(1)});
  }

  // ── Matching ─────────────────────────────────────────────────────────────

  /// Given a customer [message], returns the best-matching FAQ article
  /// (or null if no article scores above [minScore]).
  ///
  /// Algorithm:
  ///   1. Tokenise the message and each article's question + keywords.
  ///   2. Count exact token overlaps (keywords get 2× weight).
  ///   3. Normalise by max possible hits; return top-scorer if ≥ [minScore].
  ///
  /// Fully offline — no external API.
  Future<FaqArticleModel?> findMatch(String message, {double minScore = 0.15}) async {
    if (message.trim().isEmpty) return null;

    final snap = await _col.where('isActive', isEqualTo: true).get();
    if (snap.docs.isEmpty) return null;

    final articles = snap.docs.map((d) => FaqArticleModel.fromMap(d.id, d.data())).toList();

    final msgTokens = _tokenize(message);
    if (msgTokens.isEmpty) return null;

    FaqArticleModel? best;
    double bestScore = 0.0;

    for (final article in articles) {
      final qTokens = _tokenize(article.question);
      final kTokens = article.keywords.expand((kw) => _tokenize(kw)).toSet();

      int hits = 0;
      int maxPossible = qTokens.length + kTokens.length * 2;
      if (maxPossible == 0) continue;

      for (final t in msgTokens) {
        if (qTokens.contains(t)) hits++;
        if (kTokens.contains(t)) hits += 2; // keywords weighted higher
      }

      final score = hits / maxPossible;
      if (score > bestScore) {
        bestScore = score;
        best = article;
      }
    }

    if (bestScore >= minScore) return best;
    return null;
  }

  /// Synchronous version for already-loaded lists (used in chat UI).
  FaqArticleModel? findMatchSync(
    String message,
    List<FaqArticleModel> articles, {
    double minScore = 0.15,
  }) {
    if (message.trim().isEmpty || articles.isEmpty) return null;

    final msgTokens = _tokenize(message);
    if (msgTokens.isEmpty) return null;

    FaqArticleModel? best;
    double bestScore = 0.0;

    for (final article in articles.where((a) => a.isActive)) {
      final qTokens = _tokenize(article.question);
      final kTokens = article.keywords.expand((kw) => _tokenize(kw)).toSet();

      int hits = 0;
      final maxPossible = qTokens.length + kTokens.length * 2;
      if (maxPossible == 0) continue;

      for (final t in msgTokens) {
        if (qTokens.contains(t)) hits++;
        if (kTokens.contains(t)) hits += 2;
      }

      final score = hits / maxPossible;
      if (score > bestScore) {
        bestScore = score;
        best = article;
      }
    }

    if (bestScore >= minScore) return best;
    return null;
  }

  // ── Seed defaults ─────────────────────────────────────────────────────────

  /// Idempotent: only seeds if the collection is empty.
  Future<void> seedDefaults() async {
    final snap = await _col.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final defaults = <(String, String, String, List<String>, int)>[
      // (question, answer, category, keywords, sortOrder)

      // Orders
      (
        'How do I track my order?',
        'You can track your order in real time by opening the Orders section '
            'in the Fufaji app. Tap your active order to see live delivery status '
            'and estimated arrival time.',
        'Orders',
        ['track', 'tracking', 'where', 'order', 'status', 'delivery'],
        10,
      ),

      (
        'Can I cancel my order?',
        'Orders can be cancelled within 1 hour of placement if they have not '
            'yet been dispatched. Go to Orders → select the order → tap Cancel. '
            'After dispatch, cancellation is no longer possible.',
        'Orders',
        ['cancel', 'cancellation', 'stop', 'undo'],
        11,
      ),

      (
        'Why was my order cancelled?',
        'Orders are cancelled automatically when (1) payment fails, '
            '(2) the item goes out of stock after placement, or (3) the delivery '
            'address is outside our service area. A full refund is issued '
            'immediately.',
        'Orders',
        ['cancelled', 'automatically', 'why', 'cancel', 'refund'],
        12,
      ),

      (
        'What should I do if I received a wrong item?',
        'We sincerely apologise! Please tap "Report Issue" on the order in '
            'the app, attach a photo, and select "Wrong item received". Our team '
            'will arrange a replacement or refund within 24 hours.',
        'Orders',
        ['wrong', 'incorrect', 'item', 'received', 'mistake'],
        13,
      ),

      // Delivery
      (
        'What is the delivery time?',
        'Standard deliveries are fulfilled within 30–90 minutes depending on '
            'your location. Express slots (where available) target 30 minutes. '
            'You can see the estimated time before placing your order.',
        'Delivery',
        ['delivery', 'time', 'minutes', 'hours', 'fast', 'quick', 'long'],
        20,
      ),

      (
        'Why is my delivery delayed?',
        'Delays can occur during peak hours, bad weather, or high order '
            'volumes. Your delivery agent will contact you if there is a '
            'significant delay. We appreciate your patience!',
        'Delivery',
        ['delay', 'late', 'slow', 'stuck', 'waiting'],
        21,
      ),

      (
        'My order shows "Delivered" but I didn\'t receive it.',
        'Please check with your building security / neighbours first. If the '
            'item is genuinely missing, report it within 4 hours of the delivery '
            'timestamp via the app or contact our support team.',
        'Delivery',
        ['delivered', 'missing', 'not received', 'lost', 'stolen'],
        22,
      ),

      (
        'Do you deliver to my area?',
        'We currently serve select areas. Enter your pin code in the app '
            'at checkout to confirm availability. We are expanding rapidly, '
            'so please check back if your area is not yet covered.',
        'Delivery',
        ['area', 'location', 'pincode', 'serviceable', 'available'],
        23,
      ),

      // Payments
      (
        'What payment methods are accepted?',
        'We accept UPI (GPay, PhonePe, Paytm), credit/debit cards, net '
            'banking, and Cash on Delivery (COD) for eligible orders.',
        'Payments',
        ['payment', 'pay', 'upi', 'card', 'cash', 'cod', 'method'],
        30,
      ),

      (
        'How do I get a refund?',
        'Refunds are processed automatically to your original payment method '
            'within 5–7 business days. For COD orders, refunds are credited to '
            'your Fufaji Wallet. Contact support if you haven\'t received yours.',
        'Payments',
        ['refund', 'money', 'back', 'return', 'wallet'],
        31,
      ),

      (
        'Why was my payment charged twice?',
        'Duplicate charges usually reverse automatically within 24–48 hours '
            'as a bank pre-auth. If not, share your transaction ID with us and '
            'we will resolve it within 1 business day.',
        'Payments',
        ['charged', 'double', 'twice', 'extra', 'deducted'],
        32,
      ),

      // Products & Quality
      (
        'The product I received was expired / damaged.',
        'We are very sorry! Please tap "Report Issue" on the order, attach '
            'a photo, and select "Expired" or "Damaged". We will issue a full '
            'refund or replacement within 24 hours.',
        'Quality',
        ['expired', 'damaged', 'broken', 'stale', 'rotten', 'quality'],
        40,
      ),

      (
        'Can I request a specific brand?',
        'We stock a wide range of brands. You can search by brand name in '
            'the app. If your preferred brand is not listed, use the "Request a '
            'Product" feature and we\'ll try to source it.',
        'Quality',
        ['brand', 'specific', 'request', 'product', 'stock'],
        41,
      ),

      // Account
      (
        'How do I change my delivery address?',
        'Go to Profile → Saved Addresses → Add or Edit an address. You can '
            'also change the delivery address at checkout before placing an order.',
        'Account',
        ['address', 'change', 'update', 'location', 'profile'],
        50,
      ),

      (
        'How do I delete my account?',
        'You can request account deletion from Profile → Settings → '
            '"Delete Account". All your personal data will be erased within '
            '30 days in compliance with DPDP regulations.',
        'Account',
        ['delete', 'account', 'close', 'remove', 'data', 'GDPR'],
        51,
      ),

      // Returns
      (
        'What is the return policy?',
        'Perishable items (fresh produce, dairy, meat) cannot be returned '
            'but we will issue a refund if quality is unsatisfactory. For other '
            'categories, returns are accepted within 7 days of delivery. Items '
            'must be unused and in original packaging.',
        'Returns',
        ['return', 'policy', 'exchange', 'replace', '7 days'],
        60,
      ),

      (
        'How do I initiate a return?',
        'Open the order in the app → tap "Return Item" → select the reason '
            '→ upload a photo → submit. Our rider will collect the item at a '
            'convenient time you choose.',
        'Returns',
        ['return', 'initiate', 'how', 'start', 'exchange'],
        61,
      ),

      // Wallet
      (
        'How does the Fufaji Wallet work?',
        'Your Fufaji Wallet stores credits from refunds and promotional offers. '
            'It is applied automatically at checkout. Wallet balance does not '
            'expire and can be used for any order.',
        'Wallet',
        ['wallet', 'credits', 'balance', 'money', 'cashback'],
        70,
      ),

      // General
      (
        'How do I contact customer support?',
        'You can reach us here via chat, or call our helpline at 1800-XXX-XXXX '
            '(Mon–Sat, 9 AM – 9 PM). For urgent issues, use the in-app chat for '
            'the fastest response.',
        'General',
        ['contact', 'support', 'help', 'phone', 'call', 'helpline'],
        80,
      ),

      (
        'Is Fufaji safe to order from?',
        'Absolutely! All our products are sourced from certified suppliers, '
            'stored in temperature-controlled warehouses, and quality-checked '
            'before dispatch. We are FSSAI licensed.',
        'General',
        ['safe', 'trust', 'certified', 'quality', 'fresh', 'FSSAI'],
        81,
      ),
    ];

    final batch = _db.batch();
    for (final (q, a, cat, kw, sort) in defaults) {
      final ref = _col.doc();
      batch.set(ref, {
        'question': q,
        'answer': a,
        'category': cat,
        'keywords': kw,
        'sortOrder': sort,
        'isActive': true,
        'views': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Set<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s]"), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2) // skip stop words like "a", "to", "is"
        .toSet();
  }
}
