// ============================================================
//  RoleGreetingHeader — Personalised greeting banner
//
//  Usage (in dashboard body — not AppBar):
//    RoleGreetingHeader(
//      name: 'Gaurav',
//      role: 'Owner',
//      subtitle: 'Jaipur Branch',
//      accentColor: AppTheme.ownerAccent,
//    )
// ============================================================

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class RoleGreetingHeader extends StatelessWidget {
  final String name;
  final String role;
  final String? subtitle;
  final Color accentColor;
  final Widget? trailing;
  final String? avatarUrl;

  const RoleGreetingHeader({
    super.key,
    required this.name,
    required this.role,
    this.subtitle,
    this.accentColor = AppTheme.primary,
    this.trailing,
    this.avatarUrl,
  });

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withOpacity(0.12),
              border: Border.all(color: accentColor.withOpacity(0.25), width: 2),
            ),
            child: avatarUrl != null
                ? ClipOval(child: Image.network(avatarUrl!, fit: BoxFit.cover))
                : Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()}, $name 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.grey900,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.circle, size: 4, color: AppTheme.grey400),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Trailing widget (e.g. notification bell)
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Shift status chip ──────────────────────────────────────

class ShiftStatusChip extends StatelessWidget {
  final bool isOnShift;
  const ShiftStatusChip({super.key, required this.isOnShift});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOnShift
            ? AppTheme.info.withOpacity(0.12)
            : AppTheme.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnShift
              ? AppTheme.info.withOpacity(0.40)
              : AppTheme.warning.withOpacity(0.40),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnShift ? AppTheme.success : AppTheme.warning,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOnShift ? 'On Shift' : 'Not Checked In',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isOnShift ? AppTheme.success : AppTheme.warning,
            ),
          ),
        ],
      ),
    );
  }
}
