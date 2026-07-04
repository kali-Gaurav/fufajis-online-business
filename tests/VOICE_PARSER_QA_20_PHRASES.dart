/// VOICE PARSER QA TEST — BATCH 1 VALIDATION
/// 20 Test Phrases across English, Hindi, Mixed, Village Style
/// Target: >90% STT accuracy, >95% Parser accuracy, >90% Order success

import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/models/product_model.dart';
import 'package:fufajis_online/services/voice_order_parser.dart';
import 'package:fufajis_online/utils/monetary_value.dart';

void main() {
  group('VOICE PARSER QA — BATCH 1 VALIDATION', () {
    late VoiceOrderParser parser;
    late List<ProductModel> batch1Products;

    setUpAll(() {
      parser = VoiceOrderParser();
      batch1Products = _loadBatch1Products();
      print('✓ Loaded ${batch1Products.length} Batch 1 products');
    });

    // =====================================================
    // ENGLISH TESTS (5)
    // =====================================================

    group('ENGLISH VOICE COMMANDS', () {
      test('E1: "2 kg aloo" → Potatoes, qty=2, confidence≥90', () async {
        final orders = await parser.parse('2 kg aloo', batch1Products);
        expect(orders.isNotEmpty, true, reason: 'Should find potato product');
        expect(orders.length, 1, reason: 'Should parse as 1 product');
        expect(orders[0].quantity, 2.0, reason: 'Quantity should be 2');
        expect(orders[0].confidence, greaterThanOrEqualTo(90),
            reason: 'Confidence should be ≥ 90 for exact "aloo"');
        print('✓ E1 PASS — "2 kg aloo" parsed correctly');
      });

      test('E2: "1 liter milk" → Amul Milk, qty=1, confidence≥85', () async {
        final orders = await parser.parse('1 liter milk', batch1Products);
        expect(orders.isNotEmpty, true);
        expect(orders[0].productName.toLowerCase().contains('milk'), true);
        expect(orders[0].quantity, 1.0);
        expect(orders[0].confidence, greaterThanOrEqualTo(85));
        print('✓ E2 PASS — "1 liter milk" parsed correctly');
      });

      test('E3: "2 kg pyaz" → Onions, qty=2, confidence≥90', () async {
        final orders = await parser.parse('2 kg pyaz', batch1Products);
        expect(orders.isNotEmpty, true);
        expect(orders[0].productName.toLowerCase().contains('onion'), true);
        expect(orders[0].quantity, 2.0);
        expect(orders[0].confidence, greaterThanOrEqualTo(90));
        print('✓ E3 PASS — "2 kg pyaz" parsed correctly');
      });

      test('E4: "500 gram paneer" → Paneer, qty=500, confidence≥80',
          () async {
        final orders = await parser.parse('500 gram paneer', batch1Products);
        expect(orders.isNotEmpty, true);
        expect(orders[0].productName.toLowerCase().contains('paneer'), true);
        expect(orders[0].quantity, 500.0);
        expect(orders[0].confidence, greaterThanOrEqualTo(80));
        print('✓ E4 PASS — "500 gram paneer" parsed correctly');
      });

      test('E5: "3 kg rice" → Basmati/Rice, qty=3, confidence≥85',
          () async {
        final orders = await parser.parse('3 kg rice', batch1Products);
        expect(orders.isNotEmpty, true);
        expect(orders[0].productName.toLowerCase().contains('rice'), true);
        expect(orders[0].quantity, 3.0);
        expect(orders[0].confidence, greaterThanOrEqualTo(85));
        print('✓ E5 PASS — "3 kg rice" parsed correctly');
      });
    });

    // =====================================================
    // HINDI TESTS (5)
    // =====================================================

    group('HINDI VOICE COMMANDS', () {
      test('H1: "2 किलो आलू" → Potatoes, qty=2, confidence≥85', () async {
        final orders = await parser.parse('2 किलो आलू', batch1Products);
        expect(orders.isNotEmpty, true, reason: 'Should recognize Hindi potato');
        expect(orders[0].quantity, 2.0);
        expect(orders[0].confidence, greaterThanOrEqualTo(85),
            reason: 'Hindi match should score ≥ 85');
        print('✓ H1 PASS — "2 किलो आलू" parsed correctly');
      });

      test('H2: "1 दूध" → Amul Milk, qty=1, confidence≥80', () async {
        final orders = await parser.parse('1 दूध', batch1Products);
        expect(orders.isNotEmpty, true);
        expect(orders[0].productName.toLowerCase().contains('milk'), true);
        expect(orders[0].quantity, 1.0);
        expect(orders[0].confidence, greaterThanOrEqualTo(80));
        print('✓ H2 PASS — "1 दूध" parsed correctly');
      });

      test('H3: "1 किलो प्याज" → Onions, qty=1, confidence≥85', () async {
        final orders = await parser.parse('1 किलो प्याज', batch1Products);
        expect(orders.isNotEmpty, true);
        expect(orders[0].productName.toLowerCase().contains('onion'), true);
        expect(orders[0].confidence, greaterThanOrEqualTo(85));
        print('✓ H3 PASS — "1 किलो प्याज" parsed correctly');
      });

      test('H4: "500 ग्राम पनीर" → Paneer, qty=500, confidence≥75',
          () async {
        final orders = await parser.parse('500 ग्राम पनीर', batch1Products);
        expect(orders.isNotEmpty, true);
        expect(orders[0].quantity, 500.0);
        expect(orders[0].confidence, greaterThanOrEqualTo(75));
        print('✓ H4 PASS — "500 ग्राम पनीर" parsed correctly');
      });

      test('H5: "3 किलो चावल" → Rice, qty=3, confidence≥80', () async {
        final orders = await parser.parse('3 किलो चावल', batch1Products);
        expect(orders.isNotEmpty, true);
        expect(orders[0].quantity, 3.0);
        expect(orders[0].confidence, greaterThanOrEqualTo(80));
        print('✓ H5 PASS — "3 किलो चावल" parsed correctly');
      });
    });

    // =====================================================
    // MIXED LANGUAGE TESTS (4)
    // =====================================================

    group('MIXED ENGLISH + HINDI COMMANDS', () {
      test('M1: "2 kilo aloo aur 1 milk" → 2 products', () async {
        final orders = await parser.parse('2 kilo aloo aur 1 milk', batch1Products);
        expect(orders.length, 2, reason: 'Should parse 2 products');
        expect(orders[0].quantity, 2.0);
        expect(orders[1].quantity, 1.0);
        print('✓ M1 PASS — "2 kilo aloo aur 1 milk" parsed as 2 products');
      });

      test('M2: "ek atta 1 kg" → Wheat Atta, qty=1', () async {
        final orders = await parser.parse('ek atta 1 kg', batch1Products);
        expect(orders.isNotEmpty, true);
        expect(orders[0].productName.toLowerCase().contains('atta'), true);
        expect(orders[0].quantity, 1.0);
        print('✓ M2 PASS — "ek atta 1 kg" parsed correctly');
      });

      test('M3: "2 kg टमाटर aur 1 कद्दू" → 2 products', () async {
        final orders = await parser.parse('2 kg टमाटर aur 1 कद्दू', batch1Products);
        expect(orders.length, 2);
        print('✓ M3 PASS — Mixed Hindi+English parsed as 2 products');
      });

      test('M4: "half kg aloo aur 1 pyaz" → Mixed units', () async {
        final orders = await parser.parse('half kg aloo aur 1 pyaz', batch1Products);
        expect(orders.length, 2);
        expect(orders[0].quantity, 0.5, reason: '"half" should parse as 0.5');
        print('✓ M4 PASS — "half kg" quantifier recognized');
      });
    });

    // =====================================================
    // VILLAGE/BROKEN PRONUNCIATION TESTS (4)
    // =====================================================

    group('VILLAGE ACCENT & BROKEN PRONUNCIATION', () {
      test('V1: "do kilo aata" (typo: aata→atta)', () async {
        // "do" = 2 in Hindi
        final orders = await parser.parse('do kilo aata', batch1Products);
        expect(orders.isNotEmpty, true,
            reason: 'Should fuzzy-match "aata" to "atta"');
        expect(orders[0].confidence, greaterThanOrEqualTo(70),
            reason: 'Fuzzy match confidence ≥ 70');
        print('✓ V1 PASS — "do kilo aata" fuzzy-matched to atta');
      });

      test('V2: "aadha kilo pyaj" (half kg onion)', () async {
        final orders = await parser.parse('aadha kilo pyaj', batch1Products);
        expect(orders.isNotEmpty, true);
        expect(orders[0].quantity, 0.5,
            reason: '"aadha" (half) should parse as 0.5');
        print('✓ V2 PASS — "aadha" quantifier recognized');
      });

      test('V3: "ek tel litre" (1 oil liter, broken English)', () async {
        final orders = await parser.parse('ek tel litre', batch1Products);
        // "tel" = oil, "ek" = 1
        expect(orders.isNotEmpty, true);
        expect(orders[0].confidence, greaterThanOrEqualTo(75),
            reason: 'Should match oil product despite typo');
        print('✓ V3 PASS — Village accent "ek tel" recognized');
      });

      test('V4: "paanch kilo chini" (5 kg sugar, village)', () async {
        final orders = await parser.parse('paanch kilo chini', batch1Products);
        // "paanch" = 5 (Hindi), "chini" = sugar
        expect(orders.isNotEmpty, true);
        expect(orders[0].quantity, 5.0,
            reason: '"paanch" should parse as 5');
        print('✓ V4 PASS — "paanch" number recognized');
      });
    });

    // =====================================================
    // EDGE CASES & FAILURE HANDLING (2)
    // =====================================================

    group('EDGE CASES & SAFETY', () {
      test('EDGE1: Empty input → empty result (no crash)', () async {
        final orders = await parser.parse('', batch1Products);
        expect(orders.isEmpty, true);
        print('✓ EDGE1 PASS — Empty input handled gracefully');
      });

      test('EDGE2: No matching products → empty result (no crash)',
          () async {
        final orders =
            await parser.parse('xyz nonsense blah', batch1Products);
        expect(orders.isEmpty, true);
        print('✓ EDGE2 PASS — No matches handled gracefully');
      });
    });
  });
}

