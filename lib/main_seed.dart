import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'scripts/seed_products_500.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  print('--- FUFAJI SEEDER STARTING ---');
  try {
    await seedProducts500(FirebaseFirestore.instance);
    print('--- FUFAJI SEEDER FINISHED SUCCESSFULLY ---');
  } catch (e) {
    print('--- FUFAJI SEEDER ERROR: $e ---');
  }
  
  exit(0);
}
