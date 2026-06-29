import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Toast notification helper utilities
/// Shows brief, non-intrusive feedback messages
class ToastUtils {
  static void showSuccess(BuildContext context, String message) {
    _showToast(context, message, AppTheme.success, Icons.check_circle_rounded);
  }

  static void showError(BuildContext context, String message) {
    _showToast(context, message, AppTheme.error, Icons.error_outline_rounded);
  }

  static void showInfo(BuildContext context, String message) {
    _showToast(context, message, AppTheme.info, Icons.info_outline_rounded);
  }

  static void showWarning(BuildContext context, String message) {
    _showToast(context, message, AppTheme.warning, Icons.warning_amber_rounded);
  }

  static void _showToast(
    BuildContext context,
    String message,
    Color bgColor,
    IconData icon,
  ) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      debugPrint('Error showing toast: $e');
    }
  }

  /// Show validation error below a form field
  /// Use in onChanged callback after validation
  static void showFieldError(
    BuildContext context,
    String fieldName,
    String errorMessage,
  ) {
    showError(context, '$fieldName: $errorMessage');
  }

  /// Show success with custom action
  static void showSuccessWithAction(
    BuildContext context,
    String message, {
    String actionLabel = 'UNDO',
    VoidCallback? onAction,
  }) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.success,
          action: SnackBarAction(
            label: actionLabel,
            textColor: Colors.white,
            onPressed: onAction ?? () {},
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('Error showing toast with action: $e');
    }
  }
}
