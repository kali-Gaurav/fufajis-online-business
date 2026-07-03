import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/audit_service.dart';
import '../../services/cod_limit_service.dart';
import '../../widgets/owner/bi_widgets.dart';

/// Owner-facing COD Limit Management screen (Task #51).
///
/// Two sections:
///  1. Search any user (customer or rider/DeliveryAgent) and edit their
///     per-customer `codLimit` and/or per-rider `maxCashInHand`. Writes go
///     directly to `users/{userId}` (allowed by Firestore rules for
///     isGlobalAdmin) and are logged via [AuditService] /
///     [AuditAction.codLimitChanged].
///  2. Review `cod_limit_alerts` raised by the `enforceCodOrderLimit` Cloud
///     Function when a customer's COD order pushes them over their limit —
///     mark them resolved/dismissed.
class CodLimitManagementScreen extends StatefulWidget {
  const CodLimitManagementScreen({super.key});

  @override
  State<CodLimitManagementScreen> createState() => _CodLimitManagementScreenState();
}

class _CodLimitManagementScreenState extends State<CodLimitManagementScreen> {
  final _dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
  final _searchController = TextEditingController();
  final _codLimitService = CodLimitService();

  bool _searching = false;
  String? _searchError;
  List<UserModel> _results = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final term = _searchController.text.trim();
    if (term.isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
      _results = [];
    });
    try {
      final results = <UserModel>[];
      final seen = <String>{};

      // Try phone number match (exact).
      final byPhone = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: term)
          .limit(10)
          .get();
      for (final d in byPhone.docs) {
        if (seen.add(d.id)) results.add(UserModel.fromMap({...d.data(), 'id': d.id}));
      }

      // Try email match (exact, lowercase).
      final byEmail = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: term.toLowerCase())
          .limit(10)
          .get();
      for (final d in byEmail.docs) {
        if (seen.add(d.id)) results.add(UserModel.fromMap({...d.data(), 'id': d.id}));
      }

      // Try name prefix match.
      final byName = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('name')
          .startAt([term])
          .endAt(['$term'])
          .limit(10)
          .get();
      for (final d in byName.docs) {
        if (seen.add(d.id)) results.add(UserModel.fromMap({...d.data(), 'id': d.id}));
      }

      setState(() => _results = results);
    } catch (e) {
      setState(() => _searchError = e.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(title: const Text('COD Limit Management')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BiSectionCard(
            title: 'Find a user to set COD limits',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Search by phone number, email, or name. Set the per-customer '
                  'COD order limit (codLimit) or the per-rider COD cash-in-hand '
                  'limit (maxCashInHand).',
                  style: TextStyle(fontSize: 12, color: AppTheme.grey600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Phone, email, or name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _searching ? null : _search,
                      child: _searching
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Search'),
                    ),
                  ],
                ),
                if (_searchError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Search failed: $_searchError',
                    style: const TextStyle(fontSize: 12, color: AppTheme.error),
                  ),
                ],
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ..._results.map(
                    (u) => _UserLimitCard(
                      user: u,
                      codLimitService: _codLimitService,
                      onUpdated: _search,
                    ),
                  ),
                ] else if (!_searching && _searchError == null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'No results yet — search for a user above.',
                    style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          BiSectionCard(
            title: 'COD Limit Alerts',
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('cod_limit_alerts')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _ErrorBox(message: snap.error.toString());
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent)),
                  );
                }
                final alerts = snap.data!.docs;
                if (alerts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: AppTheme.grey400),
                          SizedBox(height: 8),
                          Text('No COD limit alerts', style: TextStyle(color: AppTheme.grey600)),
                        ],
                      ),
                    ),
                  );
                }
                final open = alerts.where((d) => d.data()['status'] == 'open').toList();
                final closed = alerts.where((d) => d.data()['status'] != 'open').toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.6,
                      children: [
                        BiKpiCard(
                          label: 'Open Alerts',
                          value: '${open.length}',
                          icon: Icons.warning_amber_outlined,
                          color: AppTheme.warning,
                        ),
                        BiKpiCard(
                          label: 'Resolved / Dismissed',
                          value: '${closed.length}',
                          icon: Icons.check_circle_outline,
                          color: AppTheme.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (open.isNotEmpty) ...[
                      const Text(
                        'Needs Review',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      ...open.map((d) => _CodAlertCard(doc: d, dateFmt: _dateFmt)),
                      const SizedBox(height: 16),
                    ],
                    if (closed.isNotEmpty) ...[
                      const Text(
                        'Resolved',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      ...closed.map((d) => _CodAlertCard(doc: d, dateFmt: _dateFmt)),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Card showing a user's current codLimit / maxCashInHand with edit actions.
class _UserLimitCard extends StatefulWidget {
  final UserModel user;
  final CodLimitService codLimitService;
  final VoidCallback onUpdated;

  const _UserLimitCard({
    required this.user,
    required this.codLimitService,
    required this.onUpdated,
  });

  @override
  State<_UserLimitCard> createState() => _UserLimitCardState();
}

class _UserLimitCardState extends State<_UserLimitCard> {
  bool _loadingUsage = true;
  double? _customerExposure;
  double? _riderCashInHand;
  bool _saving = false;

  bool get _isRiderRole {
    final r = widget.user.role.toString().toLowerCase();
    return r.contains('delivery') || r.contains('rider');
  }

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    try {
      final exposure = await widget.codLimitService.getCustomerCodExposure(widget.user.id);
      double? cashInHand;
      if (_isRiderRole) {
        cashInHand = await widget.codLimitService.getRiderCashInHand(widget.user.id);
      }
      if (mounted) {
        setState(() {
          _customerExposure = exposure;
          _riderCashInHand = cashInHand;
          _loadingUsage = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUsage = false);
    }
  }

  Future<void> _editLimit({required bool isRiderLimit}) async {
    final current = isRiderLimit ? widget.user.maxCashInHand : widget.user.codLimit;
    final controller = TextEditingController(text: current.toStringAsFixed(0));
    final newValue = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isRiderLimit
              ? 'Set max cash-in-hand for ${widget.user.name ?? widget.user.id}'
              : 'Set COD order limit for ${widget.user.name ?? widget.user.id}',
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            prefixText: '₹ ',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v != null && v >= 0) Navigator.pop(context, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newValue == null || newValue == current) return;

    setState(() => _saving = true);
    try {
      final field = isRiderLimit ? 'maxCashInHand' : 'codLimit';
      await FirebaseFirestore.instance.collection('users').doc(widget.user.id).set({
        field: newValue,
      }, SetOptions(merge: true));

      final currentUser = FirebaseAuth.instance.currentUser;
      await AuditService().logAction(
        userId: currentUser?.uid ?? 'system',
        userName: currentUser?.displayName ?? currentUser?.email ?? 'Owner',
        action: AuditAction.codLimitChanged,
        description: isRiderLimit
            ? 'Updated max cash-in-hand for ${widget.user.name ?? widget.user.id} '
                  'from ₹${current.toStringAsFixed(0)} to ₹${newValue.toStringAsFixed(0)}'
            : 'Updated COD order limit for ${widget.user.name ?? widget.user.id} '
                  'from ₹${current.toStringAsFixed(0)} to ₹${newValue.toStringAsFixed(0)}',
        targetId: widget.user.id,
        targetType: 'user',
        oldValue: {field: current},
        newValue: {field: newValue},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Limit updated')));
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final exposure = _customerExposure ?? 0;
    final exposurePct = u.codLimit > 0 ? (exposure / u.codLimit).clamp(0, 1.5) : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.name ?? '(no name)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        [
                          if (u.phoneNumber.isNotEmpty) u.phoneNumber,
                          if (u.email != null) u.email!,
                        ].join(' • '),
                        style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    u.role.toString().replaceFirst('UserRole.', ''),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Customer COD order limit row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'COD order limit',
                        style: TextStyle(fontSize: 12, color: AppTheme.grey600),
                      ),
                      Text(
                        kInr.format(u.codLimit),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (!_loadingUsage)
                        Text(
                          'Outstanding COD: ${kInr.format(exposure)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: exposurePct >= 1
                                ? AppTheme.error
                                : exposurePct >= 0.8
                                ? AppTheme.warning
                                : AppTheme.grey600,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : () => _editLimit(isRiderLimit: false),
                  child: const Text('Edit'),
                ),
              ],
            ),
            if (_isRiderRole) ...[
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Max COD cash-in-hand',
                          style: TextStyle(fontSize: 12, color: AppTheme.grey600),
                        ),
                        Text(
                          kInr.format(u.maxCashInHand),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (!_loadingUsage && _riderCashInHand != null)
                          Text(
                            'Currently holding: ${kInr.format(_riderCashInHand!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: _riderCashInHand! > u.maxCashInHand
                                  ? AppTheme.error
                                  : AppTheme.grey600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : () => _editLimit(isRiderLimit: true),
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card for reviewing a `cod_limit_alerts` document.
class _CodAlertCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final DateFormat dateFmt;
  const _CodAlertCard({required this.doc, required this.dateFmt});

  @override
  State<_CodAlertCard> createState() => _CodAlertCardState();
}

class _CodAlertCardState extends State<_CodAlertCard> {
  bool _updating = false;

  Future<void> _setStatus(String status) async {
    setState(() => _updating = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await widget.doc.reference.set({
        'status': status,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': currentUser?.uid,
      }, SetOptions(merge: true));

      await AuditService().logAction(
        userId: currentUser?.uid ?? 'system',
        userName: currentUser?.displayName ?? currentUser?.email ?? 'Owner',
        action: AuditAction.codLimitChanged,
        description: 'Marked COD limit alert ${widget.doc.id} as $status',
        targetId: widget.doc.id,
        targetType: 'cod_limit_alert',
        metadata: widget.doc.data(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final status = (data['status'] as String?) ?? 'open';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final isOpen = status == 'open';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #${data['orderNumber'] ?? data['orderId'] ?? '-'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isOpen ? AppTheme.warning : AppTheme.success).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOpen ? AppTheme.warning : AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Customer: ${data['customerName'] ?? data['customerId'] ?? '-'}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              'COD limit: ${kInr.format((data['codLimit'] as num? ?? 0).toDouble())}  •  '
              'Prior exposure: ${kInr.format((data['priorExposure'] as num? ?? 0).toDouble())}  •  '
              'Order amount: ${kInr.format((data['orderAmount'] as num? ?? 0).toDouble())}',
              style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
            ),
            const SizedBox(height: 2),
            Text(
              'New exposure would be: ${kInr.format((data['newExposure'] as num? ?? 0).toDouble())}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.error,
              ),
            ),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  widget.dateFmt.format(createdAt),
                  style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                ),
              ),
            if (isOpen) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: _updating ? null : () => _setStatus('dismissed'),
                    child: const Text('Dismiss'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _updating ? null : () => _setStatus('resolved'),
                    child: _updating
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Mark Resolved'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          const Text(
            'Could not load COD limit alerts',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey800),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
          ),
        ],
      ),
    );
  }
}
