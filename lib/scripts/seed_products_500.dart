/// Seed script for 500 catalog products to Firestore
/// Run this to populate the full catalog for LOOP 2

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../utils/monetary_value.dart';

Future<void> seedProducts500(FirebaseFirestore firestore) async {
  print('[Seed] Starting to seed 500 products...');
  
  // Wipe existing products to prevent ID collisions and clean the slate
  print('[Seed] Wiping existing products...');
  final snapshot = await firestore.collection('products').get();
  final deleteBatch = firestore.batch();
  for (final doc in snapshot.docs) {
    deleteBatch.delete(doc.reference);
  }
  await deleteBatch.commit();
  print('[Seed] Wiped ${snapshot.docs.length} existing products.');

  // Load JSON
  print('[Seed] Loading products_500.json from assets...');
  final jsonString = await rootBundle.loadString('assets/data/products_500.json');
  final List<dynamic> jsonList = json.decode(jsonString);
  
  final productsRef = firestore.collection('products');
  var batch = firestore.batch();
  int batchCount = 0;
  int totalCount = 0;

  for (final item in jsonList) {
    final Map<String, dynamic> data = item as Map<String, dynamic>;
    
    // Construct ProductModel
    final product = ProductModel.fromMap(data);
    
    final docRef = productsRef.doc(product.id);
    batch.set(docRef, product.toMap());
    
    batchCount++;
    totalCount++;

    // Firestore batch is limited to 500 writes
    if (batchCount == 400) {
      await batch.commit();
      print('[Seed] Committed $batchCount products...');
      batch = firestore.batch(); // Create a new batch
      batchCount = 0;
    }
  }

  // Commit any remaining
  if (batchCount > 0) {
    await batch.commit();
    print('[Seed] Committed remaining $batchCount products...');
  }

  print('[Seed] ✅ Seeded $totalCount products successfully!');
}
