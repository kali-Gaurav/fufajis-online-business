import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/fulfillment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/fulfillment_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/packing_widgets.dart';

class QualityCheckScreen extends StatefulWidget {
  final String? taskId;

  const QualityCheckScreen({super.key, this.taskId});

  @override
  State<QualityCheckScreen> createState() => _QualityCheckScreenState();
}

class _QualityCheckScreenState extends State<QualityCheckScreen> {
  FulfillmentTask? _currentTask;
  final List<bool> _verifiedItems = [];
  int _qualityScore = 100;
  final _rejectionReasonController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadTask() async {
    setState(() => _isLoading = true);

    try {
      final fulfillment = context.read<FulfillmentProvider>();

      if (widget.taskId != null) {
        await fulfillment.loadTask(widget.taskId!);
        _currentTask = fulfillment.currentTask;
      } else if (fulfillment.assignedOrders.isNotEmpty) {
        // Load the first "ready" task
        final readyTasks = fulfillment.assignedOrders
            .where((t) => t.status == FulfillmentStatus.ready)
            .toList();

        if (readyTasks.isNotEmpty) {
          await fulfillment.loadTask(readyTasks.first.id);
          _currentTask = fulfillment.currentTask;
        }
      }

      // Initialize verified items list
      if (_currentTask != null) {
        _verifiedItems.addAll(List.generate(
          _currentTask!.items.length,
          (i) => _currentTask!.items[i].verified,
        ));
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading task: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _approveQuality() async {
    if (_currentTask == null) return;

    try {
      setState(() => _isLoading = true);

      final auth = context.read<AuthProvider>();
      final fulfillment = context.read<FulfillmentProvider>();

      final approvedBy = auth.currentUser?.uid ?? 'unknown';

      await fulfillment.approveQuality(
        _currentTask!.id,
        _qualityScore.toDouble(),
        approvedBy,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order approved successfully'),
            backgroundColor: AppTheme.success,
          ),
        );

        // Wait and navigate back
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectQuality() async {
    if (_currentTask == null) return;

    final reason = _rejectionReasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide rejection reason'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Rejection', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to reject this order?\n\nReason: $reason'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                setState(() => _isLoading = true);

                final auth = context.read<AuthProvider>();
                final fulfillment = context.read<FulfillmentProvider>();

                final rejectedBy = auth.currentUser?.uid ?? 'unknown';

                await fulfillment.rejectQuality(
                  _currentTask!.id,
                  reason,
                  rejectedBy,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order rejected. Sent back for repacking'),
                      backgroundColor: AppTheme.warning,
                    ),
                  );

                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted) Navigator.pop(context);
                  });
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              } finally {
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading && _currentTask == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quality Check')),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_currentTask == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quality Check')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('No orders ready for QC',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quality Check', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order header
            OrderHeaderCard(
              orderId: _currentTask!.orderId,
              customerName: _currentTask!.orderId, // Use order ID as fallback
              createdAt: _currentTask!.createdAt,
            ),

            // Quality score slider
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: isDark ? Colors.grey[800] : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quality Score',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _qualityScore.toDouble(),
                              min: 0,
                              max: 100,
                              divisions: 10,
                              onChanged: (value) {
                                setState(() => _qualityScore = value.toInt());
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getScoreColor(_qualityScore),
                            ),
                            child: Center(
                              child: Text(
                                '$_qualityScore%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Items verification
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Verify Items',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),

            ...List.generate(
              _currentTask!.items.length,
              (index) {
                final item = _currentTask!.items[index];
                return QualityCheckItemCard(
                  item: item,
                  isChecked: _verifiedItems[index],
                  onVerify: () {
                    setState(() => _verifiedItems[index] = true);
                  },
                );
              },
            ),

            // Rejection reason field
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rejection Reason (if rejecting)',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _rejectionReasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'E.g., Damaged items, Missing items, Incorrect quantity',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                spacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _approveQuality,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Approve Order'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _rejectQuality,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Reject Order'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: AppTheme.error),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return AppTheme.success;
    if (score >= 70) return AppTheme.info;
    if (score >= 50) return AppTheme.warning;
    return AppTheme.error;
  }
}
