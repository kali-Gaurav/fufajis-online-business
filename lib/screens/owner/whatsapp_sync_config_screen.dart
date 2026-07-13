import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/product_provider.dart';
import '../../providers/product_provider_extensions.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';

/// WhatsApp Sync Configuration Screen
/// Allows shop owners to configure and monitor WhatsApp inventory sync
class WhatsAppSyncConfigScreen extends StatefulWidget {
  const WhatsAppSyncConfigScreen({super.key});

  @override
  State<WhatsAppSyncConfigScreen> createState() => _WhatsAppSyncConfigScreenState();
}

class _WhatsAppSyncConfigScreenState extends State<WhatsAppSyncConfigScreen> {
  late TextEditingController _phoneController;
  bool _isLoading = false;
  bool _isSyncEnabled = false;
  DateTime? _lastSyncTime;
  int _syncedItemsCount = 0;
  List<ProductModel> _recentSyncedItems = [];

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _loadSyncStatus();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSyncStatus() async {
    setState(() => _isLoading = true);
    try {
      // Load sync status from provider
      final provider = context.read<ProductProvider>();
      final status = await provider.getWhatsAppSyncStatus();

      setState(() {
        _isSyncEnabled = status['enabled'] as bool? ?? false;
        _lastSyncTime = status['lastSyncTime'] as DateTime?;
        _syncedItemsCount = status['itemsCount'] as int? ?? 0;
        _recentSyncedItems = (status['recentItems'] as List? ?? []).cast<ProductModel>();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading sync status: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testSync() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ProductProvider>();
      await provider.testWhatsAppSync();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test sync initiated. Check WhatsApp for confirmation.')),
      );

      // Reload status after a delay
      await Future.delayed(const Duration(seconds: 2));
      await _loadSyncStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Test sync failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSync() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ProductProvider>();
      await provider.updateWhatsAppSyncStatus(!_isSyncEnabled);

      setState(() => _isSyncEnabled = !_isSyncEnabled);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSyncEnabled ? 'WhatsApp sync enabled' : 'WhatsApp sync disabled'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating sync status: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WhatsApp Sync Configuration',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Sync Status',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _isSyncEnabled ? AppTheme.success : Colors.grey,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _isSyncEnabled ? 'Active' : 'Inactive',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_lastSyncTime != null)
                            Text(
                              'Last sync: ${DateFormat('MMM dd, yyyy HH:mm').format(_lastSyncTime!)}',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'Total items synced: $_syncedItemsCount',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Configuration Section
                  const Text(
                    'Configuration',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // WhatsApp Business Number
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WhatsApp Business Number',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: '+91 98765 43210',
                              prefixIcon: const Icon(Icons.phone),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _testSync,
                              child: const Text('Test Sync'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Enable/Disable Toggle
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enable WhatsApp Sync',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Receive inventory updates via WhatsApp',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isSyncEnabled,
                            onChanged: _isLoading ? null : (_) => _toggleSync(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recent Synced Items
                  const Text(
                    'Recent Synced Items',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (_recentSyncedItems.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No items synced yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentSyncedItems.length,
                      itemBuilder: (context, index) {
                        final item = _recentSyncedItems[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[200],
                              ),
                              child: item.images.isNotEmpty
                                  ? Image.network(item.images[0], fit: BoxFit.cover)
                                  : const Icon(Icons.image_not_supported),
                            ),
                            title: Text(item.name),
                            subtitle: Text('₹${item.price} • Stock: ${item.stockQuantity}'),
                            trailing: const Icon(Icons.check_circle, color: AppTheme.success),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),

                  // Instructions
                  Card(
                    color: AppTheme.info.withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How to use WhatsApp Sync',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildInstructionItem(
                            '1',
                            'Send a photo of your bill to our WhatsApp number',
                          ),
                          _buildInstructionItem(
                            '2',
                            'Or send a text list like: "Add 20 apples at 150, 10 bananas at 50"',
                          ),
                          _buildInstructionItem(
                            '3',
                            'Items will be automatically added to your inventory',
                          ),
                          _buildInstructionItem(
                            '4',
                            'You\'ll receive a confirmation message with details',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.info,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
