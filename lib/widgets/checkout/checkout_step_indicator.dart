import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// Step indicator widget for checkout flow progress
class CheckoutStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepTitles;

  const CheckoutStepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
    this.stepTitles = const [
      'Address',
      'Payment',
      'Review',
      'Confirm',
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              totalSteps,
              (index) => _buildStepIndicator(index),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: stepTitles.map((title) {
              final index = stepTitles.indexOf(title);
              final isActive = index <= currentStep;
              final isCurrent = index == currentStep;

              return Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? AppTheme.primary : AppTheme.grey400,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int index) {
    final isCompleted = index < currentStep;
    final isCurrent = index == currentStep;

    return Expanded(
      child: Column(
        children: [
          // Step circle with connector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left connector
              if (index > 0)
                Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: index <= currentStep ? AppTheme.primary : AppTheme.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              // Step circle
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted || isCurrent ? AppTheme.primary : Colors.white,
                  border: Border.all(
                    color: isCompleted || isCurrent ? AppTheme.primary : AppTheme.grey300,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? Colors.white : AppTheme.grey500,
                          ),
                        ),
                      ),
              ),
              // Right connector
              if (index < totalSteps - 1)
                Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: index < currentStep ? AppTheme.primary : AppTheme.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact step indicator for smaller screens
class CompactCheckoutStepIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> stepTitles;

  const CompactCheckoutStepIndicator({
    super.key,
    required this.currentStep,
    this.stepTitles = const ['Address', 'Payment', 'Review', 'Done'],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          stepTitles.length,
          (index) => _buildCompactStep(index),
        ),
      ),
    );
  }

  Widget _buildCompactStep(int index) {
    final isCompleted = index < currentStep;
    final isCurrent = index == currentStep;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted || isCurrent ? AppTheme.primary : Colors.white,
              border: Border.all(
                color: isCompleted || isCurrent ? AppTheme.primary : AppTheme.grey300,
                width: 2,
              ),
            ),
            child: isCompleted
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 12,
                  )
                : Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? Colors.white : AppTheme.grey500,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            stepTitles[index],
            style: TextStyle(
              fontSize: 9,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              color: isCurrent ? AppTheme.primary : AppTheme.grey400,
            ),
          ),
        ],
      ),
    );
  }
}

