import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/fulfillment_provider.dart';
import '../../models/fulfillment_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/packing_widgets.dart';

class PackingScreen extends StatefulWidget {
  final String taskId;
  final String? orderId;
  final String? customerName;
  final String? customerPhone;
  final String? address;

  const PackingScreen({
    super.key,
    required this.taskId,
    this.orderId,
    this.customerName,
    this.customerPhone,
    this.address,
  });

  @override
  State<PackingScreen> createState() => _PackingScreenState();
}

class _PackingScreenState extends State<PackingScreen> {
  bool _isPacking = false;
  final _notesController = TextEditingController();
  int _currentItemIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadTask() async {
    try {
      final fulfillment = context.read<FulfillmentProvider>();
      await fulfillment.loadTask(widget.taskId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading task: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _startPacking() async {
    try {
      final fulfillment = context.read<FulfillmentProvider>();
      await fulfillment.startPacking(widget.taskId);
      setState(() => _isPacking = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Packing started'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _markItemPacked(FulfillmentItem item) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _QuantityInputSheet(
        item: item,
        onSave: (quantity) async {
          try {
            final fulfillment = context.read<FulfillmentProvider>();
            await fulfillment.markItemPacked(widget.taskId, item.productId, quantity);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.productName} marked as packed'),
                  backgroundColor: AppTheme.success,
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
            }
          }
        },
      ),
    );
  }

  Future<void> _completePacking() async {
    final fulfillment = context.read<FulfillmentProvider>();
    final currentTask = fulfillment.currentTask;

    if (currentTask == null || !currentTask.allItemsPacked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pack all items before completing'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Packing', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add any special notes (optional):'),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'E.g., Fragile items, Handle with care',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await fulfillment.completePacking(
                  widget.taskId,
                  notes: _notesController.text.isNotEmpty ? _notesController.text : null,
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Packing completed successfully'),
                      backgroundColor: AppTheme.success,
                    ),
                  );

                  // Navigate back after a brief delay
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
              }
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pack Order', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: Consumer<FulfillmentProvider>(
        builder: (context, fulfillment, child) {
          final task = fulfillment.currentTask;

          if (fulfillment.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          if (task == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
                  const SizedBox(height: 16),
                  Text('Task not found', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order header
                OrderHeaderCard(
                  orderId: widget.orderId ?? task.orderId,
                  customerName: widget.customerName ?? task.orderId,
                  customerPhone: widget.customerPhone,
                  address: widget.address,
                  createdAt: task.createdAt,
                ),

                // Progress indicator
                PackingProgressIndicator(
                  packedCount: task.packedItemCount,
                  totalCount: task.totalItemCount,
                  itemsPacked: task.packedItemCount.toDouble(),
                  efficiency: task.packingEfficiency,
                ),

                // Special notes (if any)
                if (task.notes != null) SpecialNotesAlert(notes: task.notes!),

                // Items to pack
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Items to Pack',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),

                ...List.generate(task.items.length, (index) {
                  final item = task.items[index];
                  return OrderItemCard(
                    item: item,
                    isSelected: _currentItemIndex == index,
                    onTap: () {
                      setState(() => _currentItemIndex = index);
                    },
                    onVerify: () => _markItemPacked(item),
                  );
                }),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    spacing: 12,
                    children: [
                      if (!_isPacking)
                        ElevatedButton.icon(
                          onPressed: _startPacking,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Packing'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: AppTheme.info,
                            foregroundColor: Colors.white,
                          ),
                        )
                      else ...[
                        ElevatedButton.icon(
                          onPressed: task.allItemsPacked ? _completePacking : null,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Complete Packing'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: task.allItemsPacked ? AppTheme.success : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuantityInputSheet extends StatefulWidget {
  final FulfillmentItem item;
  final Function(double) onSave;

  const _QuantityInputSheet({required this.item, required this.onSave});

  @override
  State<_QuantityInputSheet> createState() => _QuantityInputSheetState();
}

class _QuantityInputSheetState extends State<_QuantityInputSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.item.packedQuantity > 0
          ? widget.item.packedQuantity.toString()
          : widget.item.requiredQuantity.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Quantity Packed',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(widget.item.productName, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Enter quantity',
              suffixText: widget.item.unit,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Required: ${widget.item.requiredQuantity} ${widget.item.unit}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final quantity = double.tryParse(_controller.text) ?? 0;
                  if (quantity > 0) {
                    widget.onSave(quantity);
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid quantity'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
