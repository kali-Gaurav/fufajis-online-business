import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// Elder Mode Indicator Badge
/// Displays "👴 Elder Mode ON" to make accessibility mode visible to user.
/// Appears in search header when isElderly is true.
///
/// Problem Fixed: User didn't know they were in Elder Mode
/// Solution: Visual indicator + settings toggle

class ElderModeIndicator extends StatelessWidget {
  final VoidCallback? onToggle;
  final bool isElderlyMode;

  const ElderModeIndicator({super.key, this.onToggle, required this.isElderlyMode});

  @override
  Widget build(BuildContext context) {
    if (!isElderlyMode) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3), width: 1.5),
      ),
      child: GestureDetector(
        onTap: onToggle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👴', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              'Elder Mode',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.success,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onToggle != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 14, color: AppTheme.success),
            ],
          ],
        ),
      ),
    );
  }
}
