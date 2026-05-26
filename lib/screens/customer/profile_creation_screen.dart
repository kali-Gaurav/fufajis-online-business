import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class ProfileCreationScreen extends StatefulWidget {
  const ProfileCreationScreen({Key? key}) : super(key: key);

  @override
  State<ProfileCreationScreen> createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _villageController = TextEditingController();
  LatLng? _selectedLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _districtController, decoration: const InputDecoration(labelText: 'District')),
            TextField(controller: _villageController, decoration: const InputDecoration(labelText: 'Village')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Here we would integrate a Map Picker
                // For now, save current input
                final auth = Provider.of<AuthProvider>(context, listen: false);
                if (auth.currentUser != null) {
                  await FirebaseFirestore.instance.collection('users').doc(auth.currentUser!.id).update({
                    'district': _districtController.text,
                    'village': _villageController.text,
                  });
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text("Save Profile"),
            ),
          ],
        ),
      ),
    );
  }
}
