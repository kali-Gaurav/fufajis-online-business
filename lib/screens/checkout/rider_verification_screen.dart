import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RiderVerificationScreen extends StatefulWidget {
  final String orderId;

  const RiderVerificationScreen({super.key, required this.orderId});

  @override
  State<RiderVerificationScreen> createState() => _RiderVerificationScreenState();
}

class _RiderVerificationScreenState extends State<RiderVerificationScreen> {
  late Map<String, dynamic> riderInfo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRiderInfo();
  }

  void _loadRiderInfo() async {
    // Simulated rider data - replace with API call
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      riderInfo = {
        'name': 'Raj Kumar',
        'phone': '+919876543210',
        'photoUrl': 'https://via.placeholder.com/150',
        'rating': 4.8,
        'reviews': 245,
        'vehicleType': 'Two-wheeler',
        'vehicleNumber': 'DL01AB1234',
      };
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Your Rider'), centerTitle: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Rider Photo
                  CircleAvatar(radius: 50, backgroundImage: NetworkImage(riderInfo['photoUrl'])),
                  const SizedBox(height: 16),

                  // Name & Phone
                  Text(
                    riderInfo['name'],
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    riderInfo['phone'],
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),

                  // Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${riderInfo['rating']} (${riderInfo['reviews']} reviews)',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Vehicle Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vehicle Details',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Type: ${riderInfo['vehicleType']}'),
                        Text('Number: ${riderInfo['vehicleNumber']}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Verification Badges
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Icon(Icons.verified, color: Colors.green, size: 30),
                          SizedBox(height: 4),
                          Text('Verified', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      Column(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 30),
                          SizedBox(height: 4),
                          Text('Highly Rated', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/orders'),
                      child: const Text('Confirm & Complete Order'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
