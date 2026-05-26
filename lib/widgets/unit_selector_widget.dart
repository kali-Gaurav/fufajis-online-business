import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';

class UnitSelectorWidget extends StatelessWidget {
  final List<ProductUnitOption> options;
  final ProductUnitOption? selectedOption;
  final Function(ProductUnitOption) onSelected;

  const UnitSelectorWidget({
    super.key,
    required this.options,
    required this.selectedOption,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Size/Unit', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: options.map((option) {
            final isSelected = selectedOption?.id == option.id;
            return ChoiceChip(
              label: Text(option.name),
              selected: isSelected,
              onSelected: (_) => onSelected(option),
              selectedColor: AppTheme.primary.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primary : AppTheme.grey800,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

