import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/fufaji_colors.dart';

/// FjFocusableButton - Accessible Interactive Element
///
/// Provides keyboard navigation and screen reader support for any button-like widget.
/// Features:
/// - Tab/Shift+Tab navigation
/// - Enter/Space key activation
/// - 2px focus ring (solid border in primary color)
/// - Screen reader integration via Semantics
/// - Optional autofocus
/// - Escape key to unfocus
///
/// Example:
/// ```dart
/// FjFocusableButton(
///   label: 'Add to Cart',
///   onPressed: () => print('Added!'),
///   child: Icon(Icons.add),
/// )
/// ```

class FjFocusableButton extends StatefulWidget {
  /// Child widget to wrap (typically icon or text)
  final Widget child;

  /// Callback when button is pressed (Enter/Space or tap)
  final VoidCallback? onPressed;

  /// External FocusNode for managing focus state
  final FocusNode? focusNode;

  /// Auto-focus this button on build
  final bool autofocus;

  /// Semantic label for screen readers (defaults to child content description)
  final String? semanticLabel;

  /// Show focus ring decoration
  final bool showFocusRing;

  const FjFocusableButton({
    super.key,
    required this.child,
    this.onPressed,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.showFocusRing = true,
  });

  @override
  State<FjFocusableButton> createState() => _FjFocusableButtonState();
}

class _FjFocusableButtonState extends State<FjFocusableButton> {
  late FocusNode _internalFocusNode;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    super.dispose();
  }

  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode;

  void _handlePress() {
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKey: (node, event) {
        if (event.isKeyPressed(LogicalKeyboardKey.enter) ||
            event.isKeyPressed(LogicalKeyboardKey.space)) {
          _handlePress();
          return KeyEventResult.handled;
        }
        if (event.isKeyPressed(LogicalKeyboardKey.escape)) {
          _focusNode.unfocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      onFocusChange: (hasFocus) {
        setState(() {
          // Trigger rebuild to show/hide focus ring
        });
      },
      child: GestureDetector(
        onTap: _handlePress,
        onTapDown: (_) {
          setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
        },
        child: Semantics(
          button: true,
          label: widget.semanticLabel,
          enabled: widget.onPressed != null,
          onTap: widget.onPressed,
          child: Container(
            decoration: widget.showFocusRing && _focusNode.hasFocus
                ? BoxDecoration(
                    border: Border.all(
                      color: FufajiColors.primary,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
