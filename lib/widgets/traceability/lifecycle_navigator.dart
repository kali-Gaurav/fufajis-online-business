import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class LifecycleNode {
  final String id;
  final String title;
  final String type; // e.g., 'Payment', 'Delivery Task'
  final DateTime timestamp;
  final String status; // e.g., 'Completed', 'Pending'
  final List<String> childrenIds;

  LifecycleNode({
    required this.id,
    required this.title,
    required this.type,
    required this.timestamp,
    required this.status,
    this.childrenIds = const [],
  });
}

class LifecycleNavigator extends StatelessWidget {
  final String rootEntityTitle;
  final List<LifecycleNode> nodes;

  const LifecycleNavigator({super.key, required this.rootEntityTitle, required this.nodes});

  @override
  Widget build(BuildContext context) {
    // A simplified vertical tree view for UI demonstration of the Graph.
    // In a production app, this might use a canvas-based Graph Viewer or a recursive tree builder.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'LIFECYCLE GRAPH: $rootEntityTitle',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...nodes.map((n) => _buildNode(n)),
        ],
      ),
    );
  }

  Widget _buildNode(LifecycleNode node) {
    Color statusColor = Colors.grey;
    if (node.status == 'Completed') statusColor = AppTheme.success;
    if (node.status == 'Pending') statusColor = AppTheme.warning;
    if (node.status == 'Failed') statusColor = AppTheme.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              if (node.childrenIds.isNotEmpty)
                Container(width: 2, height: 40, color: Colors.grey.shade300),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(node.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      node.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(node.type, style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
