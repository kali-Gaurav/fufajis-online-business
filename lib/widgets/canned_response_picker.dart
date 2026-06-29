import 'package:flutter/material.dart';
import '../models/canned_response_model.dart';
import '../services/canned_response_service.dart';
import '../utils/app_theme.dart';

/// Task #66 — Shared Canned Response Picker
///
/// Shows a bottom sheet with:
///   • Search bar
///   • Category filter chips
///   • Scrollable list of matching responses
///   • (Owner only) Add / delete controls when [allowManage] is true
///
/// Usage:
///   final text = await CannedResponsePicker.show(context);
///   if (text != null) controller.text = text;
class CannedResponsePicker {
  static Future<String?> show(
    BuildContext context, {
    bool allowManage = false,
    Color accentColor = AppTheme.primary,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CannedResponseSheet(
        allowManage: allowManage,
        accentColor: accentColor,
      ),
    );
  }
}

class _CannedResponseSheet extends StatefulWidget {
  final bool allowManage;
  final Color accentColor;

  const _CannedResponseSheet({
    required this.allowManage,
    required this.accentColor,
  });

  @override
  State<_CannedResponseSheet> createState() => _CannedResponseSheetState();
}

class _CannedResponseSheetState extends State<_CannedResponseSheet> {
  final CannedResponseService _service = CannedResponseService();
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedCategory; // null = all

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
    // Seed defaults if empty (idempotent — noop if already seeded)
    _service.seedDefaults();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CannedResponseModel> _filter(List<CannedResponseModel> all) {
    var list = all;
    if (_selectedCategory != null) {
      list = list.where((r) => r.category == _selectedCategory).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      list = list
          .where((r) =>
              r.title.toLowerCase().contains(q) ||
              r.text.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  Set<String> _categories(List<CannedResponseModel> all) =>
      all.map((r) => r.category).toSet();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Row(
              children: [
                Icon(Icons.flash_on_rounded,
                    color: widget.accentColor, size: 20),
                const SizedBox(width: 8),
                const Text('Quick Replies',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (widget.allowManage)
                  IconButton(
                    icon: Icon(Icons.add_circle_outline,
                        color: widget.accentColor),
                    tooltip: 'Add new response',
                    onPressed: () => _showAddDialog(),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search responses…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
            ),
          ),
          // Body: StreamBuilder
          Expanded(
            child: StreamBuilder<List<CannedResponseModel>>(
              stream: _service.watchAll(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }
                final all = snapshot.data!;
                final categories = _categories(all);
                final filtered = _filter(all);

                return Column(
                  children: [
                    // Category chips
                    if (categories.length > 1)
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _CategoryChip(
                              label: 'All',
                              selected: _selectedCategory == null,
                              color: widget.accentColor,
                              onTap: () => setState(
                                  () => _selectedCategory = null),
                            ),
                            ...categories.map((c) => _CategoryChip(
                                  label: c,
                                  selected: _selectedCategory == c,
                                  color: widget.accentColor,
                                  onTap: () => setState(
                                      () => _selectedCategory = c),
                                )),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    // List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                _query.isNotEmpty
                                    ? 'No responses match "$_query"'
                                    : 'No responses yet',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) => _ResponseTile(
                                response: filtered[i],
                                accentColor: widget.accentColor,
                                allowManage: widget.allowManage,
                                onSelect: (text) =>
                                    Navigator.pop(context, text),
                                onDelete: (id) => _service.delete(id),
                                onEdit: (r) => _showEditDialog(r),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: mq.padding.bottom),
        ],
      ),
    );
  }

  void _showAddDialog() {
    _showResponseDialog(title: 'Add Quick Reply', onSave: (t, tx, c) {
      _service.add(title: t, text: tx, category: c);
    });
  }

  void _showEditDialog(CannedResponseModel r) {
    _showResponseDialog(
      title: 'Edit Quick Reply',
      initialTitle: r.title,
      initialText: r.text,
      initialCategory: r.category,
      onSave: (t, tx, c) =>
          _service.update(r.id, title: t, text: tx, category: c),
    );
  }

  void _showResponseDialog({
    required String title,
    String initialTitle = '',
    String initialText = '',
    String initialCategory = 'General',
    required void Function(String title, String text, String category) onSave,
  }) {
    final titleCtrl = TextEditingController(text: initialTitle);
    final textCtrl = TextEditingController(text: initialText);
    final catCtrl = TextEditingController(text: initialCategory);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title (short label)',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: catCtrl,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
                hintText: 'e.g. Greeting, Order, Delivery',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: textCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Message text',
                prefixIcon: Icon(Icons.message_outlined),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.isNotEmpty && textCtrl.text.isNotEmpty) {
                onSave(
                  titleCtrl.text.trim(),
                  textCtrl.text.trim(),
                  catCtrl.text.trim().isEmpty ? 'General' : catCtrl.text.trim(),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ─── Response Tile ─────────────────────────────────────────────────────────────

class _ResponseTile extends StatelessWidget {
  final CannedResponseModel response;
  final Color accentColor;
  final bool allowManage;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;
  final ValueChanged<CannedResponseModel> onEdit;

  const _ResponseTile({
    required this.response,
    required this.accentColor,
    required this.allowManage,
    required this.onSelect,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onSelect(response.text),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            response.category,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            response.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      response.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (allowManage)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      color: Colors.grey,
                      constraints: const BoxConstraints(
                          minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                      onPressed: () => onEdit(response),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      color: AppTheme.error,
                      constraints: const BoxConstraints(
                          minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Response'),
                          content: Text(
                              'Delete "${response.title}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                onDelete(response.id);
                                Navigator.pop(context);
                              },
                              child: const Text('Delete',
                                  style: TextStyle(color: AppTheme.error)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              else
                const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Category Chip ─────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
