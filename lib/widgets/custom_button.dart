import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// A versatile, reusable button widget for Fufaji's Online.
///
/// Full-width by default, orange primary color, supports loading state,
/// outlined variant, optional leading icon, and disabled state.
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? color;
  final double? width;
  final IconData? icon;
  final double verticalPadding;
  final double borderRadius;
  final TextStyle? textStyle;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.color,
    this.width,
    this.icon,
    this.verticalPadding = 16.0,
    this.borderRadius = 12.0,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.primary;
    final isDisabled = onPressed == null || isLoading;

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius));

    final labelContent = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOutlined ? effectiveColor : AppTheme.white,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: isOutlined ? effectiveColor : AppTheme.white),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style:
                    textStyle ??
                    TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isOutlined ? effectiveColor : AppTheme.white,
                    ),
              ),
            ],
          );

    final buttonChild = SizedBox(
      width: width ?? double.infinity,
      child: isOutlined
          ? OutlinedButton(
              onPressed: isDisabled ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: effectiveColor,
                side: BorderSide(color: isDisabled ? AppTheme.grey300 : effectiveColor, width: 1.5),
                padding: EdgeInsets.symmetric(vertical: verticalPadding),
                shape: shape,
              ),
              child: labelContent,
            )
          : ElevatedButton(
              onPressed: isDisabled ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDisabled ? AppTheme.grey300 : effectiveColor,
                foregroundColor: AppTheme.white,
                elevation: isDisabled ? 0 : 2,
                padding: EdgeInsets.symmetric(vertical: verticalPadding),
                shape: shape,
              ),
              child: labelContent,
            ),
    );

    return buttonChild;
  }
}
