import 'package:flutter/material.dart';

/// Filter panel widget for owner dashboard
/// Provides date range picker, status filter, and amount range slider
class FilterPanel extends StatefulWidget {
  final Function(Map<String, dynamic>) onApplyFilters;
  final VoidCallback onClearFilters;
  final List<String> statusOptions;

  const FilterPanel({
    super.key,
    required this.onApplyFilters,
    required this.onClearFilters,
    this.statusOptions = const [
      'All',
      'Pending',
      'Confirmed',
      'Processing',
      'Packed',
      'Out for Delivery',
      'Delivered',
      'Cancelled',
    ],
  });

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late DateTimeRange _selectedDateRange;
  late String _selectedStatus;
  late RangeValues _amountRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
    _selectedStatus = 'All';
    _amountRange = const RangeValues(0, 10000);
  }

  Future<void> _selectDateRange() async {
    final newRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (newRange != null) {
      setState(() {
        _selectedDateRange = newRange;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter title
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),

            // Date range filter
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date Range',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _selectDateRange,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${_selectedDateRange.start.toString().split(' ')[0]} - ${_selectedDateRange.end.toString().split(' ')[0]}',
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status filter
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Status',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _selectedStatus,
                  isExpanded: true,
                  items: widget.statusOptions
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount range filter
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount Range',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text(
                      '₹${_amountRange.start.toInt()} - ₹${_amountRange.end.toInt()}',
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RangeSlider(
                  values: _amountRange,
                  min: 0,
                  max: 10000,
                  onChanged: (values) {
                    setState(() {
                      _amountRange = values;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      final now = DateTime.now();
                      _selectedDateRange = DateTimeRange(
                        start: now.subtract(const Duration(days: 30)),
                        end: now,
                      );
                      _selectedStatus = 'All';
                      _amountRange = const RangeValues(0, 10000);
                    });
                    widget.onClearFilters();
                  },
                  child: const Text('Clear Filters'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onApplyFilters({
                      'dateRangeStart': _selectedDateRange.start,
                      'dateRangeEnd': _selectedDateRange.end,
                      'status': _selectedStatus,
                      'amountMin': _amountRange.start,
                      'amountMax': _amountRange.end,
                    });
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Apply Filters'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet filter dialog
class FilterBottomSheet extends StatelessWidget {
  final Function(Map<String, dynamic>) onApplyFilters;
  final VoidCallback onClearFilters;

  const FilterBottomSheet({
    super.key,
    required this.onApplyFilters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 24,
      ),
      child: SingleChildScrollView(
        child: FilterPanel(
          onApplyFilters: onApplyFilters,
          onClearFilters: onClearFilters,
        ),
      ),
    );
  }
}

/// Show filter bottom sheet
void showFilterBottomSheet(
  BuildContext context, {
  required Function(Map<String, dynamic>) onApplyFilters,
  required VoidCallback onClearFilters,
}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => FilterBottomSheet(
      onApplyFilters: onApplyFilters,
      onClearFilters: onClearFilters,
    ),
  );
}
