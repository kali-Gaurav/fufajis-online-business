import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../models/product_review_model.dart';
import '../../utils/app_theme.dart';

class PostDeliveryReviewModal extends StatefulWidget {
  final String orderId;
  final List<ProductModel> products;
  final Function(List<ProductReviewModel>) onSubmit;

  const PostDeliveryReviewModal({
    super.key,
    required this.orderId,
    required this.products,
    required this.onSubmit,
  });

  @override
  State<PostDeliveryReviewModal> createState() => _PostDeliveryReviewModalState();
}

class _PostDeliveryReviewModalState extends State<PostDeliveryReviewModal> {
  late bool _rateAllTogether;
  late Map<String, int> _productRatings;
  late Map<String, String> _productFeedback;
  late int _overallRating;
  late String _overallFeedback;

  @override
  void initState() {
    super.initState();
    _rateAllTogether = true;
    _overallRating = 0;
    _overallFeedback = '';
    _productRatings = {};
    _productFeedback = {};

    for (var product in widget.products) {
      _productRatings[product.id] = 0;
      _productFeedback[product.id] = '';
    }
  }

  void _submitReview() {
    List<ProductReviewModel> reviews = [];

    if (_rateAllTogether) {
      if (_overallRating == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a rating'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }

      for (var product in widget.products) {
        reviews.add(
          ProductReviewModel(
            id: 'review_${DateTime.now().millisecondsSinceEpoch}',
            orderId: widget.orderId,
            productId: product.id,
            customerId: 'current_customer', // Will be replaced with actual customer ID
            orderItemId: 'order_item_${product.id}',
            rating: _overallRating,
            reviewText: _overallFeedback.isEmpty ? null : _overallFeedback,
            tags: [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }
    } else {
      for (var product in widget.products) {
        int rating = _productRatings[product.id] ?? 0;
        if (rating == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please rate ${product.name}'),
              backgroundColor: AppTheme.error,
            ),
          );
          return;
        }

        reviews.add(
          ProductReviewModel(
            id: 'review_${DateTime.now().millisecondsSinceEpoch}',
            orderId: widget.orderId,
            productId: product.id,
            customerId: 'current_customer',
            orderItemId: 'order_item_${product.id}',
            rating: rating,
            reviewText: (_productFeedback[product.id] ?? '').isEmpty
                ? null
                : _productFeedback[product.id],
            tags: [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }
    }

    widget.onSubmit(reviews);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'How was your experience?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Order #${widget.orderId}\n${widget.products.length} items in order',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.grey600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildReviewModeSelector(),
              const SizedBox(height: 24),
              if (_rateAllTogether)
                _buildRateAllTogether()
              else
                _buildRateIndividually(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                      child: const Text(
                        'Submit Feedback',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How do you want to review?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.grey900,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _rateAllTogether = true),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _rateAllTogether
                        ? AppTheme.primary.withOpacity(0.1)
                        : AppTheme.grey100,
                    border: Border.all(
                      color: _rateAllTogether
                          ? AppTheme.primary
                          : AppTheme.grey200,
                      width: _rateAllTogether ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.star, color: AppTheme.primary),
                      const SizedBox(height: 6),
                      const Text(
                        'Rate All Together',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'One rating for all',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _rateAllTogether = false),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: !_rateAllTogether
                        ? AppTheme.primary.withOpacity(0.1)
                        : AppTheme.grey100,
                    border: Border.all(
                      color: !_rateAllTogether
                          ? AppTheme.primary
                          : AppTheme.grey200,
                      width: !_rateAllTogether ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.assessment, color: AppTheme.primary),
                      const SizedBox(height: 6),
                      const Text(
                        'Rate Individually',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Each product',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRateAllTogether() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your rating:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.grey900,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () => setState(() => _overallRating = index + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.star,
                  size: 36,
                  color: _overallRating > index
                      ? AppTheme.primary
                      : AppTheme.grey300,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        const Text(
          'Feedback (optional)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.grey900,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          maxLines: 4,
          maxLength: 500,
          onChanged: (value) => _overallFeedback = value,
          decoration: InputDecoration(
            hintText: 'Share your thoughts...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            counterText: '${_overallFeedback.length}/500',
          ),
        ),
      ],
    );
  }

  Widget _buildRateIndividually() {
    return Column(
      children: List.generate(widget.products.length, (index) {
        final product = widget.products[index];
        final rating = _productRatings[product.id] ?? 0;
        final feedback = _productFeedback[product.id] ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.grey200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 50,
                        height: 50,
                        color: AppTheme.grey200,
                        child: product.imageUrl.isNotEmpty
                            ? Image.network(
                                product.imageUrl,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.inventory_2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Product ID: #${product.id.substring(0, 8)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.grey600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Rating:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey900,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (starIndex) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _productRatings[product.id] = starIndex + 1;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.star,
                          size: 24,
                          color: rating > starIndex
                              ? AppTheme.primary
                              : AppTheme.grey300,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Feedback (optional):',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.grey600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  maxLines: 2,
                  maxLength: 500,
                  onChanged: (value) {
                    setState(() {
                      _productFeedback[product.id] = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Your feedback...',
                    hintStyle: const TextStyle(fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    counterText:
                        '${feedback.length}/500',
                    contentPadding: const EdgeInsets.all(8),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
