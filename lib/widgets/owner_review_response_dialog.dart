import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/review_provider.dart';
import '../models/product_review_model.dart';
import '../utils/app_theme.dart';

class OwnerReviewResponseDialog extends StatefulWidget {
  final String productId;
  final ProductReviewModel review;

  const OwnerReviewResponseDialog({super.key, required this.productId, required this.review});

  @override
  State<OwnerReviewResponseDialog> createState() => _OwnerReviewResponseDialogState();
}

class _OwnerReviewResponseDialogState extends State<OwnerReviewResponseDialog> {
  late TextEditingController _responseController;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _responseController = TextEditingController(text: widget.review.ownerReply ?? '');
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _submitResponse() async {
    final response = _responseController.text.trim();

    if (response.isEmpty) {
      setState(() => _error = 'Response cannot be empty');
      return;
    }

    if (response.length < 10) {
      setState(() => _error = 'Response must be at least 10 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);
      await reviewProvider.addOwnerResponse(widget.productId, widget.review.id, response);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Response added successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = 'Failed to add response: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Respond to Review',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Original review preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: widget.review.userImage != null
                              ? NetworkImage(widget.review.userImage!)
                              : null,
                          child: widget.review.userImage == null
                              ? const Icon(Icons.person, size: 16)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.review.userName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Row(
                                children: [
                                  ..._buildStars(widget.review.rating),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDate(widget.review.createdAt),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.review.comment,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Response input
              Text(
                'Your Response',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _responseController,
                maxLines: 4,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'Thank you for your feedback...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Minimum 10 characters',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),

              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    border: Border.all(color: AppTheme.error),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 12)),
                ),
                const SizedBox(height: 16),
              ],

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitResponse,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Post Response'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStars(double rating) {
    List<Widget> stars = [];
    for (int i = 1; i <= 5; i++) {
      if (i <= rating) {
        stars.add(const Icon(Icons.star, color: AppTheme.primary, size: 14));
      } else if (i - rating < 1) {
        stars.add(const Icon(Icons.star_half, color: AppTheme.primary, size: 14));
      } else {
        stars.add(Icon(Icons.star_outline, color: Colors.grey[400], size: 14));
      }
    }
    return stars;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}m ago';
    }
  }
}
