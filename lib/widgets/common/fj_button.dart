import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

enum FjButtonType { primary, secondary, outline, text, error, success, info, danger }

class FjButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final FjButtonType type;
  final IconData? icon;
  final bool isLoading;
  final bool isDisabled;
  final bool isError;
  final double? width;
  final double height;
  final EdgeInsets? padding;

  const FjButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = FjButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.isDisabled = false,
    this.isError = false,
    this.width,
    this.height = 50.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context); // Unused

    Widget content = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          );

    final effectiveOnPressed = (isLoading || isDisabled) ? null : onPressed;

    switch (type) {
      case FjButtonType.primary:
        return Semantics(
          button: true,
          label: label,
          enabled: !isDisabled && !isLoading,
          child: SizedBox(
            width: width,
            height: height,
            child: ElevatedButton(
              onPressed: effectiveOnPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: padding,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isError ? const BorderSide(color: AppTheme.error, width: 2) : BorderSide.none,
                ),
                elevation: 0,
              ).copyWith(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) return AppTheme.grey100;
                  return AppTheme.primary;
                }),
              ),
              child: content,
            ),
          ),
        );
      case FjButtonType.secondary:
        return Semantics(
          button: true,
          label: label,
          enabled: !isDisabled && !isLoading,
          child: SizedBox(
            width: width,
            height: height,
            child: ElevatedButton(
              onPressed: effectiveOnPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.grey100,
                foregroundColor: AppTheme.textPrimary,
                padding: padding,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isError ? const BorderSide(color: AppTheme.error, width: 2) : BorderSide.none,
                ),
                elevation: 0,
              ),
              child: content,
            ),
          ),
        );
      case FjButtonType.outline:
        return Semantics(
          button: true,
          label: label,
          enabled: !isDisabled && !isLoading,
          child: SizedBox(
            width: width,
            height: height,
            child: OutlinedButton(
              onPressed: effectiveOnPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: padding,
                side: BorderSide(
                  color: isError ? AppTheme.error : AppTheme.primary,
                  width: isError ? 2 : 1,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: content,
            ),
          ),
        );
      case FjButtonType.error:
      case FjButtonType.danger:
        return Semantics(
          button: true,
          label: label,
          enabled: !isDisabled && !isLoading,
          child: SizedBox(
            width: width,
            height: height,
            child: ElevatedButton(
              onPressed: effectiveOnPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                padding: padding,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: content,
            ),
          ),
        );
      case FjButtonType.text:
        return Semantics(
          button: true,
          label: label,
          enabled: !isDisabled && !isLoading,
          child: TextButton(
            onPressed: effectiveOnPressed,
            style: TextButton.styleFrom(
              foregroundColor: isError ? AppTheme.error : AppTheme.primary,
              padding: padding,
            ),
            child: content,
          ),
        );
      case FjButtonType.success:
        return Semantics(
          button: true,
          label: label,
          enabled: !isDisabled && !isLoading,
          child: SizedBox(
            width: width,
            height: height,
            child: ElevatedButton(
              onPressed: effectiveOnPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: padding,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: content,
            ),
          ),
        );
      case FjButtonType.info:
        return Semantics(
          button: true,
          label: label,
          enabled: !isDisabled && !isLoading,
          child: SizedBox(
            width: width,
            height: height,
            child: ElevatedButton(
              onPressed: effectiveOnPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.info,
                foregroundColor: Colors.white,
                padding: padding,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: content,
            ),
          ),
        );
    }
  }
}
