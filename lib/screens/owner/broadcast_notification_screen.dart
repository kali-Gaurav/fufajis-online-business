import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/notification_service.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';

import '../../widgets/common/fj_button.dart';
import '../../widgets/common/fj_card.dart';

class BroadcastNotificationScreen extends StatefulWidget {
  const BroadcastNotificationScreen({super.key});

  @override
  State<BroadcastNotificationScreen> createState() => _BroadcastNotificationScreenState();
}

class _BroadcastNotificationScreenState extends State<BroadcastNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  String _selectedType = 'promotion';
  ProductModel? _selectedProduct;
  bool _isSending = false;

  final List<Map<String, String>> _notifTypes = [
    {'id': 'promotion', 'label': 'Promotion / Offer'},
    {'id': 'priceDrop', 'label': 'Price Drop Alert'},
    {'id': 'backInStock', 'label': 'Back in Stock'},
    {'id': 'systemMessage', 'label': 'Store Update'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      final notificationService = NotificationService();

      await notificationService.sendBroadcastNotification(
        title: _titleController.text,
        body: _bodyController.text,
        data: {'type': _selectedType, 'productId': _selectedProduct?.id},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Broadcast Notification Queued for all customers!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Broadcast Update', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notify All Customers',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Send a push notification to every customer who has installed the Fufaji app.',
                style: TextStyle(color: AppTheme.grey600),
              ),
              const SizedBox(height: 32),

              // Notification Type
              const Text('Update Type', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: _notifTypes.map((type) {
                  final isSelected = _selectedType == type['id'];
                  return ChoiceChip(
                    label: Text(type['label']!),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedType = type['id']!);
                    },
                    selectedColor: AppTheme.primary.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primary : AppTheme.grey700,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Notification Title',
                  hintText: 'e.g. Fresh Mangoes are back!',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),

              // Body
              TextFormField(
                controller: _bodyController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message Body',
                  hintText: 'e.g. Get 10% discount on all seasonal fruits this weekend.',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Message is required' : null,
              ),
              const SizedBox(height: 24),

              // Link to Product (Optional)
              const Text(
                'Link to Product (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FjCard(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ProductModel>(
                    isExpanded: true,
                    hint: const Text('Select a product to link'),
                    value: _selectedProduct,
                    items: productProvider.products.map((p) {
                      return DropdownMenuItem(value: p, child: Text(p.name));
                    }).toList(),
                    onChanged: (p) => setState(() => _selectedProduct = p),
                  ),
                ),
              ),
              if (_selectedProduct != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Linked: ${_selectedProduct!.name}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.primary),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _selectedProduct = null),
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: AppTheme.error, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 48),

              FjButton(
                label: 'Send Broadcast Notification',
                onPressed: _isSending ? null : _sendBroadcast,
                icon: Icons.send,
                isLoading: _isSending,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
