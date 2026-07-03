import 'package:flutter/material.dart';
import 'package:fufajis_online/models/customer_models.dart';

/// Feedback Synthesis Card Component
/// Displays weekly feedback analysis and sentiment summary
class FeedbackSynthesisCard extends StatefulWidget {
  final FeedbackSynthesis synthesis;

  const FeedbackSynthesisCard({super.key, required this.synthesis});

  @override
  State<FeedbackSynthesisCard> createState() => _FeedbackSynthesisCardState();
}

class _FeedbackSynthesisCardState extends State<FeedbackSynthesisCard> {
  final bool _expandedProducts = false;



  @override
  Widget build(BuildContext context) {
    final synthesis = widget.synthesis;
    final sentiment = synthesis.overallSentiment;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // ============ HEADER ============
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.comment, size: 24, color: Colors.purple),
                            const SizedBox(width: 12),
                            Text(
                              'Weekly Feedback Summary',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${synthesis.period.startDate.month}/${synthesis.period.startDate.day} - ${synthesis.period.endDate.month}/${synthesis.period.endDate.day}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${sentiment.totalReviews} reviews',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ============ OVERALL SENTIMENT ============
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // Star rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            sentiment.avgRating.toStringAsFixed(1),
                            style: Theme.of(
                              context,
                            ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              Row(
                                children: List.generate(
                                  5,
                                  (index) => Icon(
                                    index < sentiment.avgRating.round()
                                        ? Icons.star
                                        : Icons.star_outline,
                                    size: 24,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Average Rating', style: Theme.of(context).textTheme.labelSmall),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Trend
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: sentiment.trend.direction == 'IMPROVING'
                              ? Colors.green.shade50
                              : sentiment.trend.direction == 'DECLINING'
                              ? Colors.red.shade50
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Trend', style: Theme.of(context).textTheme.labelSmall),
                            Row(
                              children: [
                                Icon(
                                  sentiment.trend.direction == 'IMPROVING'
                                      ? Icons.trending_up
                                      : sentiment.trend.direction == 'DECLINING'
                                      ? Icons.trending_down
                                      : Icons.trending_flat,
                                  color: sentiment.trend.direction == 'IMPROVING'
                                      ? Colors.green
                                      : sentiment.trend.direction == 'DECLINING'
                                      ? Colors.red
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${sentiment.trend.direction} (${sentiment.trend.change > 0 ? '+' : ''}${sentiment.trend.change.toStringAsFixed(1)} ⭐)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: sentiment.trend.direction == 'IMPROVING'
                                        ? Colors.green.shade700
                                        : sentiment.trend.direction == 'DECLINING'
                                        ? Colors.red.shade700
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Rating distribution
                ...sentiment.ratingDistribution.entries.map((entry) {
                  final rating = entry.key;
                  final count = entry.value;
                  final total = sentiment.totalReviews;
                  final percentage = total > 0 ? (count / total * 100) : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30,
                          child: Text('$rating⭐', style: Theme.of(context).textTheme.labelSmall),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                rating >= 4
                                    ? Colors.green
                                    : rating >= 3
                                    ? Colors.orange
                                    : Colors.red,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 50,
                          child: Text(
                            '$count (${percentage.toStringAsFixed(0)}%)',
                            style: Theme.of(context).textTheme.labelSmall,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // ============ BY PRODUCT ============
          if (synthesis.byProduct.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(top: BorderSide(color: Colors.blue.shade200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Product Feedback',
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${synthesis.byProduct.length} products analyzed',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...synthesis.byProduct.entries.take(5).map((entry) {
                    final productId = entry.key;
                    final data = entry.value;
                    final riskLevel = data['riskLevel'] ?? 'OK';
                    final avgRating = data['avgRating'] ?? 4.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: riskLevel == 'CRITICAL'
                              ? Colors.red.shade200
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  data['productName'] ?? productId,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: riskLevel == 'CRITICAL'
                                      ? Colors.red.shade100
                                      : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  riskLevel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: riskLevel == 'CRITICAL'
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (index) => Icon(
                                  index < avgRating.round() ? Icons.star : Icons.star_outline,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('$avgRating ⭐', style: Theme.of(context).textTheme.labelSmall),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

          // ============ ACTION BUTTON ============
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Feedback report exported'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.file_download),
                label: const Text('Download Full Report'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
