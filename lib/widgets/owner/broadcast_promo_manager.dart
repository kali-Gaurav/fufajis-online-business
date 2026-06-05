import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class BroadcastPromoManager extends StatefulWidget {
  const BroadcastPromoManager({super.key});

  @override
  State<BroadcastPromoManager> createState() => _BroadcastPromoManagerState();
}

class _BroadcastPromoManagerState extends State<BroadcastPromoManager> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _msgController = TextEditingController();
  String _selectedVillage = 'All';

  final List<String> _villages = ['All', 'Bassi', 'Shahpura', 'Bagru', 'Achrol'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Broadcast Promo (Area-Specific)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedVillage,
            decoration: const InputDecoration(labelText: 'Target Village', border: OutlineInputBorder()),
            items: _villages.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => _selectedVillage = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Offer Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _msgController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Message (WhatsApp/App)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('📢 Promo sent to all users in $_selectedVillage'), backgroundColor: AppTheme.success),
                );
              },
              icon: const Icon(Icons.send),
              label: const Text('BROADCAST TO AREA'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
