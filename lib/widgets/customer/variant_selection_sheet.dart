import 'package:flutter/material.dart';
import 'package:fufajis_online/constants/app_colors.dart';

class VariantSelectionSheet extends StatelessWidget {
  final String productName;
  final List<String> variants;
  final Function(String) onSelectVariant;

  const VariantSelectionSheet({
    super.key,
    required this.productName,
    required this.variants,
    required this.onSelectVariant,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Variant for $productName',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...variants.map((variant) => _buildVariantTile(context, variant)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildVariantTile(BuildContext context, String variant) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () => onSelectVariant(variant),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          constraints: const BoxConstraints(minHeight: 48),
          child: Text(
            variant,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
