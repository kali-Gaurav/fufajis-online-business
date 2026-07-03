import 'package:flutter/material.dart';
import 'package:fufajis_online/models/pricing_models.dart';
import 'package:fufajis_online/widgets/mission_control/price_diff_preview.dart';

/// Pricing Recommendation Card
/// Displays a single pricing recommendation with diff preview and approval controls
class PricingRecommendationCard extends StatefulWidget {
  final PricingRecommendation recommendation;
  final VoidCallback onApprove;
  final Function(double) onApproveWithEdit;
  final VoidCallback onReject;

  const PricingRecommendationCard({
    super.key,
    required this.recommendation,
    required this.onApprove,
    required this.onApproveWithEdit,
    required this.onReject,
  });

  @override
  State<PricingRecommendationCard> createState() => _PricingRecommendationCardState();
}

class _PricingRecommendationCardState extends State<PricingRecommendationCard> {
  final bool _isExpanded = false;
  bool _showEditMode = false;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.recommendation.recommendations.dynamicPrice.suggestedPrice.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _handleEditPrice() {
    setState(() => _showEditMode = !_showEditMode);
  }

  void _handleConfirmEdit() {
    final price = double.tryParse(_priceController.text);
    if (price != null && price > 0) {
      widget.onApproveWithEdit(price);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.recommendation.recommendations;
    final dynamicPrice = rec.dynamicPrice;
    final margin = rec.marginAnalysis;
    final bundle = rec.bundleOpportunity;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // ============ HEADER ============
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_offer, size: 20, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pricing Recommendation',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${widget.recommendation.productId}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(dynamicPrice.confidence * 100).toStringAsFixed(0)}% confident',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ============ MAIN RECOMMENDATION ============
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Price Diff
                PriceDiffPreview(
                  currentPrice: dynamicPrice.currentPrice,
                  suggestedPrice: dynamicPrice.suggestedPrice,
                  changePercent: dynamicPrice.priceChangePercent,
                ),

                const SizedBox(height: 16),

                // Reason
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why this price?',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(dynamicPrice.reason, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Triggers
                if (dynamicPrice.triggers.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: dynamicPrice.triggers
                        .map(
                          (trigger) => Chip(
                            label: Text(trigger, style: const TextStyle(fontSize: 11)),
                            backgroundColor: Colors.blue.shade100,
                            labelStyle: const TextStyle(color: Colors.blue),
                          ),
                        )
                        .toList(),
                  ),

                const SizedBox(height: 16),

                // Estimated impact
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Est. Revenue Lift', style: Theme.of(context).textTheme.labelSmall),
                      Text(
                        '₹${dynamicPrice.estimatedRevenueLift.toStringAsFixed(0)}/month',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ============ MARGIN ANALYSIS ============
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border(top: BorderSide(color: Colors.orange.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Margin Impact',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: margin.warningFlag ? Colors.red.shade100 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        margin.marginalCategory,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: margin.warningFlag ? Colors.red.shade700 : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Margin', style: Theme.of(context).textTheme.labelSmall),
                        Text(
                          '${margin.currentMarginPercent.toStringAsFixed(1)}%',
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_forward, color: Colors.grey.shade400),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Projected Margin', style: Theme.of(context).textTheme.labelSmall),
                        Text(
                          '${margin.projectedMarginPercent.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ============ BUNDLE OPPORTUNITY (if present) ============
          if (bundle != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                border: Border(top: BorderSide(color: Colors.purple.shade200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_cart, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text(
                        bundle.bundleName,
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(bundle.description, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Discount', style: Theme.of(context).textTheme.labelSmall),
                          Text(
                            '₹${bundle.bundleDiscount.toStringAsFixed(0)} (${bundle.discountPercent.toStringAsFixed(1)}%)',
                            style: Theme.of(
                              context,
                            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Est. Lift', style: Theme.of(context).textTheme.labelSmall),
                          Text(
                            bundle.estimatedLift.adoptionRate,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ============ ACTION BUTTONS ============
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Edit mode
                if (_showEditMode)
                  Column(
                    children: [
                      TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Enter price',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _handleEditPrice,
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _handleConfirmEdit,
                              child: const Text('Confirm Edit & Approve'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                // Main action buttons
                if (!_showEditMode)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onReject,
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text('Reject', style: TextStyle(color: Colors.red)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleEditPrice,
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          label: const Text('Edit Price', style: TextStyle(color: Colors.orange)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.onApprove,
                          icon: const Icon(Icons.check_circle, color: Colors.white),
                          label: const Text('Approve', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
