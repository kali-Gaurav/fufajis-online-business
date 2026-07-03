import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/review_provider.dart';
import '../models/product_review_model.dart';
import '../utils/app_theme.dart';

import 'package:video_player/video_player.dart';

class ReviewSection extends StatefulWidget {
  final String productId;
  final String productName;

  const ReviewSection({super.key, required this.productId, required this.productName});

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  String _sortBy = 'recent';
  int _currentPage = 0;
  final int _reviewsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  void _loadReviews() {
    final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);
    reviewProvider.fetchProductReviews(widget.productId, limit: _reviewsPerPage, sortBy: _sortBy);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReviewProvider>(
      builder: (context, reviewProvider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rating Summary
            _buildRatingSummary(reviewProvider),
            const SizedBox(height: 24),

            // Sort Options
            _buildSortOptions(reviewProvider),
            const SizedBox(height: 16),

            // Reviews List
            if (reviewProvider.isLoading)
              const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            else if (reviewProvider.reviews.isEmpty)
              _buildEmptyState()
            else
              _buildReviewsList(reviewProvider),
          ],
        );
      },
    );
  }

  Widget _buildRatingSummary(ReviewProvider reviewProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reviewProvider.averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  Row(
                    children: [
                      ..._buildStars(reviewProvider.averageRating),
                      const SizedBox(width: 8),
                      Text(
                        '${reviewProvider.reviews.length} reviews',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              _buildRatingDistribution(reviewProvider),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStars(double rating) {
    List<Widget> stars = [];
    for (int i = 1; i <= 5; i++) {
      if (i <= rating) {
        stars.add(const Icon(Icons.star, color: AppTheme.primary, size: 16));
      } else if (i - rating < 1) {
        stars.add(const Icon(Icons.star_half, color: AppTheme.primary, size: 16));
      } else {
        stars.add(Icon(Icons.star_outline, color: Colors.grey[400], size: 16));
      }
    }
    return stars;
  }

  Widget _buildRatingDistribution(ReviewProvider reviewProvider) {
    return Column(
      children: [5, 4, 3, 2, 1].map((rating) {
        final count = reviewProvider.ratingDistribution[rating] ?? 0;
        final total = reviewProvider.reviews.length;
        final percentage = total == 0 ? 0 : (count / total) * 100;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$ratingâ˜…', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(_getRatingColor(rating)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$count', style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getRatingColor(int rating) {
    if (rating >= 4) return AppTheme.success;
    if (rating == 3) return AppTheme.warning;
    return AppTheme.error;
  }

  Widget _buildSortOptions(ReviewProvider reviewProvider) {
    return Row(
      children: [
        const Text('Sort by:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSortChip('Recent', 'recent', reviewProvider),
                const SizedBox(width: 8),
                _buildSortChip('Highest', 'highest', reviewProvider),
                const SizedBox(width: 8),
                _buildSortChip('Lowest', 'lowest', reviewProvider),
                const SizedBox(width: 8),
                _buildSortChip('Helpful', 'helpful', reviewProvider),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSortChip(String label, String value, ReviewProvider reviewProvider) {
    final isSelected = _sortBy == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _sortBy = value);
        reviewProvider.fetchProductReviews(widget.productId, limit: _reviewsPerPage, sortBy: value);
      },
      backgroundColor: AppTheme.cream,
      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(color: isSelected ? AppTheme.primary : Colors.grey[300]!),
    );
  }

  Widget _buildReviewsList(ReviewProvider reviewProvider) {
    return Column(
      children: [
        ...reviewProvider.reviews.map((review) {
          return _buildReviewCard(review, reviewProvider);
        }),
        if (reviewProvider.reviews.length >= _reviewsPerPage)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ElevatedButton(
              onPressed: () {
                setState(() => _currentPage++);
                // Load more reviews
              },
              child: const Text('Load More Reviews'),
            ),
          ),
      ],
    );
  }

  Widget _buildReviewCard(ProductReviewModel review, ReviewProvider reviewProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user info and rating
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User avatar
                CircleAvatar(
                  radius: 20,
                  backgroundImage: review.userImage != null
                      ? NetworkImage(review.userImage!)
                      : null,
                  child: review.userImage == null ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              review.userName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (review.isVerifiedPurchase)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.success,
                                border: Border.all(color: AppTheme.success),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ..._buildStars(review.rating),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(review.createdAt),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Review text
            Text(
              review.comment,
              style: const TextStyle(fontSize: 13),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),

            // Review media (Step 14.1, 14.2)
            if (review.mediaUrls.isNotEmpty || review.videoUrl != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.mediaUrls.length + (review.videoUrl != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (review.videoUrl != null && index == 0) {
                      return _buildVideoThumbnail(context, review.videoUrl!);
                    }
                    final imgIndex = review.videoUrl != null ? index - 1 : index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          review.mediaUrls[imgIndex],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Owner reply
            if (review.ownerReply != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.info,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.info),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shop Owner Response',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppTheme.info,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(review.ownerReply!, style: const TextStyle(fontSize: 12)),
                    if (review.ownerReplyDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(review.ownerReplyDate!),
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Helpful button
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    reviewProvider.markAsHelpful(widget.productId, review.id);
                  },
                  icon: const Icon(Icons.thumb_up_outlined, size: 16),
                  label: Text('Helpful (${review.helpfulCount})'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    _showFlagDialog(context, review, reviewProvider);
                  },
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: const Text('Report'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFlagDialog(
    BuildContext context,
    ProductReviewModel review,
    ReviewProvider reviewProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        List<String> selectedReasons = [];
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Report Review'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('Inappropriate content'),
                    value: selectedReasons.contains('inappropriate'),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedReasons.add('inappropriate');
                        } else {
                          selectedReasons.remove('inappropriate');
                        }
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Spam'),
                    value: selectedReasons.contains('spam'),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedReasons.add('spam');
                        } else {
                          selectedReasons.remove('spam');
                        }
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Offensive language'),
                    value: selectedReasons.contains('offensive'),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedReasons.add('offensive');
                        } else {
                          selectedReasons.remove('offensive');
                        }
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Fake review'),
                    value: selectedReasons.contains('fake'),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedReasons.add('fake');
                        } else {
                          selectedReasons.remove('fake');
                        }
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: selectedReasons.isEmpty
                      ? null
                      : () {
                          reviewProvider.flagReview(widget.productId, review.id, selectedReasons);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Review reported successfully')),
                          );
                        },
                  child: const Text('Report'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to review this product',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return '${(difference.inDays / 365).floor()} years ago';
    }
  }

  Widget _buildVideoThumbnail(BuildContext context, String videoUrl) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          _showVideoPlayer(context, videoUrl);
        },
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
              Positioned(
                bottom: 4,
                right: 4,
                child: Text(
                  'VIDEO',
                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVideoPlayer(BuildContext context, String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => VideoPlayerDialog(videoUrl: videoUrl),
    );
  }
}

class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerDialog({super.key, required this.videoUrl});

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() => _initialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_initialized)
            AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller))
          else
            const CircularProgressIndicator(color: AppTheme.primary),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (_initialized)
            Positioned(
              bottom: 20,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.white24,
                onPressed: () {
                  setState(() {
                    _controller.value.isPlaying ? _controller.pause() : _controller.play();
                  });
                },
                child: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
