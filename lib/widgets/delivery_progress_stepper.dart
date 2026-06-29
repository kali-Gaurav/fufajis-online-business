import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

class DeliveryProgressStepper extends StatelessWidget {
  final int currentStep; // 0: OTP, 1: Photo, 2: Signature, 3: Complete
  final List<bool> completedSteps; // Track which steps are completed

  const DeliveryProgressStepper({
    super.key,
    required this.currentStep,
    required this.completedSteps,
  });

  @override
  Widget build(BuildContext context) {
    const steps = ['OTP', 'Photo', 'Signature', 'Complete'];

    return Column(
      children: [
        // Step indicators
        Row(
          children: List.generate(
            steps.length,
            (index) => Expanded(
              child: Column(
                children: [
                  // Circle
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getStepColor(index),
                      border: Border.all(
                        color: _getStepBorderColor(index),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: completedSteps[index]
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Label
                  Text(
                    steps[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: index <= currentStep ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Progress line
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: (currentStep + 1) / steps.length,
            minHeight: 6,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppTheme.info,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStepColor(int index) {
    if (completedSteps[index]) {
      return AppTheme.success;
    } else if (index == currentStep) {
      return AppTheme.info;
    } else if (index < currentStep) {
      return AppTheme.success;
    } else {
      return Colors.grey[300]!;
    }
  }

  Color _getStepBorderColor(int index) {
    if (completedSteps[index]) {
      return AppTheme.success;
    } else if (index == currentStep) {
      return AppTheme.info;
    } else {
      return Colors.grey[300]!;
    }
  }
}
