import 'dart:async';
import 'package:flutter/material.dart';

class CountdownTimer extends StatefulWidget {
  final DateTime endTime;
  final TextStyle? style;

  const CountdownTimer({super.key, required this.endTime, this.style});

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Timer _timer;
  late Duration _duration;

  @override
  void initState() {
    super.initState();
    _duration = widget.endTime.difference(DateTime.now());
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _duration = widget.endTime.difference(DateTime.now());
          if (_duration.isNegative) {
            _timer.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_duration.isNegative) return const Text('Ended');
    
    final hours = _duration.inHours.toString().padLeft(2, '0');
    final minutes = (_duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_duration.inSeconds % 60).toString().padLeft(2, '0');

    return Text(
      '$hours:$minutes:$seconds',
      style: widget.style ?? const TextStyle(fontWeight: FontWeight.bold),
    );
  }
}
