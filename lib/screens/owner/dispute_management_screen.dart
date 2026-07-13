import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../utils/app_theme.dart';
import '../../models/payment_dispute_model.dart';
import '../../widgets/owner/bi_widgets.dart';

/// Owner-facing Payment Dispute / Chargeback management (Task #50).
///
/// `payment_disputes` documents are created and updated exclusively by the
/// `razorpayWebhook` Cloud Function in response to `payment.dispute.*`
/// events. This screen lets owners/admins review open disputes, see the
/// gateway's response deadline, and submit evidence (uploaded to Storage)
/// via the `submitDisputeEvidence` callable — the only write path, keeping
/// the collection Cloud-Function-only per Firestore rules.
class DisputeManagementScreen extends StatefulWidget {
  const DisputeManagementScreen({super.key});

  @override
  State<DisputeManagementScreen> createState() => _DisputeManagementScreenState();
}

class _DisputeManagementScreenState extends State<DisputeManagementScreen> {
  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(title: const Text('Payment Disputes')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('payment_disputes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorBox(message: snap.error.toString());
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
          }
          final disputes = snap.data!.docs
              .map((d) => PaymentDispute.fromMap(d.data(), d.id))
              .toList();

          if (disputes.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 100),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.gavel_outlined, size: 56, color: AppTheme.grey400),
                      SizedBox(height: 12),
                      Text(
                        'No disputes or chargebacks yet',
                        style: TextStyle(color: AppTheme.grey600),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          final open = disputes.where((d) => d.needsAction).toList();
          final resolved = disputes.where((d) => !d.needsAction).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
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
                    label: 'Open / Needs Action',
                    value: '${open.length}',
                    icon: Icons.warning_amber_outlined,
                    color: AppTheme.warning,
                  ),
                  BiKpiCard(
                    label: 'Total Disputed',
                    value: kInr.format(disputes.fold<double>(0, (a, d) => a + d.amount)),
                    icon: Icons.gavel_outlined,
                    color: AppTheme.error,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (open.isNotEmpty) ...[
                const Text(
                  'Needs Action',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                ...open.map((d) => _DisputeCard(dispute: d, dateFmt: _dateFmt)),
                const SizedBox(height: 20),
              ],
              if (resolved.isNotEmpty) ...[
                const Text('Resolved', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                ...resolved.map((d) => _DisputeCard(dispute: d, dateFmt: _dateFmt)),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _DisputeCard extends StatefulWidget {
  final PaymentDispute dispute;
  final DateFormat dateFmt;
  const _DisputeCard({required this.dispute, required this.dateFmt});

  @override
  State<_DisputeCard> createState() => _DisputeCardState();
}

class _DisputeCardState extends State<_DisputeCard> {
  bool _expanded = false;
  bool _submitting = false;
  final List<String> _newEvidenceUrls = [];
  final _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.dispute.evidenceNotes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Color _statusColor(DisputeStatus s) {
    switch (s) {
      case DisputeStatus.open:
        return AppTheme.error;
      case DisputeStatus.underReview:
        return AppTheme.warning;
      case DisputeStatus.evidenceSubmitted:
        return AppTheme.info;
      case DisputeStatus.won:
        return AppTheme.success;
      case DisputeStatus.lost:
        return AppTheme.error;
      case DisputeStatus.closed:
        return AppTheme.grey500;
    }
  }

  Future<void> _pickAndUploadEvidence() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() => _submitting = true);
    try {
      final ref = FirebaseStorage.instance.ref().child(
        'disputes/${widget.dispute.id}/evidence_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      setState(() => _newEvidenceUrls.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitEvidence() async {
    setState(() => _submitting = true);
    try {
      final allUrls = [...widget.dispute.evidenceUrls, ..._newEvidenceUrls];
      final callable = FirebaseFunctions.instance.httpsCallable('submitDisputeEvidence');
      await callable.call({
        'disputeId': widget.dispute.id,
        'evidenceUrls': allUrls,
        'evidenceNotes': _notesController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Evidence submitted to gateway record')));
        setState(() {
          _newEvidenceUrls.clear();
          _expanded = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dispute;
    final daysLeft = d.daysRemaining;

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
                    d.orderNumber != null ? 'Order #${d.orderNumber}' : 'Payment ${d.paymentId}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(d.status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    d.status.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(d.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Disputed amount: ${kInr.format(d.amount)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (d.reasonDescription.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Reason: ${d.reasonDescription}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                ),
              ),
            if (d.respondBy != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  daysLeft != null
                      ? 'Respond by ${widget.dateFmt.format(d.respondBy!)} ($daysLeft day${daysLeft == 1 ? '' : 's'} left)'
                      : 'Gateway deadline: ${widget.dateFmt.format(d.respondBy!)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: (daysLeft != null && daysLeft <= 2) ? AppTheme.error : AppTheme.grey700,
                  ),
                ),
              ),
            if (d.evidenceUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${d.evidenceUrls.length} evidence file(s) submitted',
                  style: const TextStyle(fontSize: 12, color: AppTheme.success),
                ),
              ),
            if (d.needsAction) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Hide evidence form' : 'Submit evidence'),
              ),
              if (_expanded) ...[
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Evidence notes / explanation',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._newEvidenceUrls.map(
                      (u) => Chip(
                        label: const Text('Evidence file'),
                        avatar: const Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                        onDeleted: () => setState(() => _newEvidenceUrls.remove(u)),
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.upload_file, size: 16),
                      label: const Text('Upload file'),
                      onPressed: _submitting ? null : _pickAndUploadEvidence,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submitEvidence,
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit Evidence'),
                  ),
                ),
              ],
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
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          const Text(
            'Could not load disputes',
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
