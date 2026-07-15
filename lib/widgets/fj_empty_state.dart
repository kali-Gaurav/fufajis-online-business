import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Consistent empty-state component used across all screens.
/// Shows an icon, title, subtitle, and optional CTA button.
class FjEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;
  final Color? iconColor;
  final double iconSize;

  const FjEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.buttonLabel,
    this.onButtonTap,
    this.iconColor,
    this.iconSize = 56,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppTheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container
            Container(
              width: iconSize * 1.6,
              height: iconSize * 1.6,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: iconSize, color: color),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.grey900,
              ),
            ),
            // Subtitle
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.grey500, height: 1.5),
              ),
            ],
            // CTA
            if (buttonLabel != null && onButtonTap != null) ...[
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.buttonGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: AppTheme.primaryGlowShadows(intensity: 0.6),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onButtonTap,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      child: Text(
                        buttonLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact inline empty state (for inside cards/sections)
class FjInlineEmpty extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? color;

  const FjInlineEmpty({super.key, required this.icon, required this.message, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.grey400;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 36, color: c),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c),
          ),
        ],
      ),
    );
  }
}
