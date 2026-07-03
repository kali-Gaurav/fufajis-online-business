import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Reusable form input widget with validation feedback
///
/// Features:
/// - Orange focus border
/// - Real-time error display
/// - Support for multiline input
/// - Customizable keyboard type
/// - Hindi/English support
class FormInput extends StatefulWidget {
  final String label;
  final String placeholder;
  final TextEditingController controller;
  final String? Function(String)? validator;
  final TextInputType keyboardType;
  final int maxLines;
  final int minLines;
  final bool obscureText;
  final VoidCallback? onFocus;
  final Function(String)? onChanged;
  final String? initialError;

  const FormInput({
    super.key,
    required this.label,
    required this.placeholder,
    required this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.minLines = 1,
    this.obscureText = false,
    this.onFocus,
    this.onChanged,
    this.initialError,
  });

  @override
  State<FormInput> createState() => _FormInputState();
}

class _FormInputState extends State<FormInput> {
  late FocusNode _focusNode;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    _error = widget.initialError;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      widget.onFocus?.call();
    }
  }

  void _handleChanged(String value) {
    // Validate on change
    if (widget.validator != null) {
      setState(() => _error = widget.validator!(value));
    }
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LABEL
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : AppTheme.grey900,
          ),
        ),
        const SizedBox(height: 8),

        // TEXT FIELD
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: widget.keyboardType,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          obscureText: widget.obscureText,
          onChanged: _handleChanged,
          textInputAction: widget.maxLines == 1 ? TextInputAction.next : TextInputAction.none,
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: TextStyle(color: isDark ? Colors.white38 : AppTheme.grey400),

            // FILL COLOR
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,

            // BORDER
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : AppTheme.grey300),
            ),

            // ENABLED BORDER
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : AppTheme.grey300),
            ),

            // FOCUSED BORDER (ORANGE)
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),

            // ERROR BORDER (RED)
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.error, width: 1),
            ),

            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.error, width: 2),
            ),

            // PADDING
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

            // SUFFIX ICON (for error)
            suffixIcon: _error != null && _error!.isNotEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
                  )
                : null,
          ),
        ),

        // ERROR MESSAGE
        if (_error != null && _error!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.error,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
