import 'package:flutter/material.dart';

class QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
}

class QuickActionFramework extends StatelessWidget {
  final List<QuickAction> actions;

  const QuickActionFramework({
    super.key,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: actions.map((action) => _buildActionPill(context, action)).toList(),
      ),
    );
  }

  Widget _buildActionPill(BuildContext context, QuickAction action) {
    final color = action.color ?? Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                action.label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
