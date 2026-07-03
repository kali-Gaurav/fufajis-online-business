import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../models/automation_rule_model.dart';
import '../../services/automation_rule_service.dart';
import '../../utils/app_theme.dart';

/// Owner-facing UI for the generic automation/workflow rules engine.
/// Lets the owner build "if this happens, then do that" rules without
/// code changes. Evaluation happens server-side in
/// functions/automation_rules_engine.js.
class AutomationRulesScreen extends StatefulWidget {
  const AutomationRulesScreen({super.key});

  @override
  State<AutomationRulesScreen> createState() => _AutomationRulesScreenState();
}

class _AutomationRulesScreenState extends State<AutomationRulesScreen> {
  final _service = AutomationRuleService();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final adminId = auth.currentUser?.id ?? '';
    final adminName = auth.currentUser?.name ?? 'Owner';

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Automation Rules', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, null, adminId, adminName),
        icon: const Icon(Icons.add),
        label: const Text('New Rule'),
      ),
      body: StreamBuilder<List<AutomationRuleModel>>(
        stream: _service.watchRules(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading rules: ${snapshot.error}',
                  style: const TextStyle(color: AppTheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final rules = snapshot.data ?? [];
          if (rules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt_outlined, size: 64, color: AppTheme.grey400),
                  const SizedBox(height: 16),
                  Text('No automation rules yet', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Build "if this happens, then do that" rules — e.g. notify customers when '
                      'an order is delayed, or alert the owner when stock runs low.',
                      style: TextStyle(color: AppTheme.grey600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _openEditor(context, null, adminId, adminName),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Rule'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return _RuleCard(
                rule: rule,
                onToggle: (value) => _service.setEnabled(rule.id, value, adminId, adminName),
                onEdit: () => _openEditor(context, rule, adminId, adminName),
                onDelete: () => _confirmDelete(context, rule, adminId, adminName),
              );
            },
          );
        },
      ),
    );
  }

  void _openEditor(
    BuildContext context,
    AutomationRuleModel? rule,
    String adminId,
    String adminName,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _RuleEditorScreen(rule: rule, adminId: adminId, adminName: adminName),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    AutomationRuleModel rule,
    String adminId,
    String adminName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete rule?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('This will permanently delete "${rule.name}". This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _service.deleteRule(rule.id, adminId, adminName);
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final AutomationRuleModel rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleCard({
    required this.rule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.grey200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rule.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Switch(
                  value: rule.enabled,
                  onChanged: onToggle,
                  activeThumbColor: AppTheme.primary,
                ),
              ],
            ),
            if (rule.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(rule.description, style: const TextStyle(color: AppTheme.grey600, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(Icons.flash_on, 'Trigger: ${rule.triggerType.label}', AppTheme.primary),
                ...rule.actions.map((a) => _chip(Icons.bolt, a.type.label, AppTheme.info)),
                if (rule.conditions.isNotEmpty)
                  _chip(
                    Icons.filter_alt,
                    '${rule.conditions.length} condition${rule.conditions.length == 1 ? '' : 's'}',
                    AppTheme.grey600,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.history, size: 14, color: AppTheme.grey500),
                const SizedBox(width: 4),
                Text(
                  'Triggered ${rule.triggeredCount} time${rule.triggeredCount == 1 ? '' : 's'}'
                  '${rule.lastTriggeredAt != null ? ' · last ${DateFormat('dd MMM, hh:mm a').format(rule.lastTriggeredAt!)}' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Full create/edit form for a single automation rule.
class _RuleEditorScreen extends StatefulWidget {
  final AutomationRuleModel? rule;
  final String adminId;
  final String adminName;

  const _RuleEditorScreen({required this.rule, required this.adminId, required this.adminName});

  @override
  State<_RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends State<_RuleEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late AutomationTriggerType _triggerType;
  late Map<String, dynamic> _triggerConfig;
  late List<AutomationCondition> _conditions;
  late List<AutomationAction> _actions;
  bool _enabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _nameController = TextEditingController(text: r?.name ?? '');
    _descController = TextEditingController(text: r?.description ?? '');
    _triggerType = r?.triggerType ?? AutomationTriggerType.orderStatusChanged;
    _triggerConfig = Map<String, dynamic>.from(r?.triggerConfig ?? {});
    _conditions = List.of(r?.conditions ?? []);
    _actions = List.of(r?.actions ?? []);
    _enabled = r?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.rule != null;

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a rule name')));
      return;
    }
    if (_actions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add at least one action')));
      return;
    }

    setState(() => _saving = true);
    try {
      final rule = AutomationRuleModel(
        id: widget.rule?.id ?? '',
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        enabled: _enabled,
        triggerType: _triggerType,
        triggerConfig: _triggerConfig,
        conditions: _conditions,
        actions: _actions,
        triggeredCount: widget.rule?.triggeredCount ?? 0,
        lastTriggeredAt: widget.rule?.lastTriggeredAt,
        createdAt: widget.rule?.createdAt,
      );

      if (_isEditing) {
        await AutomationRuleService().updateRule(rule, widget.adminId, widget.adminName);
      } else {
        await AutomationRuleService().createRule(rule, widget.adminId, widget.adminName);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Rule' : 'New Automation Rule'),
        elevation: 0,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Basics', [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Rule name',
                hintText: 'e.g. Notify on cancelled orders',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enabled', style: TextStyle(fontWeight: FontWeight.w700)),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              activeThumbColor: AppTheme.primary,
            ),
          ]),
          _section('Trigger — when should this run?', [_buildTriggerSection()]),
          _section('Conditions — only run if (optional)', [
            ..._conditions.asMap().entries.map(
              (e) => _ConditionRow(
                condition: e.value,
                onChanged: (c) => setState(() => _conditions[e.key] = c),
                onDelete: () => setState(() => _conditions.removeAt(e.key)),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(
                () => _conditions.add(const AutomationCondition(field: '', operator: '==')),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add condition'),
            ),
          ]),
          _section('Actions — then do this', [
            ..._actions.asMap().entries.map(
              (e) => _ActionRow(
                action: e.value,
                onChanged: (a) => setState(() => _actions[e.key] = a),
                onDelete: () => setState(() => _actions.removeAt(e.key)),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(
                () => _actions.add(
                  const AutomationAction(type: AutomationActionType.sendPush, config: {}),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add action'),
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTriggerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<AutomationTriggerType>(
          initialValue: _triggerType,
          decoration: const InputDecoration(labelText: 'Trigger event'),
          items: AutomationTriggerType.values
              .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _triggerType = v;
              _triggerConfig = {};
            });
          },
        ),
        const SizedBox(height: 12),
        ..._buildTriggerConfigFields(),
      ],
    );
  }

  List<Widget> _buildTriggerConfigFields() {
    switch (_triggerType) {
      case AutomationTriggerType.orderStatusChanged:
        return [
          DropdownButtonFormField<String>(
            initialValue: (_triggerConfig['status'] as String?) ?? '*',
            decoration: const InputDecoration(labelText: 'Order status (or "Any")'),
            items: const [
              DropdownMenuItem(value: '*', child: Text('Any status')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
              DropdownMenuItem(value: 'preparing', child: Text('Preparing')),
              DropdownMenuItem(value: 'outForDelivery', child: Text('Out for delivery')),
              DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
              DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
            onChanged: (v) => setState(() => _triggerConfig = {..._triggerConfig, 'status': v}),
          ),
        ];
      case AutomationTriggerType.lowStock:
        return [
          DropdownButtonFormField<String>(
            initialValue: (_triggerConfig['severity'] as String?) ?? '*',
            decoration: const InputDecoration(labelText: 'Severity (or "Any")'),
            items: const [
              DropdownMenuItem(value: '*', child: Text('Any severity')),
              DropdownMenuItem(value: 'medium', child: Text('Medium (low stock)')),
              DropdownMenuItem(value: 'critical', child: Text('Critical (≤2 left)')),
            ],
            onChanged: (v) => setState(() => _triggerConfig = {..._triggerConfig, 'severity': v}),
          ),
        ];
      case AutomationTriggerType.cartAbandoned:
        return [
          TextFormField(
            initialValue: (_triggerConfig['hours'] ?? 3).toString(),
            decoration: const InputDecoration(
              labelText: 'Hours of inactivity before considered abandoned',
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => _triggerConfig = {..._triggerConfig, 'hours': int.tryParse(v) ?? 3},
          ),
          const SizedBox(height: 4),
          const Text(
            'Checked hourly by a scheduled function.',
            style: TextStyle(fontSize: 12, color: AppTheme.grey500),
          ),
        ];
      case AutomationTriggerType.customerInactive:
        return [
          TextFormField(
            initialValue: (_triggerConfig['days'] ?? 14).toString(),
            decoration: const InputDecoration(
              labelText: 'Days since last order before considered inactive',
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => _triggerConfig = {..._triggerConfig, 'days': int.tryParse(v) ?? 14},
          ),
          const SizedBox(height: 4),
          const Text(
            'Checked hourly by a scheduled function.',
            style: TextStyle(fontSize: 12, color: AppTheme.grey500),
          ),
        ];
    }
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.grey200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.grey800,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

const _conditionFieldHints = [
  'orderId',
  'customerId',
  'orderNumber',
  'status',
  'previousStatus',
  'totalAmount',
  'shopId',
  'productId',
  'productName',
  'stockQuantity',
  'severity',
];

const _operatorOptions = ['==', '!=', '>', '>=', '<', '<=', 'contains', 'exists', 'not_exists'];

class _ConditionRow extends StatelessWidget {
  final AutomationCondition condition;
  final ValueChanged<AutomationCondition> onChanged;
  final VoidCallback onDelete;

  const _ConditionRow({required this.condition, required this.onChanged, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final needsValue = condition.operator != 'exists' && condition.operator != 'not_exists';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Autocomplete<String>(
              initialValue: TextEditingValue(text: condition.field),
              optionsBuilder: (v) =>
                  _conditionFieldHints.where((h) => h.toLowerCase().contains(v.text.toLowerCase())),
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                controller.text = condition.field;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: 'Field', isDense: true),
                  onChanged: (v) => onChanged(condition.copyWith(field: v)),
                );
              },
              onSelected: (v) => onChanged(condition.copyWith(field: v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: condition.operator,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true, labelText: 'Op'),
              items: _operatorOptions
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(o, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                onChanged(condition.copyWith(operator: v));
              },
            ),
          ),
          if (needsValue) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: TextEditingController(text: condition.value)
                  ..selection = TextSelection.collapsed(offset: condition.value.length),
                decoration: const InputDecoration(labelText: 'Value', isDense: true),
                onChanged: (v) => onChanged(condition.copyWith(value: v)),
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppTheme.grey500),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatefulWidget {
  final AutomationAction action;
  final ValueChanged<AutomationAction> onChanged;
  final VoidCallback onDelete;

  const _ActionRow({required this.action, required this.onChanged, required this.onDelete});

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  /// Returns the relevant config keys (with hints) for each action type.
  List<_ConfigField> _configFields(AutomationActionType type) {
    switch (type) {
      case AutomationActionType.sendPush:
        return [
          const _ConfigField('title', 'Title', '{{orderNumber}} update'),
          const _ConfigField('body', 'Message', 'Your order is now {{status}}'),
          const _ConfigField(
            'deepLink',
            'Deep link (optional)',
            '/customer/order-detail/{{orderId}}',
          ),
        ];
      case AutomationActionType.sendEmail:
        return [
          const _ConfigField('subject', 'Subject', 'Update on order {{orderNumber}}'),
          const _ConfigField(
            'html',
            'Email body (HTML)',
            '<p>Hi! Your order {{orderNumber}} is now {{status}}.</p>',
          ),
        ];
      case AutomationActionType.applyCoupon:
        return [
          const _ConfigField('discountPercent', 'Discount % (or use flat)', '10'),
          const _ConfigField('discountFlat', 'Flat discount ₹ (optional)', ''),
          const _ConfigField('expiresInDays', 'Expires in (days)', '7'),
        ];
      case AutomationActionType.addUserTag:
        return [const _ConfigField('tag', 'Tag to add', 'vip')];
      case AutomationActionType.notifyOwner:
        return [
          const _ConfigField('title', 'Alert title', 'Action needed'),
          const _ConfigField('message', 'Alert message', 'Cart abandoned: {{customerId}}'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = _configFields(widget.action.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.grey50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<AutomationActionType>(
                  initialValue: widget.action.type,
                  decoration: const InputDecoration(labelText: 'Action', isDense: true),
                  items: AutomationActionType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    widget.onChanged(widget.action.copyWith(type: v, config: {}));
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppTheme.grey500),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...fields.map((f) {
            final value = widget.action.config[f.key]?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: TextEditingController(text: value)
                  ..selection = TextSelection.collapsed(offset: value.length),
                decoration: InputDecoration(labelText: f.label, hintText: f.hint, isDense: true),
                maxLines: f.key == 'html' || f.key == 'body' || f.key == 'message' ? 3 : 1,
                onChanged: (v) {
                  final newConfig = Map<String, dynamic>.from(widget.action.config);
                  if (v.isEmpty) {
                    newConfig.remove(f.key);
                  } else {
                    newConfig[f.key] = v;
                  }
                  widget.onChanged(widget.action.copyWith(config: newConfig));
                },
              ),
            );
          }),
          const SizedBox(height: 4),
          const Text(
            'Use {{field}} placeholders (e.g. {{orderNumber}}, {{status}}) to insert event data.',
            style: TextStyle(fontSize: 11, color: AppTheme.grey500),
          ),
        ],
      ),
    );
  }
}

class _ConfigField {
  final String key;
  final String label;
  final String hint;
  const _ConfigField(this.key, this.label, this.hint);
}
