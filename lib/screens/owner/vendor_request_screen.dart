import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_theme.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../models/purchase_order.dart';
import '../../services/order_service.dart';

class VendorRequestScreen extends StatefulWidget {
  const VendorRequestScreen({super.key});

  @override
  State<VendorRequestScreen> createState() => _VendorRequestScreenState();
}

class _VendorRequestScreenState extends State<VendorRequestScreen> {
  final List<PurchaseOrderItem> _orderItems = [];
  final TextEditingController _vendorNameController = TextEditingController();
  final TextEditingController _vendorPhoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final products = Provider.of<ProductProvider>(context).products;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Vendor Order'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          if (_orderItems.isNotEmpty)
            TextButton.icon(
              onPressed: _sendOrderRequest,
              icon: const Icon(Icons.send, color: AppTheme.primary),
              label: const Text('Send', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVendorInfoSection(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Items in Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => _showAddItemDialog(products),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_orderItems.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Text('No items added to this request.'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _orderItems.length,
                itemBuilder: (context, index) {
                  final item = _orderItems[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Qty: ${item.quantity} ${item.unit}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: AppTheme.error),
                        onPressed: () => setState(() => _orderItems.removeAt(index)),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vendor Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _vendorNameController,
          decoration: const InputDecoration(
            labelText: 'Vendor Name (e.g. Mahadev Distributors)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _vendorPhoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Vendor WhatsApp Number',
            border: OutlineInputBorder(),
            prefixText: '+91 ',
          ),
        ),
      ],
    );
  }

  void _showAddItemDialog(List<ProductModel> products) {
    ProductModel? selectedProduct;
    final qtyController = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Item to Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ProductModel>(
                hint: const Text('Select Product'),
                isExpanded: true,
                items: products.map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(p.name, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (val) => setDialogState(() => selectedProduct = val),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (selectedProduct != null && qtyController.text.isNotEmpty) {
                  setState(() {
                    _orderItems.add(PurchaseOrderItem(
                      productId: selectedProduct!.id,
                      productName: selectedProduct!.name,
                      quantity: int.parse(qtyController.text),
                      unit: selectedProduct!.unit,
                      estimatedCost: selectedProduct!.price * int.parse(qtyController.text),
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendOrderRequest() async {
    if (_vendorNameController.text.isEmpty || _vendorPhoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter vendor details')));
      return;
    }

    // Create message string
    String message = "Hello ${_vendorNameController.text}, this is an order from Fufaji Online:\n\n";
    for (var item in _orderItems) {
      message += "• ${item.productName}: ${item.quantity} ${item.unit}\n";
    }
    message += "\nPlease let us know when you can deliver.";

    final phone = _vendorPhoneController.text.replaceAll('+', '').replaceAll(' ', '');
    final url = Uri.parse('https://wa.me/91$phone?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      
      // Also log to Firestore
      final order = PurchaseOrder(
        id: 'po_${DateTime.now().millisecondsSinceEpoch}',
        shopId: 'fufaji_central',
        distributorName: _vendorNameController.text,
        items: _orderItems,
        totalAmount: _orderItems.fold(0, (sum, item) => sum + item.estimatedCost),
        createdAt: DateTime.now(),
        status: 'sent',
      );

      await OrderService().updateOrder(order.id, order.toMap()); // Using existing updateOrder but for PO collection in future
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order request sent and logged.')));
        Navigator.pop(context);
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch WhatsApp')));
    }
  }
}
