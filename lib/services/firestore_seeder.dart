import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../utils/monetary_value.dart';

class FirestoreSeeder {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Main method to seed the entire Firestore catalog
  static Future<void> seedDatabase() async {
    const String shopId = 'shop_001';
    const String branchId = 'branch_001';
    const String shopName = 'Fufaji Store';

    try {
      debugPrint('[Seeder] Starting Firestore seeding...');

      // 1. Seed Shop and Branch Configurations
      await _db.collection('shops').doc(shopId).set({
        'id': shopId,
        'name': shopName,
        'phone': '919876543210',
        'address': 'Plot 45, Tonk Road, Jaipur, Rajasthan',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('shops').doc(shopId).collection('branches').doc(branchId).set({
        'id': branchId,
        'name': 'Main Baran Branch',
        'shopId': shopId,
        'isPrimary': true,
        'phone': '919876543210',
        'address': 'Jalawar Road, Tel Factory, Baran, Rajasthan 325205',
        'latitude': 25.1006,
        'longitude': 76.5156,
        'maxDeliveryRadiusKm': 8.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[Seeder] Shop & Branch configurations seeded.');

      // 2. Pre-authorize an owner and worker for testing
      await _db.collection('pre_authorized_users').doc('919876543210').set({
        'role': 'UserRole.owner',
        'name': 'Fufaji Owner',
        'isMfaRequired': false,
      });

      await _db.collection('pre_authorized_users').doc('918888888888').set({
        'role': 'UserRole.employee',
        'name': 'Ramesh Kumar',
        'isMfaRequired': false,
      });

      debugPrint('[Seeder] Pre-authorized test users seeded.');

      // 3. Setup Catalog Products
      final List<ProductModel> products = [
        ProductModel(
          id: 'prod_tomato',
          name: 'Fresh Organic Tomatoes (Desi)',
          description:
              'Directly sourced juicy, farm-fresh desi organic tomatoes. Perfect for curries, salads, and chutneys.',
          price: MonetaryValue(40.0),
          originalPrice: MonetaryValue(40.0),
          unit: 'kg',
          categoryId: 'vegetables',
          category: 'Vegetables',
          subCategory: 'fresh-veggies',
          shopId: shopId,
          shopName: shopName,
          imageUrl: 'https://images.unsplash.com/photo-1595855759920-86582396756a?w=400',
          stockQuantity: 150,
          minimumStock: 20,
          district: 'Jaipur',
          village: 'Chomu',
          farmerName: 'Ram Singh Ji',
          isOrganicCertified: true,
          harvestDate: DateTime.now().subtract(const Duration(days: 1)),
          createdAt: DateTime.now().subtract(const Duration(days: 90)),
          updatedAt: DateTime.now(),
          branchStock: {branchId: 150},
          branchLocations: {
            branchId: {'zone': 'Aisle 1', 'shelf': '3', 'bin': 'A', 'category': 'vegetables'},
          },
        ),
        ProductModel(
          id: 'prod_banana',
          name: 'Organic Bananas (Robusta)',
          description: 'Naturally ripened chemical-free bananas packed with energy and potassium.',
          price: MonetaryValue(50.0),
          originalPrice: MonetaryValue(60.0),
          unit: 'dozen',
          categoryId: 'fruits',
          category: 'Fruits',
          subCategory: 'fresh-fruits',
          shopId: shopId,
          shopName: shopName,
          imageUrl: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=400',
          stockQuantity: 80,
          minimumStock: 15,
          district: 'Sawai Madhopur',
          village: 'Khandar',
          farmerName: 'Harish Chandra',
          isOrganicCertified: true,
          harvestDate: DateTime.now().subtract(const Duration(days: 2)),
          createdAt: DateTime.now().subtract(const Duration(days: 90)),
          updatedAt: DateTime.now(),
          branchStock: {branchId: 80},
          branchLocations: {
            branchId: {'zone': 'Aisle 1', 'shelf': '1', 'bin': 'B', 'category': 'fruits'},
          },
        ),
        ProductModel(
          id: 'prod_atta',
          name: 'Sujata Chakki Fresh Atta',
          description: '100% whole wheat chakki fresh atta with natural dietary fibers.',
          price: MonetaryValue(420.0),
          originalPrice: MonetaryValue(420.0),
          unit: '10kg bag',
          categoryId: 'groceries',
          category: 'Groceries',
          subCategory: 'flours',
          shopId: shopId,
          shopName: shopName,
          imageUrl: 'https://images.unsplash.com/photo-1574316071802-0d684efa7bf5?w=400',
          stockQuantity: 120,
          minimumStock: 25,
          district: 'Jaipur',
          village: 'Bassi',
          farmerName: 'Shri Ram Swaroop',
          isOrganicCertified: false,
          createdAt: DateTime.now().subtract(const Duration(days: 90)),
          updatedAt: DateTime.now(),
          branchStock: {branchId: 120},
          branchLocations: {
            branchId: {'zone': 'Aisle 4', 'shelf': '2', 'bin': 'C', 'category': 'groceries'},
          },
        ),
        ProductModel(
          id: 'prod_basmati_rice',
          name: 'Premium Basmati Rice (Rozana)',
          description: 'Long grain, aromatic Rozana Basmati Rice perfect for daily use.',
          price: MonetaryValue(95.0),
          originalPrice: MonetaryValue(110.0),
          unit: 'kg',
          categoryId: 'groceries',
          category: 'Groceries',
          subCategory: 'rice-grains',
          shopId: shopId,
          shopName: shopName,
          imageUrl: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400',
          stockQuantity: 200,
          minimumStock: 30,
          district: 'Kota',
          village: 'Sangod',
          farmerName: 'Mukesh Choudhary',
          isOrganicCertified: false,
          createdAt: DateTime.now().subtract(const Duration(days: 90)),
          updatedAt: DateTime.now(),
          branchStock: {branchId: 200},
          branchLocations: {
            branchId: {'zone': 'Aisle 3', 'shelf': '1', 'bin': 'D', 'category': 'groceries'},
          },
        ),
        ProductModel(
          id: 'prod_milk',
          name: 'Fufaji Fresh Farm Milk (A2)',
          description:
              'Pure, organic, unpasteurized A2 cow milk delivered directly from local dairy farms.',
          price: MonetaryValue(64.0),
          originalPrice: MonetaryValue(64.0),
          unit: 'litre',
          categoryId: 'dairy',
          category: 'Dairy',
          subCategory: 'milk',
          shopId: shopId,
          shopName: shopName,
          imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400',
          stockQuantity: 60,
          minimumStock: 10,
          district: 'Jaipur',
          village: 'Amer',
          farmerName: 'Devi Lal dairy',
          isOrganicCertified: true,
          createdAt: DateTime.now().subtract(const Duration(days: 90)),
          updatedAt: DateTime.now(),
          branchStock: {branchId: 60},
          branchLocations: {
            branchId: {'zone': 'Chilled-1', 'shelf': '1', 'bin': 'A', 'category': 'dairy'},
          },
        ),
      ];

      // 4. Batch add products
      final batch = _db.batch();
      for (var product in products) {
        final docRef = _db.collection('products').doc(product.id);
        batch.set(docRef, product.toMap());
      }
      await batch.commit();
      debugPrint('[Seeder] 5 Products seeded successfully.');

      // 5. Seed Price History changes for timeline widgets
      for (var product in products) {
        final changesRef = _db.collection('price_history').doc(product.id).collection('changes');

        // History entry 1 (Old price 30 days ago)
        await changesRef.add({
          'oldPrice': product.price * 1.15,
          'newPrice': product.price,
          'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 65))),
          'note': 'Weekly local market adjustment',
        });

        // History entry 2 (Older price 75 days ago)
        await changesRef.add({
          'oldPrice': product.price * 0.95,
          'newPrice': product.price * 1.15,
          'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 80))),
          'note': 'Procurement cost adjustment',
        });
      }
      debugPrint('[Seeder] Price history streams successfully populated.');

      debugPrint('[Seeder] Seeding completely successfully. Ready for real-time operation!');
    } catch (e) {
      debugPrint('[Seeder] ERROR seeding catalog: $e');
    }
  }
}
