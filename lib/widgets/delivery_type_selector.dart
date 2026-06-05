import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/delivery_type.dart';
import '../services/delivery_charge_calculator.dart';
import '../providers/shop_config_provider.dart';
import '../utils/app_theme.dart';

/// Widget for selecting delivery type with visual cards
class DeliveryTypeSelector extends StatefulWidget {
  final DeliveryType selectedType;
  final double subtotal;
  final ValueChanged<DeliveryType> onTypeSelected;
  final bool showPrices;

  const DeliveryTypeSelector({
    super.key,
    required this.selectedType,
    required this.subtotal,
    required this.onTypeSelected,
    this.showPrices = true,
  });

  @override
  State<DeliveryTypeSelector> createState() => _DeliveryTypeSelectorState();
}

class _DeliveryTypeSelectorState extends State<DeliveryTypeSelector> {
  late DeliveryType _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.selectedType;
  }

  @override
  void didUpdateWidget(DeliveryTypeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedType != widget.selectedType) {
      _selectedType = widget.selectedType;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEmergency = false;
    try {
      final configProvider = context.watch<ShopConfigProvider>();
      isEmergency = configProvider.shopConfig?.isEmergencyMode ?? false;
    } catch (_) {}

    final filteredOptions = DeliveryTypeOption.allOptions.where((option) {
      if (isEmergency) {
        if (option.type == DeliveryType.express || option.type == DeliveryType.sameDay) {
          return false;
        }
      }
      return true;
    }).toList();

    if (isEmergency) {
      filteredOptions.sort((a, b) {
        if (a.type == DeliveryType.scheduled) return -1;
        if (b.type == DeliveryType.scheduled) return 1;
        return 0;
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.grey900,
          ),
        ),
        const SizedBox(height: 12),
        ...filteredOptions.map((option) => _buildDeliveryOption(option)),
        const SizedBox(height: 8),
        _buildFreeDeliveryHint(isEmergency: isEmergency),
      ],
    );
  }

  Widget _buildDeliveryOption(DeliveryTypeOption option) {
    final isSelected = _selectedType == option.type;
    final charge = DeliveryChargeCalculator.calculateDeliveryCharge(
      option.type,
      widget.subtotal,
    );
    final formattedDate = DeliveryChargeCalculator.getFormattedDeliveryDate(option.type);
    final icon = DeliveryTypeOption.getIcon(option.type);
    final color = DeliveryTypeOption.getColor(option.type);

    return GestureDetector(
      onTap: () {
        setState(() => _selectedType = option.type);
        widget.onTypeSelected(option.type);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppTheme.grey300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? color : AppTheme.grey600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          option.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? color : AppTheme.grey900,
                          ),
                        ),
                        if (widget.showPrices)
                          Text(
                            charge == 0 ? 'FREE' : '₹${charge.round()}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: charge == 0 ? AppTheme.success : AppTheme.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.grey600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isSelected ? color : AppTheme.grey600).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: isSelected ? color : AppTheme.grey600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? color : AppTheme.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? color : AppTheme.grey400,
                    width: 2,
                  ),
                  color: isSelected ? color : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFreeDeliveryHint({bool isEmergency = false}) {
    final threshold = isEmergency
        ? DeliveryChargeCalculator.freeDeliveryThreshold * 1.5
        : DeliveryChargeCalculator.freeDeliveryThreshold;

    if (widget.subtotal >= threshold) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.success.withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'You\'ve unlocked FREE Standard Delivery!',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.success,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final amountNeeded = threshold - widget.subtotal;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Add ₹${amountNeeded.round()} more for FREE Standard Delivery',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact delivery type selector for smaller spaces
class CompactDeliveryTypeSelector extends StatelessWidget {
  final DeliveryType selectedType;
  final double subtotal;
  final ValueChanged<DeliveryType> onTypeSelected;

  const CompactDeliveryTypeSelector({
    super.key,
    required this.selectedType,
    required this.subtotal,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    bool isEmergency = false;
    try {
      final configProvider = context.watch<ShopConfigProvider>();
      isEmergency = configProvider.shopConfig?.isEmergencyMode ?? false;
    } catch (_) {}

    final filteredOptions = DeliveryTypeOption.allOptions.where((option) {
      if (isEmergency) {
        if (option.type == DeliveryType.express || option.type == DeliveryType.sameDay) {
          return false;
        }
      }
      return true;
    }).toList();

    if (isEmergency) {
      filteredOptions.sort((a, b) {
        if (a.type == DeliveryType.scheduled) return -1;
        if (b.type == DeliveryType.scheduled) return 1;
        return 0;
      });
    }

    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filteredOptions.length,
        itemBuilder: (context, index) {
          final option = filteredOptions[index];
          final isSelected = selectedType == option.type;
          final charge = DeliveryChargeCalculator.calculateDeliveryCharge(
            option.type,
            subtotal,
          );
          final icon = DeliveryTypeOption.getIcon(option.type);
          final color = DeliveryTypeOption.getColor(option.type);

          return GestureDetector(
            onTap: () => onTypeSelected(option.type),
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.1) : AppTheme.grey100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : AppTheme.grey300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? color : AppTheme.grey600,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    charge == 0 ? 'FREE' : '₹${charge.round()}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : AppTheme.grey700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

