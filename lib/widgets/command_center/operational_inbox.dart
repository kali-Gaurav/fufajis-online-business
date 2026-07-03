import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

enum InboxCategory { tasks, approvals, alerts, messages, system_events }

class InboxItem {
  final String id;
  final InboxCategory category;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final bool isRead;

  InboxItem({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.isRead = false,
  });
}

class OperationalInbox extends StatefulWidget {
  final List<InboxItem> items;
  final Function(InboxItem) onItemTap;

  const OperationalInbox({super.key, required this.items, required this.onItemTap});

  @override
  State<OperationalInbox> createState() => _OperationalInboxState();
}

class _OperationalInboxState extends State<OperationalInbox> {
  InboxCategory _selectedCategory = InboxCategory.tasks;

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.items.where((i) => i.category == _selectedCategory).toList();

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: InboxCategory.values.map((cat) {
              final isSelected = cat == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(_formatCategoryName(cat.name)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = cat);
                  },
                  selectedColor: AppTheme.info,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.info : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        if (filteredItems.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Text('Inbox zero.', style: TextStyle(color: Colors.grey)),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredItems.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              return ListTile(
                leading: _getCategoryIcon(item.category),
                title: Text(
                  item.title,
                  style: TextStyle(fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold),
                ),
                subtitle: Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: !item.isRead
                    ? const CircleAvatar(radius: 4, backgroundColor: AppTheme.info)
                    : null,
                onTap: () => widget.onItemTap(item),
              );
            },
          ),
      ],
    );
  }

  String _formatCategoryName(String name) {
    return name[0].toUpperCase() + name.substring(1).replaceAll('_', ' ');
  }

  Widget _getCategoryIcon(InboxCategory cat) {
    switch (cat) {
      case InboxCategory.tasks:
        return const Icon(Icons.check_box, color: AppTheme.info);
      case InboxCategory.approvals:
        return const Icon(Icons.fact_check, color: AppTheme.warning);
      case InboxCategory.alerts:
        return const Icon(Icons.warning, color: AppTheme.error);
      case InboxCategory.messages:
        return const Icon(Icons.message, color: AppTheme.success);
      case InboxCategory.system_events:
        return const Icon(Icons.info, color: Colors.grey);
    }
  }
}
