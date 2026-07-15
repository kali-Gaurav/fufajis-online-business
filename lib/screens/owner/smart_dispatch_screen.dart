import '../../services/logging_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/supabase_config.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../constants/order_status.dart';
import '../../services/delivery_clustering_service.dart';
import '../../utils/app_theme.dart';

class SmartDispatchScreen extends StatefulWidget {
  const SmartDispatchScreen({super.key});

  @override
  State<SmartDispatchScreen> createState() => _SmartDispatchScreenState();
}

class _SmartDispatchScreenState extends State<SmartDispatchScreen> {
  final DeliveryClusteringService _clusteringService = DeliveryClusteringService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<OrderModel> _pendingOrders = [];
  List<DeliveryCluster> _clusters = [];
  List<Map<String, dynamic>> _agents = [];
  // clusterId → selected agentId
  final Map<String, String?> _selectedAgent = {};
  // orderId → clusterId (for drag-drop override)
  final Map<String, String> _orderClusterMap = {};

  bool _isLoading = true;
  bool _isClustering = false;
  bool _isDispatching = false;
  String? _error;

  // OTP-less eligibility cache: customerId → bool
  final Map<String, bool> _otplessCache = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await Future.wait([_loadPendingOrders(), _loadAgents()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadPendingOrders() async {
    try {
      final snap = await _firestore
          .collection('orders')
          .where(
            'status',
            whereIn: [OrderStatus.confirmed.toString(), OrderStatus.packed.toString()],
          )
          .orderBy('createdAt')
          .get();

      _pendingOrders = snap.docs.map((d) => OrderModel.fromMap(d.data())).toList();

      // Pre-fetch OTP-less eligibility
      final customerIds = _pendingOrders.map((o) => o.customerId).toSet();
      for (final cid in customerIds) {
        _otplessCache[cid] = await _clusteringService.isOtplessEligible(cid);
      }
    } catch (e) {
      setState(() => _error = 'Failed to load orders: $e');
    }
  }

  Future<void> _loadAgents() async {
    try {
      final snap = await _firestore
          .collection('users')
          .where('role', isEqualTo: UserRole.rider.toString())
          .where('isActive', isEqualTo: true)
          .get();

      _agents = snap.docs.map((d) {
        final data = d.data();
        return {'id': d.id, 'name': data['name'] ?? 'Agent', 'phone': data['phoneNumber'] ?? ''};
      }).toList();
    } catch (e) {
      // Non-fatal: agents may be empty
    }
  }

  // ── Clustering ────────────────────────────────────────────────────────────

  void _autocluster() {
    setState(() => _isClustering = true);
    try {
      final clusters = _clusteringService.clusterOrders(_pendingOrders);
      final orderClusterMap = <String, String>{};
      for (final c in clusters) {
        for (final o in c.orders) {
          orderClusterMap[o.id] = c.id;
        }
      }
      setState(() {
        _clusters = clusters;
        _orderClusterMap.addAll(orderClusterMap);
        for (final c in clusters) {
          _selectedAgent.putIfAbsent(c.id, () => null);
        }
      });
    } finally {
      setState(() => _isClustering = false);
    }
  }

  // ── Dispatch ──────────────────────────────────────────────────────────────

  Future<void> _dispatchCluster(DeliveryCluster cluster) async {
    final agentId = _selectedAgent[cluster.id];
    if (agentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a delivery agent first'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final agent = _agents.firstWhere(
      (a) => a['id'] == agentId,
      orElse: () => {'id': agentId, 'name': 'Agent', 'phone': ''},
    );

    setState(() => _isDispatching = true);
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'order-lifecycle',
        body: {
          'action': 'dispatch-cluster',
          'orderIds': cluster.orders.map((o) => o.id).toList(),
          'riderId': agentId,
        },
      );

      final data = response.data as Map<String, dynamic>? ?? {};
      if (data['success'] != true) {
        throw Exception('Server failed to dispatch orders.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cluster ${cluster.id} dispatched to ${agent['name']}'),
            backgroundColor: AppTheme.success,
          ),
        );
        setState(() {
          _clusters.remove(cluster);
          for (final o in cluster.orders) {
            _pendingOrders.removeWhere((p) => p.id == o.id);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dispatch failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isDispatching = false);
    }
  }

  // ── Drag-drop: move order to another cluster ──────────────────────────────

  void _moveOrderToCluster(OrderModel order, String fromClusterId, String toClusterId) {
    setState(() {
      final fromCluster = _clusters.firstWhere((c) => c.id == fromClusterId);
      final toCluster = _clusters.firstWhere((c) => c.id == toClusterId);

      final fromOrders = List<OrderModel>.from(fromCluster.orders)..remove(order);
      final toOrders = List<OrderModel>.from(toCluster.orders)..add(order);

      final fromIdx = _clusters.indexOf(fromCluster);
      final toIdx = _clusters.indexOf(toCluster);

      _clusters[fromIdx] = DeliveryCluster(
        id: fromCluster.id,
        orders: fromOrders,
        centerLat: fromCluster.centerLat,
        centerLng: fromCluster.centerLng,
        totalDistanceKm: fromCluster.totalDistanceKm,
        estimatedTime: fromCluster.estimatedTime,
      );
      _clusters[toIdx] = DeliveryCluster(
        id: toCluster.id,
        orders: toOrders,
        centerLat: toCluster.centerLat,
        centerLng: toCluster.centerLng,
        totalDistanceKm: toCluster.totalDistanceKm,
        estimatedTime: toCluster.estimatedTime,
      );
      _orderClusterMap[order.id] = toClusterId;
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Smart Dispatch', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent))
          : _error != null
          ? _buildError()
          : Column(
              children: [
                _buildTopBar(),
                Expanded(child: _clusters.isEmpty ? _buildEmptyState() : _buildClusterList()),
              ],
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppTheme.grey700)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: AppTheme.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_pendingOrders.length} Pending Orders',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                Text(
                  '${_agents.length} agents available',
                  style: const TextStyle(color: AppTheme.grey600, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _pendingOrders.isEmpty || _isClustering ? null : _autocluster,
            icon: _isClustering
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.white),
                  )
                : const Icon(Icons.auto_awesome),
            label: const Text('Auto Cluster'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_pendingOrders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: AppTheme.success),
            SizedBox(height: 16),
            Text('No pending orders!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('All orders have been dispatched.', style: TextStyle(color: AppTheme.grey600)),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.route, size: 64, color: AppTheme.grey400),
          const SizedBox(height: 16),
          Text(
            '${_pendingOrders.length} orders ready',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap "Auto Cluster" to group orders by area',
            style: TextStyle(color: AppTheme.grey600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _autocluster,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Auto Cluster Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildClusterList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _clusters.length,
      itemBuilder: (context, i) => _buildClusterCard(_clusters[i]),
    );
  }

  Widget _buildClusterCard(DeliveryCluster cluster) {
    final minutes = cluster.estimatedTime.inMinutes;
    final agent = _selectedAgent[cluster.id];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    cluster.id.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cluster.areaLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Stats row
            Row(
              children: [
                _stat(Icons.shopping_bag_outlined, '${cluster.orderCount} orders', AppTheme.info),
                const SizedBox(width: 16),
                _stat(
                  Icons.route,
                  '${cluster.totalDistanceKm.toStringAsFixed(1)} km',
                  AppTheme.info,
                ),
                const SizedBox(width: 16),
                _stat(Icons.schedule, '~$minutes min', AppTheme.warning),
              ],
            ),

            const Divider(height: 20),

            // Orders list with drag targets
            ...cluster.orders.map((order) => _buildOrderRow(order, cluster)),

            const SizedBox(height: 12),

            // COD total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'COD to Collect:',
                  style: TextStyle(color: AppTheme.grey600, fontSize: 13),
                ),
                Text(
                  '₹${cluster.codTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.info,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Agent selector + dispatch
            Row(
              children: [
                Expanded(child: _buildAgentDropdown(cluster)),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isDispatching || agent == null
                      ? null
                      : () => _dispatchCluster(cluster),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.info,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  child: const Text('Dispatch'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _buildOrderRow(OrderModel order, DeliveryCluster cluster) {
    final otpless = _otplessCache[order.customerId] ?? false;
    final stopIdx = cluster.orders.indexOf(order) + 1;

    return Draggable<Map<String, String>>(
      data: {'orderId': order.id, 'fromCluster': cluster.id},
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          color: AppTheme.primary.withOpacity(0.9),
          child: Text('#${order.orderNumber}', style: const TextStyle(color: AppTheme.white)),
        ),
      ),
      child: DragTarget<Map<String, String>>(
        onAcceptWithDetails: (details) {
          final data = details.data;
          final draggedOrderId = data['orderId']!;
          final fromCluster = data['fromCluster']!;
          if (fromCluster == cluster.id) return;
          final draggedOrder = _pendingOrders.firstWhere(
            (o) => o.id == draggedOrderId,
            orElse: () {
              for (final c in _clusters) {
                try {
                  return c.orders.firstWhere((o) => o.id == draggedOrderId);
                } catch (e, stack) {
                  LoggingService().error('Silent error caught', e, stack);
                }
              }
              return order;
            },
          );
          _moveOrderToCluster(draggedOrder, fromCluster, cluster.id);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovered = candidateData.isNotEmpty;
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isHovered ? AppTheme.primary.withOpacity(0.08) : AppTheme.grey50,
              borderRadius: BorderRadius.circular(8),
              border: isHovered ? Border.all(color: AppTheme.primary, width: 1.5) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$stopIdx',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#${order.orderNumber}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            order.customerName,
                            style: const TextStyle(color: AppTheme.grey700, fontSize: 13),
                          ),
                          if (otpless) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'OTP-FREE',
                                style: TextStyle(
                                  color: AppTheme.success,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        order.deliveryAddress.fullAddress,
                        style: const TextStyle(color: AppTheme.grey600, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${order.totalAmount.toDouble().toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.drag_indicator, size: 18, color: AppTheme.grey400),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAgentDropdown(DeliveryCluster cluster) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedAgent[cluster.id],
      decoration: InputDecoration(
        labelText: 'Assign Agent',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Select Agent')),
        ..._agents.map(
          (a) =>
              DropdownMenuItem<String>(value: a['id'] as String, child: Text(a['name'] as String)),
        ),
      ],
      onChanged: (val) {
        setState(() => _selectedAgent[cluster.id] = val);
      },
    );
  }
}
