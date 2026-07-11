import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_tracking_model.dart';
import '../../providers/order_tracking_provider.dart';

class OrderDeliveryConfirmationScreen extends StatefulWidget {
  final String orderId;

  const OrderDeliveryConfirmationScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderDeliveryConfirmationScreen> createState() => _OrderDeliveryConfirmationScreenState();
}

class _OrderDeliveryConfirmationScreenState extends State<OrderDeliveryConfirmationScreen> {
  int deliveryRating = 0;
  final List<String> issues = [];
  final feedbackController = TextEditingController();
  bool isSubmitting = false;

  final List<String> issueOptions = [
    'Missing item',
    'Damaged item',
    'Wrong item',
    'Wrong quantity',
    'Poor delivery experience',
  ];

  @override
  void dispose() {
    feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Delivered'),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Success icon
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.check_circle,
                size: 48,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              '🎉 Thank You! 🎉',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            // Order info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Order #${widget.orderId.substring(0, 8)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Delivered at ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} today',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Delivery rating
            _buildSectionTitle('HOW WAS YOUR DELIVERY?', context),
            _buildRatingSection(),
            const SizedBox(height: 24),

            // Any issues
            _buildSectionTitle('Any issues?', context),
            _buildIssuesSection(),
            const SizedBox(height: 24),

            // Feedback
            _buildSectionTitle('Additional Feedback (optional)', context),
            TextField(
              controller: feedbackController,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'Tell us more about your experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submitFeedback,
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('SUBMIT FEEDBACK'),
              ),
            ),
            const SizedBox(height: 12),

            // Skip button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Skip'),
            ),
            const SizedBox(height: 12),

            // Divider
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 12),

            // Additional options
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement reorder
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('REORDER SAME ITEMS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Navigate to home
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.shopping_bag),
                label: const Text('CONTINUE SHOPPING'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildRatingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  deliveryRating = index + 1;
                });
              },
              child: Icon(
                Icons.star,
                size: 40,
                color: index < deliveryRating ? Colors.orange : Colors.grey.shade300,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildIssuesSection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: issueOptions.map((option) {
          final isSelected = issues.contains(option);
          return CheckboxListTile(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  issues.add(option);
                } else {
                  issues.remove(option);
                }
              });
            },
            title: Text(option),
            activeColor: Colors.orange,
          );
        }).toList(),
      ),
    );
  }

  Future<void> _submitFeedback() async {
    setState(() {
      isSubmitting = true;
    });

    try {
      // TODO: Submit feedback to backend
      print('Rating: $deliveryRating');
      print('Issues: $issues');
      print('Feedback: ${feedbackController.text}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }
}
