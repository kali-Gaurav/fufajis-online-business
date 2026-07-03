import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

class OTPInputField extends StatefulWidget {
  final int length;
  final Function(String) onComplete;
  final TextInputType keyboardType;

  const OTPInputField({
    super.key,
    this.length = 6,
    required this.onComplete,
    this.keyboardType = TextInputType.number,
  });

  @override
  State<OTPInputField> createState() => _OTPInputFieldState();
}

class _OTPInputFieldState extends State<OTPInputField> {
  late List<FocusNode> _focusNodes;
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    _controllers = List.generate(widget.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _handleInput(String value, int index) {
    if (value.isEmpty) {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      return;
    }

    if (value.length > 1) {
      _controllers[index].text = value[value.length - 1];
    } else if (value.length == 1 && widget.keyboardType == TextInputType.number) {
      if (!RegExp(r'[0-9]').hasMatch(value)) {
        _controllers[index].clear();
        return;
      }
    }

    if (index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      // All fields filled, call onComplete
      String otp = _controllers.map((c) => c.text).join();
      widget.onComplete(otp);
    }
  }

  void _handleBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        widget.length,
        (index) => SizedBox(
          width: 50,
          height: 60,
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            keyboardType: widget.keyboardType,
            textAlign: TextAlign.center,
            maxLength: 1,
            onChanged: (value) => _handleInput(value, index),
            onSubmitted: (_) => _handleBackspace(index),
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.info, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
