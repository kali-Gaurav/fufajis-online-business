import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/purchase_order.dart';

class DatabaseSeeder {
  /// Seeds mock Purchase Orders and configures products with structured shelf coordinates.
  static Future<void> seedPurchaseOrdersAndLocations({
    required String shopId,
    required String branchId,
  }) async {
    final firestore = FirebaseFirestore.instance;

    // 1. Seed or Update Mock Products with Structured Coordinates
    final productsRef = firestore
        .collection('shops')
        .doc(shopId)
        .collection('branches')
        .doc(branchId)
        .collection('products');

    final productsSnapshot = await productsRef.get();

    // Standard list of items to seed if empty
    final List<Map<String, dynamic>> defaultMockProducts = [
      {
        'id': 'prod_amul_milk',
        'name': 'Amul Taaza Milk 1L',
        'description': 'Fresh pasteurized double toned milk.',
        'price': 66.0,
        'originalPrice': 66.0,
        'unit': 'Litre',
        'category': 'dairy',
        'shopId': shopId,
        'shopName': 'Fufaji Store',
        'imageUrl': 'https://example.com/amul_milk.png',
        'stockQuantity': 100,
        'minimumStock': 10,
        'isAvailable': true,
        'barcode': '8901262150284',
        'brand': 'Amul',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'prod_parleg',
        'name': 'Parle-G Gold Biscuits 100g',
        'description': 'Original Gluco biscuits.',
        'price': 10.0,
        'originalPrice': 10.0,
        'unit': 'Packet',
        'category': 'snacks',
        'shopId': shopId,
        'shopName': 'Fufaji Store',
        'imageUrl': 'https://example.com/parleg.png',
        'stockQuantity': 250,
        'minimumStock': 20,
        'isAvailable': true,
        'barcode': '8901725181222',
        'brand': 'Parle',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'prod_maggi',
        'name': 'Maggi Masala Noodles 70g',
        'description': '2-Minute instant noodles.',
        'price': 14.0,
        'originalPrice': 14.0,
        'unit': 'Packet',
        'category': 'snacks',
        'shopId': shopId,
        'shopName': 'Fufaji Store',
        'imageUrl': 'https://example.com/maggi.png',
        'stockQuantity': 300,
        'minimumStock': 25,
        'isAvailable': true,
        'barcode': '8901058002315',
        'brand': 'Nestle',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'prod_atta',
        'name': 'Aashirvaad Shudh Chakki Atta 5kg',
        'description': '100% whole wheat flour.',
        'price': 260.0,
        'originalPrice': 260.0,
        'unit': 'kg',
        'category': 'groceries',
        'shopId': shopId,
        'shopName': 'Fufaji Store',
        'imageUrl': 'https://example.com/atta.png',
        'stockQuantity': 50,
        'minimumStock': 5,
        'isAvailable': true,
        'barcode': '8901725191917',
        'brand': 'Aashirvaad',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }
    ];

    if (productsSnapshot.docs.isEmpty) {
      // Create default products
      for (var p in defaultMockProducts) {
        final productId = p['id'] as String;
        await productsRef.doc(productId).set(p);
      }
    }

    // Now, assign structured locations to all products under this branch
    final updatedSnapshot = await productsRef.get();
    int i = 1;
    for (var doc in updatedSnapshot.docs) {
      final zone = String.fromCharCode(65 + (i % 3)); // 'A', 'B', 'C'
      final aisle = (i % 4) + 1; // 1, 2, 3, 4
      final shelf = (i % 3) + 1; // 1, 2, 3
      final bin = (i % 2) + 1; // 1, 2

      await doc.reference.update({
        'branchLocations.$branchId': {
          'zone': zone,
          'aisle': aisle,
          'shelf': shelf,
          'bin': bin,
        }
      });
      i++;
    }

    // 2. Seed Mock Purchase Orders (POs)
    final poRef = firestore
        .collection('shops')
        .doc(shopId)
        .collection('branches')
        .doc(branchId)
        .collection('purchase_orders');

    // Remove existing test POs to avoid cluttering
    final existingPOs = await poRef.get();
    for (var poDoc in existingPOs.docs) {
      await poDoc.reference.delete();
    }

    // Retrieve fresh product IDs and names to reference in our POs
    final freshProducts = await productsRef.get();
    final itemsList = freshProducts.docs.map((doc) {
      final data = doc.data();
      return {
        'productId': doc.id,
        'productName': data['name'] ?? 'Mock Product',
        'price': (data['price'] ?? 10.0) as double,
        'unit': (data['unit'] ?? 'packet') as String,
      };
    }).toList();

    if (itemsList.isEmpty) return;

    // PO 1: Distributor "Vrindavan Dairy Distributors"
    final String po1Id = 'PO-${10000 + i}';
    final po1Items = [
      {
        'productId': itemsList[0]['productId'],
        'productName': itemsList[0]['productName'],
        'quantity': 50,
        'unit': itemsList[0]['unit'],
        'estimatedCost': itemsList[0]['price'] * 0.85, // 15% trade discount
      },
      if (itemsList.length > 1)
        {
          'productId': itemsList[1]['productId'],
          'productName': itemsList[1]['productName'],
          'quantity': 100,
          'unit': itemsList[1]['unit'],
          'estimatedCost': itemsList[1]['price'] * 0.85,
        }
    ];

    double po1Total = po1Items.fold(0.0, (sum, item) {
      final cost = (item['estimatedCost'] as num).toDouble();
      final qty = item['quantity'] as int;
      return sum + (cost * qty);
    });

    await poRef.doc(po1Id).set({
      'id': po1Id,
      'shopId': shopId,
      'distributorName': 'Vrindavan Dairy & Snacks Distributors',
      'items': po1Items,
      'totalAmount': po1Total,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'sent', // Ready to be received
    });

    // PO 2: Distributor "Rajasthan Grain Merchants"
    final String po2Id = 'PO-${20000 + i}';
    final po2Items = [
      if (itemsList.length > 2)
        {
          'productId': itemsList[2]['productId'],
          'productName': itemsList[2]['productName'],
          'quantity': 80,
          'unit': itemsList[2]['unit'],
          'estimatedCost': itemsList[2]['price'] * 0.90,
        },
      if (itemsList.length > 3)
        {
          'productId': itemsList[3]['productId'],
          'productName': itemsList[3]['productName'],
          'quantity': 30,
          'unit': itemsList[3]['unit'],
          'estimatedCost': itemsList[3]['price'] * 0.90,
        }
    ];

    double po2Total = po2Items.fold(0.0, (sum, item) {
      final cost = (item['estimatedCost'] as num).toDouble();
      final qty = item['quantity'] as int;
      return sum + (cost * qty);
    });

    await poRef.doc(po2Id).set({
      'id': po2Id,
      'shopId': shopId,
      'distributorName': 'Rajasthan Grain Merchants & Staples',
      'items': po2Items,
      'totalAmount': po2Total,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'draft',
    });
  }
}
