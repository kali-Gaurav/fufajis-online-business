import 'package:flutter/material.dart';

class ProfileCompletionCard extends StatelessWidget {
  final int completionPercentage;

  const ProfileCompletionCard({
    super.key,
    required this.completionPercentage,
  });

  @override
  Widget build(BuildContext context) {
    // Determine color based on completion
    final Color progressColor = completionPercentage < 50
        ? Colors.orange
        : completionPercentage < 100
            ? Colors.blue
            : Colors.green;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: progressColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: progressColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile Completion',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                '$completionPercentage%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: completionPercentage / 100,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          if (completionPercentage < 100)
            Text(
              'Complete your profile to make checkout faster and unlock personalized offers.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            )
          else
            const Text(
              'Your profile is complete! 🎉',
              style: TextStyle(
                fontSize: 13,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
