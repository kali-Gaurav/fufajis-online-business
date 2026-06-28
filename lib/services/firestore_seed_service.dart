import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreSeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Seed initial product categories
  Future<void> seedCategories() async {
    final categories = [
      {'id': 'groceries', 'name': 'Groceries', 'icon': 'shopping_basket', 'color': '4CAF50', 'order': 1},
      {'id': 'vegetables', 'name': 'Vegetables', 'icon': 'eco', 'color': '8BC34A', 'order': 2},
      {'id': 'fruits', 'name': 'Fruits', 'icon': 'apple', 'color': 'FF9800', 'order': 3},
      {'id': 'dairy', 'name': 'Dairy', 'icon': 'egg', 'color': 'FFEB3B', 'order': 4},
      {'id': 'snacks', 'name': 'Snacks', 'icon': 'fastfood', 'color': 'FF5722', 'order': 5},
      {'id': 'beverages', 'name': 'Beverages', 'icon': 'local_cafe', 'color': '03A9F4', 'order': 6},
      {'id': 'household', 'name': 'Household', 'icon': 'home', 'color': '607D8B', 'order': 7},
      {'id': 'personalCare', 'name': 'Personal Care', 'icon': 'face', 'color': 'E91E63', 'order': 8},
      {'id': 'spices', 'name': 'Spices & Masala', 'icon': 'spa', 'color': 'FF6F00', 'order': 9},
      {'id': 'medicines', 'name': 'Medicines', 'icon': 'medical_services', 'color': 'F44336', 'order': 10},
    ];

    final batch = _firestore.batch();
    for (final cat in categories) {
      final ref = _firestore.collection('categories').doc(cat['id'] as String);
      batch.set(ref, {
        ...cat,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Seed sample grocery products for Baran, Rajasthan
  Future<void> seedSampleProducts(String shopId) async {
    final products = _getBaranGroceryProducts(shopId);
    final batch = _firestore.batch();
    for (final product in products) {
      final ref = _firestore.collection('products').doc(product['id'] as String);
      batch.set(ref, product, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Seed shop configuration
  Future<void> seedShopConfig() async {
    await _firestore.collection('shopConfig').doc('main').set({
      'shopId': 'shop_001',
      'shopName': "Fufaji's Online",
      'tagline': 'Baran ka Apna Online Store',
      'address': 'Main Market, Baran, Rajasthan 325205',
      'phone': '+91-XXXXXXXXXX',
      'whatsappNumber': '+91-XXXXXXXXXX',
      'latitude': 25.1065,
      'longitude': 76.5158,
      'isOpen': true,
      'deliveryRadius': 15, // km
      'minOrderAmount': 99,
      'freeDeliveryAbove': 499,
      'deliveryCharge': 30,
      'gstNumber': '',
      'operatingHours': {
        'Monday': {'open': '08:00', 'close': '21:00'},
        'Tuesday': {'open': '08:00', 'close': '21:00'},
        'Wednesday': {'open': '08:00', 'close': '21:00'},
        'Thursday': {'open': '08:00', 'close': '21:00'},
        'Friday': {'open': '08:00', 'close': '21:00'},
        'Saturday': {'open': '08:00', 'close': '21:00'},
        'Sunday': {'open': '09:00', 'close': '20:00'},
      },
      'acceptedPayments': ['cash', 'upi', 'card', 'wallet'],
      'upiId': 'fufajionline@paytm',
      'dailyReportEnabled': true,
      'whatsappOrderEnabled': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Pre-authorize owner account
  Future<void> seedOwnerAuth(String ownerPhone) async {
    await _firestore.collection('authorizedUsers').doc(ownerPhone).set({
      'phone': ownerPhone,
      'role': 'shopOwner',
      'name': 'Fufaji (Shop Owner)',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Run full setup — call once on first launch
  Future<void> runInitialSetup({required String shopId, required String ownerPhone}) async {
    await seedCategories();
    await seedSampleProducts(shopId);
    await seedShopConfig();
    await seedOwnerAuth(ownerPhone);
    await _firestore.collection('appConfig').doc('setup').set({
      'isSetupDone': true,
      'setupAt': FieldValue.serverTimestamp(),
      'version': '1.0.0',
    }, SetOptions(merge: true));
  }

  List<Map<String, dynamic>> _getBaranGroceryProducts(String shopId) {
    final now = Timestamp.now();
    final products = <Map<String, dynamic>>[];

    // Helper to create a product
    Map<String, dynamic> p({
      required String id,
      required String name,
      required String description,
      required double price,
      double? mrp,
      required String category,
      required String unit,
      required int stock,
      bool isFeatured = false,
      List<String> tags = const [],
      String? brand,
    }) {
      return {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'originalPrice': mrp,
        'unit': unit,
        'category': category,
        'subCategory': '',
        'shopId': shopId,
        'shopName': "Fufaji's Online",
        'imageUrl': '',
        'images': [],
        'rating': 0.0,
        'reviewCount': 0,
        'stockQuantity': stock,
        'minimumStock': 10,
        'isAvailable': true,
        'isFeatured': isFeatured,
        'isOnSale': mrp != null && mrp > price,
        'isNewArrival': true,
        'isTrending': false,
        'tags': tags,
        'barcode': '',
        'brand': brand,
        'specifications': {},
        'district': 'Baran',
        'village': 'Baran',
        'createdAt': now,
        'updatedAt': now,
        'minOrderQuantity': 1,
        'maxOrderQuantity': 50,
        'weightUnit': 'kg',
        'branchStock': {},
        'branchLocations': {},
        'competitorPrices': [],
        'unitOptions': [],
        'isGroupBuyEligible': false,
        'isExpired': false,
      };
    }

    // Rice Varieties
    products.addAll([
      p(id: 'rice_basmati_1kg', name: 'Basmati Rice 1kg', description: 'Premium long-grain basmati rice, perfect for biryani and pulao', price: 85, mrp: 99, category: 'groceries', unit: '1 kg', stock: 150, isFeatured: true, tags: ['rice', 'basmati'], brand: 'India Gate'),
      p(id: 'rice_sona_masoori_5kg', name: 'Sona Masoori Rice 5kg', description: 'Medium grain sona masoori rice, ideal for daily cooking', price: 240, mrp: 265, category: 'groceries', unit: '5 kg', stock: 80, tags: ['rice', 'sona masoori']),
      p(id: 'rice_local_5kg', name: 'Baran Local Rice 5kg', description: 'Fresh locally grown rice from Baran farms', price: 180, category: 'groceries', unit: '5 kg', stock: 100, tags: ['rice', 'local']),
    ]);

    // Atta / Flour
    products.addAll([
      p(id: 'atta_chakki_5kg', name: 'Chakki Fresh Atta 5kg', description: 'Fresh whole wheat flour, ground daily, soft rotis guaranteed', price: 185, mrp: 200, category: 'groceries', unit: '5 kg', stock: 120, isFeatured: true, tags: ['atta', 'flour', 'wheat'], brand: 'Aashirvaad'),
      p(id: 'atta_10kg', name: 'Whole Wheat Atta 10kg', description: 'Premium whole wheat flour for daily chapati making', price: 340, mrp: 375, category: 'groceries', unit: '10 kg', stock: 60, tags: ['atta', 'flour']),
      p(id: 'maida_1kg', name: 'Maida 1kg', description: 'Refined flour for baking, pakoras, and puri', price: 42, category: 'groceries', unit: '1 kg', stock: 90, tags: ['maida', 'flour']),
      p(id: 'besan_1kg', name: 'Besan (Gram Flour) 1kg', description: 'Fresh besan for pakora, kadhi, and sweets', price: 75, mrp: 82, category: 'groceries', unit: '1 kg', stock: 100, tags: ['besan', 'flour', 'gram']),
    ]);

    // Dal / Lentils
    products.addAll([
      p(id: 'dal_arhar_1kg', name: 'Arhar Dal 1kg', description: 'Yellow pigeon peas, staple of every Indian kitchen', price: 140, mrp: 155, category: 'groceries', unit: '1 kg', stock: 130, isFeatured: true, tags: ['dal', 'arhar', 'toor']),
      p(id: 'dal_moong_1kg', name: 'Moong Dal 1kg', description: 'Split green gram, easy to digest and nutritious', price: 115, mrp: 130, category: 'groceries', unit: '1 kg', stock: 100, tags: ['dal', 'moong']),
      p(id: 'dal_masoor_1kg', name: 'Masoor Dal 1kg', description: 'Red lentils, quick cooking and protein-rich', price: 95, category: 'groceries', unit: '1 kg', stock: 120, tags: ['dal', 'masoor']),
      p(id: 'dal_chana_1kg', name: 'Chana Dal 1kg', description: 'Split Bengal gram, perfect for dal and pakora', price: 85, category: 'groceries', unit: '1 kg', stock: 110, tags: ['dal', 'chana']),
      p(id: 'rajma_500g', name: 'Rajma (Kidney Beans) 500g', description: 'Dark red kidney beans from Jammu', price: 65, mrp: 75, category: 'groceries', unit: '500 g', stock: 80, tags: ['rajma', 'beans']),
    ]);

    // Spices
    products.addAll([
      p(id: 'haldi_200g', name: 'Haldi Powder 200g', description: 'Pure turmeric powder, bright yellow, high curcumin content', price: 45, mrp: 55, category: 'groceries', unit: '200 g', stock: 150, tags: ['spice', 'haldi', 'turmeric']),
      p(id: 'lalmirch_100g', name: 'Lal Mirch Powder 100g', description: 'Hot red chilli powder from Rajasthan', price: 38, category: 'groceries', unit: '100 g', stock: 120, tags: ['spice', 'mirch', 'chilli']),
      p(id: 'dhaniya_200g', name: 'Dhaniya Powder 200g', description: 'Ground coriander seeds, fresh aroma', price: 35, category: 'groceries', unit: '200 g', stock: 130, tags: ['spice', 'dhaniya', 'coriander']),
      p(id: 'garam_masala_100g', name: 'Garam Masala 100g', description: 'Aromatic blend of whole spices, perfect for curries', price: 55, mrp: 65, category: 'groceries', unit: '100 g', stock: 80, isFeatured: true, tags: ['spice', 'masala'], brand: 'MDH'),
      p(id: 'jeera_100g', name: 'Jeera (Cumin Seeds) 100g', description: 'Whole cumin seeds, fragrant and fresh', price: 30, category: 'groceries', unit: '100 g', stock: 100, tags: ['spice', 'jeera', 'cumin']),
    ]);

    // Dairy
    products.addAll([
      p(id: 'milk_toned_1l', name: 'Toned Milk 1L', description: 'Fresh pasteurized toned milk, 3% fat', price: 58, category: 'dairy', unit: '1 litre', stock: 200, isFeatured: true, tags: ['milk', 'dairy']),
      p(id: 'paneer_200g', name: 'Fresh Paneer 200g', description: 'Soft, fresh cottage cheese made daily', price: 72, category: 'dairy', unit: '200 g', stock: 50, tags: ['paneer', 'dairy']),
      p(id: 'dahi_500g', name: 'Dahi (Curd) 500g', description: 'Thick, creamy curd set overnight', price: 42, category: 'dairy', unit: '500 g', stock: 80, tags: ['dahi', 'curd', 'dairy']),
      p(id: 'ghee_500ml', name: 'Pure Cow Ghee 500ml', description: 'A2 milk pure desi ghee, slow churned', price: 325, mrp: 380, category: 'dairy', unit: '500 ml', stock: 40, isFeatured: true, tags: ['ghee', 'dairy'], brand: 'Amul'),
      p(id: 'butter_100g', name: 'Amul Butter 100g', description: 'Salted table butter, fresh and creamy', price: 56, mrp: 60, category: 'dairy', unit: '100 g', stock: 60, tags: ['butter', 'dairy'], brand: 'Amul'),
    ]);

    // Snacks
    products.addAll([
      p(id: 'namkeen_bikaneri_200g', name: 'Bikaneri Bhujia 200g', description: 'Crispy gram flour noodles, Rajasthani favourite', price: 52, mrp: 60, category: 'snacks', unit: '200 g', stock: 120, isFeatured: true, tags: ['namkeen', 'bhujia', 'rajasthani']),
      p(id: 'chips_kurkure_75g', name: 'Kurkure 75g', description: 'Crunchy corn puffs in masala flavour', price: 20, category: 'snacks', unit: '75 g', stock: 200, tags: ['chips', 'kurkure', 'snack'], brand: 'Kurkure'),
      p(id: 'biscuit_parle_g_100g', name: 'Parle-G Biscuits 100g', description: 'Classic glucose biscuits loved by all', price: 10, category: 'snacks', unit: '100 g', stock: 300, tags: ['biscuit', 'parle'], brand: 'Parle'),
    ]);

    // Vegetables (listed as product for quick-add)
    products.addAll([
      p(id: 'potato_1kg', name: 'Aalu (Potato) 1kg', description: 'Fresh potatoes from Baran farms', price: 22, category: 'vegetables', unit: '1 kg', stock: 300, isFeatured: true, tags: ['potato', 'aalu', 'vegetable']),
      p(id: 'onion_1kg', name: 'Pyaz (Onion) 1kg', description: 'Red onions, pungent and fresh', price: 28, category: 'vegetables', unit: '1 kg', stock: 250, tags: ['onion', 'pyaz', 'vegetable']),
      p(id: 'tomato_1kg', name: 'Tamatar (Tomato) 1kg', description: 'Ripe red tomatoes, juicy and fresh', price: 35, category: 'vegetables', unit: '1 kg', stock: 200, tags: ['tomato', 'tamatar', 'vegetable']),
    ]);

    return products;
  }
}
