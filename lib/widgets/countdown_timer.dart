import 'dart:async';
import 'package:flutter/material.dart';

class CountdownTimer extends StatefulWidget {
  final DateTime endTime;
  final TextStyle? style;

  const CountdownTimer({super.key, required this.endTime, this.style});

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  late Duration _duration;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _duration = widget.endTime.difference(DateTime.now());
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _duration = widget.endTime.difference(DateTime.now());
          if (_duration.isNegative) {
            _timer.cancel();
            _pulseController.stop();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_duration.isNegative) return const Text('Ended');

    final hours = _duration.inHours.toString().padLeft(2, '0');
    final minutes = (_duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_duration.inSeconds % 60).toString().padLeft(2, '0');

    // Step 9.2: Pulse animation on "Live" deals
    return FadeTransition(
      opacity: Tween<double>(begin: 0.7, end: 1.0).animate(_pulseController),
      child: Text(
        '$hours:$minutes:$seconds',
        style: widget.style ?? const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
