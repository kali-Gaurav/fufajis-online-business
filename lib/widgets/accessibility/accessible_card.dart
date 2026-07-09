import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import '../../utils/fufaji_colors.dart';

/// FjAccessibleCard - Keyboard & Screen Reader Compatible Card
///
/// Wraps a card with full accessibility support:
/// - Keyboard navigation (Tab to focus)
/// - Enter key to activate
/// - Screen reader announcements
/// - Visual focus ring (2px border in primary color)
/// - Optional tap and semantics callbacks
///
/// Example:
/// ```dart
/// FjAccessibleCard(
///   title: 'Order #1234',
///   onTap: () => navigateToOrder('1234'),
///   child: OrderDetails(),
/// )
/// ```

class FjAccessibleCard extends StatefulWidget {
  /// Content to display inside card
  final Widget child;

  /// Title for screen reader (semantic label)
  final String? title;

  /// Hint text for screen reader (semantic hint)
  final String? hint;

  /// Callback when card is tapped or Enter pressed
  final VoidCallback? onTap;

  /// Card padding (default 16)
  final EdgeInsets padding;

  /// Card border radius (default 12)
  final double borderRadius;

  /// Background color
  final Color backgroundColor;

  /// External FocusNode
  final FocusNode? focusNode;

  /// Auto-focus on build
  final bool autofocus;

  /// Show focus ring when focused
  final bool showFocusRing;

  /// Shadow elevation (default 2)
  final double elevation;

  const FjAccessibleCard({
    super.key,
    required this.child,
    this.title,
    this.hint,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 12,
    this.backgroundColor = FufajiColors.white,
    this.focusNode,
    this.autofocus = false,
    this.showFocusRing = true,
    this.elevation = 2,
  });

  @override
  State<FjAccessibleCard> createState() => _FjAccessibleCardState();
}

class _FjAccessibleCardState extends State<FjAccessibleCard> {
  late FocusNode _internalFocusNode;

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

  void _handleTap() {
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKey: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space) {
          _handleTap();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _focusNode.unfocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        label: widget.title,
        hint: widget.hint,
        button: widget.onTap != null,
        enabled: widget.onTap != null,
        onTap: widget.onTap,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Card(
            elevation: widget.elevation,
            color: widget.backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              side: widget.showFocusRing && _focusNode.hasFocus
                  ? const BorderSide(
                      color: FufajiColors.primary,
                      width: 2.0,
                    )
                  : BorderSide.none,
            ),
            child: Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
