# Review System - Developer Guide

## Quick Start

### 1. Display Reviews on Product Detail Screen

```dart
import 'package:provider/provider.dart';
import 'lib/widgets/review_section.dart';
import 'lib/providers/review_provider.dart';

// In ProductDetailScreen
@override
Widget build(BuildContext context) {
  return ChangeNotifierProvider(
    create: (_) => ReviewProvider(),
    child: Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ... other product details ...
            ReviewSection(
              productId: widget.productId,
              productName: product.name,
            ),
          ],
        ),
      ),
    ),
  );
}
```

### 2. Show Rating Prompt After Delivery

```dart
import 'lib/services/rating_prompt_service.dart';
import 'lib/screens/customer/add_review_screen.dart';

final ratingPromptService = RatingPromptService();

// In OrderDetailScreen or after delivery
if (order.status == OrderStatus.delivered) {
  final isEligible = await ratingPromptService.isEligibleForRating(order);
  
  if (isEligible && !await ratingPromptService.hasRatingPromptBeenShown(order.id)) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate Your Order'),
        content: const Text('How was your experience?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              final unreviewed = await ratingPromptService.getUnreviewedProducts(order);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddReviewScreen(
                    productId: unreviewed.first.productId,
                    orderId: order.id,
                    productName: unreviewed.first.productName,
                  ),
                ),
              );
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
    
    await ratingPromptService.markRatingPromptShown(order.id);
  }
}
```

### 3. Submit a Review

```dart
import 'lib/providers/review_provider.dart';
import 'lib/models/product_review_model.dart';

final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);

final review = ProductReviewModel(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  productId: 'product_123',
  userId: currentUser.id,
  userName: currentUser.name,
  userImage: currentUser.profileImage,
  rating: 4.5,
  comment: 'Great product!',
  mediaUrls: ['https://...image1.jpg', 'https://...image2.jpg'],
  createdAt: DateTime.now(),
  orderId: 'order_123',
  isVerifiedPurchase: true,
);

await reviewProvider.submitReview(review);
```

### 4. Add Shop Owner Response

```dart
import 'lib/providers/review_provider.dart';

final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);

await reviewProvider.addOwnerResponse(
  productId: 'product_123',
  reviewId: 'review_456',
  response: 'Thank you for your feedback! We appreciate your business.',
);
```

### 5. Flag a Review

```dart
final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);

await reviewProvider.flagReview(
  productId: 'product_123',
  reviewId: 'review_456',
  reasons: ['inappropriate', 'spam'],
);
```

### 6. Get Rating Statistics

```dart
import 'lib/services/product_rating_calculator.dart';

final calculator = ProductRatingCalculator();

final averageRating = await calculator.calculateAverageRating('product_123');
final reviewCount = await calculator.getReviewCount('product_123');
final distribution = await calculator.getRatingDistribution('product_123');
final percentages = await calculator.getRatingPercentages('product_123');

print('Average: $averageRating');
print('Count: $reviewCount');
print('Distribution: $distribution');
print('Percentages: $percentages');
```

### 7. Admin Moderation

```dart
import 'lib/services/review_moderation_system.dart';

final moderationSystem = ReviewModerationSystem();

// Get flagged reviews
final flaggedReviews = await moderationSystem.getFlaggedReviews();

// Approve a review
await moderationSystem.approveReview('product_123', 'review_456');

// Hide a review
await moderationSystem.hideReview(
  'product_123',
  'review_456',
  reason: 'Violates community guidelines',
);

// Get moderation stats
final stats = await moderationSystem.getModerationStats();
print('Flagged: ${stats['flagged']}');
print('Pending: ${stats['pending']}');
print('Approved: ${stats['approved']}');

// Detect spam
final isSpamming = await moderationSystem.isUserSpamming('user_123');
```

---

## API Reference

### ReviewProvider

```dart
class ReviewProvider extends ChangeNotifier {
  // Properties
  List<ProductReviewModel> get reviews
  bool get isLoading
  String? get error
  Map<int, int> get ratingDistribution
  double get averageRating

  // Methods
  Future<void> fetchProductReviews(
    String productId, {
    int limit = 10,
    DocumentSnapshot? startAfter,
    String sortBy = 'recent',
  })
  
  Future<void> submitReview(ProductReviewModel review)
  
  Future<void> addOwnerResponse(
    String productId,
    String reviewId,
    String response,
  )
  
  Future<void> flagReview(
    String productId,
    String reviewId,
    List<String> reasons,
  )
  
  Future<void> markAsHelpful(String productId, String reviewId)
  
  Future<bool> hasUserReviewedProduct(
    String productId,
    String userId,
    String orderId,
  )
  
  Future<List<ProductReviewModel>> getFlaggedReviews()
  
  Future<void> approveReview(String productId, String reviewId)
  
  Future<void> hideReview(String productId, String reviewId)
  
  void clearReviews()
}
```

### ProductRatingCalculator