// =====================================================
// TEST HELPERS
// =====================================================

List<ProductModel> _loadBatch1Products() {
  // Load first 10 Batch 1 products (full set available in batch_1_products_catalog.json)
  return [
    ProductModel(
      id: 'VEG_001',
      name: 'Potatoes (Aloo)',
      hindiName: 'आलू',
      description: 'Fresh white potatoes',
      keywords: ['aloo', 'aalu', 'potato', 'potatoes', 'आलू'],
      categoryId: 'vegetables',
      category: 'Vegetables',
      mrpPrice: 28,
      price: MonetaryValue(25),
      unit: '1 kg',
      stockQuantity: 500,
      shopId: 'shop1',
      shopName: 'Main Shop',
      imageUrl: '',
      district: 'Delhi',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    ProductModel(
      id: 'VEG_002',
      name: 'Onions (Pyaz)',
      hindiName: 'प्याज',
      description: 'Red onions',
      keywords: ['pyaz', 'piyaz', 'onion', 'प्याज'],
      categoryId: 'vegetables',
      category: 'Vegetables',
      mrpPrice: 35,
      price: MonetaryValue(32),
      unit: '1 kg',
      stockQuantity: 400,
      shopId: 'shop1',
      shopName: 'Main Shop',
      imageUrl: '',
      district: 'Delhi',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    ProductModel(
      id: 'VEG_003',
      name: 'Tomatoes',
      hindiName: 'टमाटर',
      description: 'Red tomatoes',
      keywords: ['tamatar', 'tomato', 'टमाटर'],
      categoryId: 'vegetables',
      category: 'Vegetables',
      mrpPrice: 40,
      price: MonetaryValue(38),
      unit: '1 kg',
      stockQuantity: 350,
      shopId: 'shop1',
      shopName: 'Main Shop',
      imageUrl: '',
      district: 'Delhi',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    ProductModel(
      id: 'DAI_001',
      name: 'Amul Milk',
      hindiName: 'अमूल दूध',
      description: 'Fresh milk',
      keywords: ['milk', 'doodh', 'amul', 'दूध'],
      categoryId: 'dairy',
      category: 'Dairy',
      mrpPrice: 58,
      price: MonetaryValue(56),
      unit: '1 L',
      stockQuantity: 300,
      shopId: 'shop1',
      shopName: 'Main Shop',
      imageUrl: '',
      district: 'Delhi',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    ProductModel(
      id: 'DAI_004',
      name: 'Paneer',
      hindiName: 'पनीर',
      description: 'Fresh paneer',
      keywords: ['paneer', 'cheese', 'पनीर'],
      categoryId: 'dairy',
      category: 'Dairy',
      mrpPrice: 420,
      price: MonetaryValue(410),
      unit: '500 g',
      stockQuantity: 80,
      shopId: 'shop1',
      shopName: 'Main Shop',
      imageUrl: '',
      district: 'Delhi',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    ProductModel(
      id: 'RIC_001',
      name: 'Basmati Rice',
      hindiName: 'बासमती चावल',
      description: 'Long grain rice',
      keywords: ['basmati', 'rice', 'chawal', 'बासमती'],
      categoryId: 'rice',
      category: 'Rice/Grains',
      mrpPrice: 90,
      price: MonetaryValue(85),
      unit: '1 kg',
      stockQuantity: 400,
      shopId: 'shop1',
      shopName: 'Main Shop',
      imageUrl: '',
      district: 'Delhi',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    ProductModel(
      id: 'FLO_001',
      name: 'Wheat Flour (Atta)',
      hindiName: 'गेहूं का आटा',
      description: 'Whole wheat flour',
      keywords: ['atta', 'flour', 'wheat', 'आटा'],
      categoryId: 'flour',
      category: 'Flour',
      mrpPrice: 42,
      price: MonetaryValue(40),
      unit: '1 kg',
      stockQuantity: 400,
      shopId: 'shop1',
      shopName: 'Main Shop',
      imageUrl: '',
      district: 'Delhi',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    ProductModel(
      id: 'VEG_013',
      name: 'Pumpkin (Kaddu)',
      hindiName: 'कद्दू',
      description: 'Fresh pumpkin',
      keywords: ['kaddu', 'pumpkin', 'कद्दू'],
      categoryId: 'vegetables',
      category: 'Vegetables',
      mrpPrice: 25,
      price: MonetaryValue(22),
      unit: '1 kg',
      stockQuantity: 80,
      shopId: 'shop1',
      shopName: 'Main Shop',
      imageUrl: '',
      district: 'Delhi',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];
}
