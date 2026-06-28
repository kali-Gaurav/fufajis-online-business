import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../utils/app_theme.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../../services/storage_service.dart';

class DisputeScreen extends StatefulWidget {
  final String orderId;

  const DisputeScreen({super.key, required this.orderId});

  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen> {
  final TextEditingController _reasonController = TextEditingController();
  final List<XFile> _images = [];
  final List<String> _selectedItemIds = [];
  bool _isSubmitting = false;
  OrderModel? _order;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final order = await context.read<OrderProvider>().getOrderById(widget.orderId);
    setState(() => _order = order);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (image != null) {
      setState(() => _images.add(image));
    }
  }

  Future<void> _submitDispute() async {
    if (_selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one item')));
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please describe the issue')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final storage = StorageService();
      List<String> imageUrls = [];
      for (var file in _images) {
        final url = await storage.uploadImage(File(file.path), 'disputes/${widget.orderId}');
        if (url != null) imageUrls.add(url);
      }

      final orderProvider = context.read<OrderProvider>();
      await orderProvider.createReturnRequest(
        orderId: widget.orderId,
        reason: _reasonController.text.trim(),
        itemIds: _selectedItemIds,
        proofImages: imageUrls,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispute submitted. Our team will review it within 24 hours.'), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    if (_order == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));

    return Scaffold(
      appBar: AppBar(title: const Text('Report an Issue')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select problematic items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ..._order!.items.map((item) {
              final isSelected = _selectedItemIds.contains(item.productId);
              return CheckboxListTile(
                title: Text(item.productName),
                subtitle: Text('₹${item.price} x ${item.quantity}'),
                value: isSelected,
                activeColor: AppTheme.primary,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedItemIds.add(item.productId);
                    } else {
                      _selectedItemIds.remove(item.productId);
                    }
                  });
                },
              );
            }),
            const Divider(height: 40),
            const Text('Describe the issue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'e.g. Items are damaged, missing, or poor quality...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Upload Photos (Proof)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(color: AppTheme.grey100, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.add_a_photo, color: AppTheme.grey500),
                    ),
                  ),
                  ..._images.map((img) => Container(
                    width: 100,
                    margin: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(image: FileImage(File(img.path)), fit: BoxFit.cover),
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitDispute,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SUBMIT COMPLAINT', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
