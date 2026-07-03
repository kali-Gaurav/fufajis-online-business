import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Consistent button widget with orange/white branding
///
/// Features:
/// - Primary (orange) and secondary (outline) styles
/// - Loading state with spinner
/// - Disabled state
/// - Minimum 48x48 touch target
class Button extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final double? width;
  final double height;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final TextStyle? textStyle;

  const Button({
    super.key,
    required this.title,
    this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.width,
    this.height = 48,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppTheme.primary;
    final txtColor = textColor ?? (isSecondary ? AppTheme.primary : Colors.white);

    if (isSecondary) {
      return SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: OutlinedButton.icon(
          onPressed: isLoading ? null : onPressed,
          icon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                  ),
                )
              : (icon != null ? Icon(icon, size: 20, color: txtColor) : const SizedBox.shrink()),
          label: Text(
            title,
            style:
                textStyle ?? TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: txtColor),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.primary, width: 2),
            foregroundColor: txtColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : (icon != null ? Icon(icon, size: 20, color: Colors.white) : const SizedBox.shrink()),
        label: Text(
          title,
          style:
              textStyle ??
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isLoading ? AppTheme.grey500 : bgColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.grey500,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

/// Small icon button for close/back actions
class IconButtonSmall extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final Color? backgroundColor;

  const IconButtonSmall({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: backgroundColor ?? AppTheme.grey100, shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(icon, color: color ?? AppTheme.grey900, size: 20),
        onPressed: onPressed,
        splashRadius: 20,
      ),
    );
  }
}
