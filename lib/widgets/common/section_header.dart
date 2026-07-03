// ============================================================
//  SectionHeader — Consistent section titles with optional CTA
//
//  Usage:
//    SectionHeader(title: 'Flash Deals', onSeeAll: () => ...)
//    SectionHeader.branded(title: 'For You', emoji: '🎯')
// ============================================================

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? emoji;
  final String? seeAllLabel;
  final VoidCallback? onSeeAll;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.emoji,
    this.seeAllLabel,
    this.onSeeAll,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  factory SectionHeader.branded({
    required String title,
    String? emoji,
    String? subtitle,
    VoidCallback? onSeeAll,
  }) {
    return SectionHeader(
      title: title,
      emoji: emoji,
      subtitle: subtitle,
      seeAllLabel: 'See All',
      onSeeAll: onSeeAll,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Optional emoji
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
          ],

          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.grey900,
                    height: 1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // See all / trailing
          if (trailing != null)
            trailing!
          else if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      seeAllLabel ?? 'See All',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppTheme.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
