import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../utils/app_theme.dart';

class FarmMapWidget extends StatelessWidget {
  final ProductModel product;

  const FarmMapWidget({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    if (product.sourceName == null || product.sourceName!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.eco_outlined,
                color: AppTheme.secondary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Farm to Fork',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Sourced directly from ${product.sourceName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Simulation of a map view
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: const DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=600',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.location_on,
                    color: AppTheme.error,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
          if (product.farmStory != null) ...[
            const SizedBox(height: 12),
            Text(
              product.farmStory!,
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppTheme.grey800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
