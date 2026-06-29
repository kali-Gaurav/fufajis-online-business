/// DeliveryFeedbackScreen
///
/// Customer feedback collection after delivery completion.
/// Collects rating, review, and optional photos.
/// Provides smooth UX with confirmation screen.
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class DeliveryFeedbackScreen extends StatefulWidget {
  final String orderId;
  final String customerId;
  final String deliveryTaskId;
  final String riderName;
  final String deliveryAddress;

  const DeliveryFeedbackScreen({
    super.key,
    required this.orderId,
    required this.customerId,
    required this.deliveryTaskId,
    required this.riderName,
    required this.deliveryAddress,
  });

  @override
  State<DeliveryFeedbackScreen> createState() => _DeliveryFeedbackScreenState();
}

class _DeliveryFeedbackScreenState extends State<DeliveryFeedbackScreen> {
  double _deliveryRating = 0;
  double _riderRating = 0;
  double _packagingRating = 0;

  final TextEditingController _reviewController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  final List<File> _selectedImages = [];
  bool _isSubmitting = false;
  bool _submitted = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  /// Pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() {
          if (_selectedImages.length < 3) {
            _selectedImages.add(File(pickedFile.path));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Maximum 3 images allowed')),
            );
          }
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorDialog('Failed to pick image');
    }
  }

  /// Show image source selection dialog
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: const Text('Choose where to upload image from'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
              child: const Text('Camera'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
              child: const Text('Gallery'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Remove selected image
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// Validate feedback before submission
  bool _validateFeedback() {
    if (_deliveryRating == 0) {
      _showErrorDialog('Please rate the delivery speed');
      return false;
    }

    if (_riderRating == 0) {
      _showErrorDialog('Please rate the rider');
      return false;
    }

    if (_packagingRating == 0) {
      _showErrorDialog('Please rate the packaging');
      return false;
    }

    return true;
  }

  /// Submit feedback to backend
  Future<void> _submitFeedback() async {
    if (!_validateFeedback()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Create feedback record
      final feedbackData = {
        'order_id': widget.orderId,
        'customer_id': widget.customerId,
        'delivery_task_id': widget.deliveryTaskId,
        'rider_name': widget.riderName,
        'delivery_address': widget.deliveryAddress,
        'ratings': {
          'delivery_speed': _deliveryRating,
          'rider_behavior': _riderRating,
          'packaging_quality': _packagingRating,
          'overall': (_deliveryRating + _riderRating + _packagingRating) / 3,
        },
        'review': _reviewController.text,
        'has_images': _selectedImages.isNotEmpty,
        'image_count': _selectedImages.length,
        'submitted_at': FieldValue.serverTimestamp(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Save feedback to Firestore
      await _firestore.collection('delivery_feedback').add(feedbackData);

      // Update feedback request status
      final feedbackRequests = await _firestore
          .collection('feedback_requests')
          .where('order_id', isEqualTo: widget.orderId)
          .get();

      for (final doc in feedbackRequests.docs) {
        await doc.reference.update({
          'status': 'submitted',
          'rating': (_deliveryRating + _riderRating + _packagingRating) / 3,
          'review': _reviewController.text,
          'submitted_at': FieldValue.serverTimestamp(),
        });
      }

      setState(() {
        _submitted = true;
        _isSubmitting = false;
      });

      // Show success and navigate
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for your feedback!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate after delay
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.of(context).pop(true);
      });
    } catch (e) {
      print('Error submitting feedback: $e');
      setState(() => _isSubmitting = false);
      _showErrorDialog('Failed to submit feedback. Please try again.');
    }
  }

  /// Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Delivery'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order summary card
              _buildOrderSummaryCard(),
              const SizedBox(height: 24),

              // Delivery Speed Rating
              _buildRatingSection(
                title: 'Delivery Speed',
                subtitle: 'How quickly was your order delivered?',
                rating: _deliveryRating,
                onRatingChanged: (rating) {
                  setState(() => _deliveryRating = rating);
                },
              ),
              const SizedBox(height: 20),

              // Rider Rating
              _buildRatingSection(
                title: 'Rider Behavior',
                subtitle: 'How was the rider\'s behavior and professionalism?',
                rating: _riderRating,
                onRatingChanged: (rating) {
                  setState(() => _riderRating = rating);
                },
              ),
              const SizedBox(height: 20),

              // Packaging Rating
              _buildRatingSection(
                title: 'Packaging Quality',
                subtitle: 'Was your order properly packaged?',
                rating: _packagingRating,
                onRatingChanged: (rating) {
                  setState(() => _packagingRating = rating);
                },
              ),
              const SizedBox(height: 24),

              // Text Review
              _buildReviewSection(),
              const SizedBox(height: 24),

              // Image Upload Section
              _buildImageUploadSection(),
              const SizedBox(height: 24),

              // Issue Report Button
              _buildReportIssueButton(),
              const SizedBox(height: 24),

              // Submit Button
              _buildSubmitButton(),
              const SizedBox(height: 16),

              // Skip Button
              _buildSkipButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Build order summary card
  Widget _buildOrderSummaryCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rider: ${widget.riderName}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Address: ${widget.deliveryAddress}',
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build star rating section
  Widget _buildRatingSection({
    required String title,
    required String subtitle,
    required double rating,
    required ValueChanged<double> onRatingChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 12),
        Center(
          child: CustomStarRating(
            rating: rating,
            onRatingChanged: onRatingChanged,
            size: 40,
            color: Colors.amber,
            borderColor: Colors.grey[300] ?? Colors.grey,
            spacing: 8.0,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            rating == 0 ? 'Tap to rate' : '${rating.toStringAsFixed(1)} / 5.0',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  /// Build review text section
  Widget _buildReviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Comments',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reviewController,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Share your experience (optional)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  /// Build image upload section
  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Photos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Share photos of your order (optional)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 12),
        if (_selectedImages.isEmpty)
          GestureDetector(
            onTap: _showImageSourceDialog,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[50],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to add photos',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _selectedImages.length + (_selectedImages.length < 3 ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _selectedImages.length) {
                return GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add, color: Colors.grey[400]),
                  ),
                );
              }

              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(_selectedImages[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  /// Build report issue button
  Widget _buildReportIssueButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.red[50],
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Report an issue with this delivery',
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(Icons.arrow_forward, color: Colors.red[700], size: 20),
        ],
      ),
    );
  }

  /// Build submit button
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitFeedback,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Submit Feedback',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  /// Build skip button
  Widget _buildSkipButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(false),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text('Skip for now'),
      ),
    );
  }

  /// Build success screen
  Widget _buildSuccessScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green[700],
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Thank You!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your feedback helps us improve',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'Done',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomStarRating extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onRatingChanged;
  final double size;
  final Color color;
  final Color borderColor;
  final double spacing;

  const CustomStarRating({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.size = 40.0,
    this.color = Colors.amber,
    this.borderColor = Colors.grey,
    this.spacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        final isFilled = rating >= starIndex;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: GestureDetector(
            onTap: () => onRatingChanged(starIndex.toDouble()),
            child: Icon(
              isFilled ? Icons.star : Icons.star_border,
              size: size,
              color: isFilled ? color : borderColor,
            ),
          ),
        );
      }),
    );
  }
}