```dart
class ProductRatingCalculator {
  Future<double> calculateAverageRating(String productId)
  
  Future<int> getReviewCount(String productId)
  
  Future<void> updateProductRating(String productId)
  
  Future<Map<int, int>> getRatingDistribution(String productId)
  
  Future<Map<int, double>> getRatingPercentages(String productId)
  
  Future<List<String>> getTopRatedProducts({int limit = 10})
  
  Future<List<String>> getMostReviewedProducts({int limit = 10})
}
```

### ReviewModerationSystem

```dart
class ReviewModerationSystem {
  Future<List<Map<String, dynamic>>> getFlaggedReviews({
    int limit = 20,
    DocumentSnapshot? startAfter,
  })
  
  Future<List<Map<String, dynamic>>> getPendingReviews({int limit = 20})
  
  Future<void> approveReview(String productId, String reviewId)
  
  Future<void> hideReview(
    String productId,
    String reviewId,
    {String? reason}
  )
  
  Future<void> deleteReview(String productId, String reviewId)
  
  Future<Map<String, int>> getModerationStats()
  
  Future<Map<String, int>> getReviewsByFlagReason()
  
  Future<List<ProductReviewModel>> getReviewsByUser(String userId)
  
  Future<bool> isUserSpamming(String userId, {int reviewsInHours = 24})
  
  Future<List<Map<String, dynamic>>> getSuspiciousReviews()
}
```

### RatingPromptService

```dart
class RatingPromptService {
  Future<bool> isEligibleForRating(OrderModel order)
  
  Future<List<OrderItem>> getUnreviewedProducts(OrderModel order)
  
  Future<void> markRatingPromptShown(String orderId)
  
  Future<bool> hasRatingPromptBeenShown(String orderId)
  
  int getRemainingDaysForRating(OrderModel order)
}
```

### ProfanityFilterService

```dart
class ProfanityFilterService {
  String filter(String text)
  
  bool hasProfanity(String text)
  
  List<String> getProfanityWords(String text)
}
```

---

## Firestore Queries

### Get all reviews for a product
```dart
db.collection('products')
  .doc(productId)
  .collection('reviews')
  .where('isApproved', isEqualTo: true)
  .where('isFlagged', isEqualTo: false)
  .orderBy('createdAt', descending: true)
  .limit(10)
  .get()
```

### Get flagged reviews
```dart
db.collectionGroup('reviews')
  .where('isFlagged', isEqualTo: true)
  .orderBy('createdAt', descending: true)
  .get()
```

### Get reviews by user
```dart
db.collectionGroup('reviews')
  .where('userId', isEqualTo: userId)
  .orderBy('createdAt', descending: true)
  .get()
```

### Get reviews with owner response
```dart
db.collectionGroup('reviews')
  .where('ownerReply', isNotEqualTo: null)
  .get()
```

---

## Validation Rules

### Review Submission
- Rating: 1-5 stars (required)
- Comment: 0-500 characters (optional, min 3 if provided)
- Images: 0-3 images (optional)
- Profanity: Filtered before submission
- One review per product per order

### Rating Eligibility
- Order must be delivered
- Within 7 days of delivery
- Not already reviewed

### Moderation
- Inappropriate content flagged
- Spam detection (5+ reviews in 24 hours)
- Suspicious patterns identified
- Admin approval workflow

---

## Error Handling

```dart
try {
  await reviewProvider.submitReview(review);
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

---

## Best Practices

1. **Always use ReviewProvider** for review operations
2. **Validate input** before submission
3. **Show loading states** during async operations
4. **Handle errors gracefully** with user feedback
5. **Use pagination** for large review lists
6. **Cache rating data** to reduce Firestore reads
7. **Implement rate limiting** for review submissions
8. **Monitor moderation queue** regularly
9. **Respond to reviews** promptly as shop owner
10. **Track helpful counts** for review ranking

---

## Troubleshooting

### Reviews not showing
- Check if reviews are approved (`isApproved: true`)
- Check if reviews are not flagged (`isFlagged: false`)
- Verify Firestore security rules allow read access

### Rating not updating
- Ensure `updateProductRating()` is called after review submission
- Check Firestore indexes for review queries
- Verify product document exists

### Profanity filter not working
- Add more words to `_profanityList` in `ProfanityFilterService`
- Test with exact word matches (case-insensitive)

### Moderation not working
- Check if reviews are properly flagged
- Verify admin has permission to update reviews
- Check Firestore security rules for admin access

---

## Performance Tips

1. **Pagination**: Load 10 reviews at a time
2. **Caching**: Cache rating calculations for 1 hour
3. **Indexing**: Create Firestore indexes for common queries
4. **Lazy Loading**: Load images only when visible
5. **Batch Operations**: Use batch writes for bulk updates

---

## Security Considerations

1. **Verify Purchase**: Only allow reviews from verified purchases
2. **Rate Limiting**: Limit reviews per user per day
3. **Spam Detection**: Detect and flag spam patterns
4. **Content Moderation**: Filter inappropriate content
5. **User Verification**: Verify user identity before allowing reviews
6. **Firestore Rules**: Restrict review access appropriately

---

## Testing

Run tests with:
```bash
flutter test test/review_system_test.dart
```

Test coverage includes:
- Model serialization
- Rating calculations
- Profanity filtering
- Validation rules
- Moderation workflows
- Owner responses
- Helpful count tracking
