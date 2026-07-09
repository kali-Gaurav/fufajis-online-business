import 'package:flutter/material.dart';
import 'common/empty_state_widget.dart';

/// Legacy wrapper for [EmptyStateWidget] to maintain backward compatibility.
/// DEPRECATED: Use [EmptyStateWidget] directly for new development.
class FjEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;

  const FjEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: icon,
      title: title,
      subtitle: subtitle,
      actionLabel: buttonLabel,
      onAction: onButtonTap,
    );
  }
}
