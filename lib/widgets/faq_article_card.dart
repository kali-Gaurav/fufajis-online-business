import 'package:flutter/material.dart';
import '../models/faq_article_model.dart';
import '../services/faq_service.dart';
import '../utils/app_theme.dart';

/// Task #69 — Expandable FAQ card shown inline in the chat thread.
///
/// • Tapping the header toggles the answer panel.
/// • On first expand the view count is incremented in Firestore.
/// • [accentColor] lets both owner (blue) and employee (purple) screens
///   tint the card to match their colour scheme.
class FaqArticleCard extends StatefulWidget {
  final FaqArticleModel article;
  final Color accentColor;
  final bool initiallyExpanded;
  final VoidCallback? onDismiss;

  const FaqArticleCard({
    super.key,
    required this.article,
    this.accentColor = AppTheme.primary,
    this.initiallyExpanded = false,
    this.onDismiss,
  });

  @override
  State<FaqArticleCard> createState() => _FaqArticleCardState();
}

class _FaqArticleCardState extends State<FaqArticleCard> with SingleTickerProviderStateMixin {
  late bool _expanded;
  bool _viewTracked = false;
  late final AnimationController _anim;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    if (_expanded) _anim.value = 1.0;
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _anim.forward();
        if (!_viewTracked) {
          _viewTracked = true;
          FaqService().incrementViews(widget.article.id);
        }
      } else {
        _anim.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.help_outline_rounded, color: accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.article.category,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          ),
                        ),
                        Text(
                          widget.article.question,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expand / dismiss controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onDismiss != null)
                        GestureDetector(
                          onTap: widget.onDismiss,
                          child: const Icon(Icons.close, size: 14, color: AppTheme.grey400),
                        ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more, color: accent, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ── Answer ──────────────────────────────────────────────────────
          ClipRect(
            child: FadeTransition(
              opacity: _fade,
              child: SizeTransition(
                sizeFactor: _fade,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(36, 0, 12, 12),
                  child: Text(
                    widget.article.answer,
                    style: const TextStyle(fontSize: 13, color: AppTheme.grey700, height: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Task #69 — FAQ manager bottom sheet (owner / admin only).
///
/// Shows all articles (active + inactive) with add/edit/toggle/delete.
class FaqManagerSheet {
  static Future<void> show(BuildContext context, {Color accentColor = AppTheme.primary}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FaqManagerContent(accentColor: accentColor),
    );
  }
}

class _FaqManagerContent extends StatefulWidget {
  final Color accentColor;
  const _FaqManagerContent({required this.accentColor});

  @override
  State<_FaqManagerContent> createState() => _FaqManagerContentState();
}

class _FaqManagerContentState extends State<_FaqManagerContent> {
  final FaqService _service = FaqService();
  String? _filterCategory;

  @override
  void initState() {
    super.initState();
    _service.seedDefaults();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.88,
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
                Icon(Icons.menu_book_outlined, color: widget.accentColor),
                const SizedBox(width: 8),
                const Text(
                  'FAQ Knowledgebase',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: widget.accentColor),
                  tooltip: 'Add FAQ',
                  onPressed: () => _showEditDialog(),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Body
          Expanded(
            child: StreamBuilder<List<FaqArticleModel>>(
              stream: _service.watchAdmin(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }
                final all = snap.data!;
                // Category filter chips
                final categories = all.map((a) => a.category).toSet().toList()..sort();

                return Column(
                  children: [
                    // Category chips
                    if (categories.length > 1)
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          children: [
                            _FilterChip(
                              label: 'All',
                              selected: _filterCategory == null,
                              color: widget.accentColor,
                              onTap: () => setState(() => _filterCategory = null),
                            ),
                            ...categories.map(
                              (c) => _FilterChip(
                                label: c,
                                selected: _filterCategory == c,
                                color: widget.accentColor,
                                onTap: () => setState(() => _filterCategory = c),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: all
                            .where((a) => _filterCategory == null || a.category == _filterCategory)
                            .length,
                        itemBuilder: (ctx, i) {
                          final filtered = all
                              .where(
                                (a) => _filterCategory == null || a.category == _filterCategory,
                              )
                              .toList();
                          return _ArticleAdminTile(
                            article: filtered[i],
                            accentColor: widget.accentColor,
                            onEdit: () => _showEditDialog(article: filtered[i]),
                            onToggle: () =>
                                _service.update(filtered[i].id, isActive: !filtered[i].isActive),
                            onDelete: () => _confirmDelete(filtered[i]),
                          );
                        },
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

  void _showEditDialog({FaqArticleModel? article}) {
    final qCtrl = TextEditingController(text: article?.question ?? '');
    final aCtrl = TextEditingController(text: article?.answer ?? '');
    final catCtrl = TextEditingController(text: article?.category ?? 'General');
    final kwCtrl = TextEditingController(text: article?.keywords.join(', ') ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(article == null ? 'Add FAQ' : 'Edit FAQ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  prefixIcon: Icon(Icons.help_outline),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: catCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                  hintText: 'Orders, Delivery, Payments…',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: kwCtrl,
                decoration: const InputDecoration(
                  labelText: 'Keywords (comma-separated)',
                  prefixIcon: Icon(Icons.label_outline),
                  hintText: 'track, order, status',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: aCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Answer',
                  prefixIcon: Icon(Icons.article_outlined),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (qCtrl.text.trim().isEmpty || aCtrl.text.trim().isEmpty) return;
              final keywords = kwCtrl.text
                  .split(',')
                  .map((s) => s.trim().toLowerCase())
                  .where((s) => s.isNotEmpty)
                  .toList();
              if (article == null) {
                _service.add(
                  question: qCtrl.text,
                  answer: aCtrl.text,
                  category: catCtrl.text.trim().isEmpty ? 'General' : catCtrl.text.trim(),
                  keywords: keywords,
                );
              } else {
                _service.update(
                  article.id,
                  question: qCtrl.text,
                  answer: aCtrl.text,
                  category: catCtrl.text.trim().isEmpty ? 'General' : catCtrl.text.trim(),
                  keywords: keywords,
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(FaqArticleModel article) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete FAQ'),
        content: Text('Delete "${article.question}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              _service.delete(article.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

// ── Admin tile ─────────────────────────────────────────────────────────────

class _ArticleAdminTile extends StatelessWidget {
  final FaqArticleModel article;
  final Color accentColor;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ArticleAdminTile({
    required this.article,
    required this.accentColor,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: article.isActive ? Colors.grey.shade50 : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: article.isActive ? accentColor.withValues(alpha: 0.25) : Colors.grey.shade300,
        ),
      ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          article.category,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ),
                      if (!article.isActive) ...[
                        const SizedBox(width: 6),
                        const Text('(hidden)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                      const Spacer(),
                      Text(
                        '${article.views} views',
                        style: const TextStyle(fontSize: 10, color: AppTheme.grey400),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    article.question,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: article.isActive ? AppTheme.grey900 : AppTheme.grey400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    article.answer,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  color: Colors.grey,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: Icon(
                    article.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 16,
                  ),
                  color: AppTheme.infoGrey,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  onPressed: onToggle,
                  tooltip: article.isActive ? 'Hide' : 'Show',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  color: AppTheme.error,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter chip ────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
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
