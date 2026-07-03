import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';

// ─────────────── DATA CLASS ───────────────

class BillItem {
  String name;
  double quantity;
  String unit;
  double pricePerUnit;

  BillItem({this.name = '', this.quantity = 0, this.unit = 'kg', this.pricePerUnit = 0});

  double get total => quantity * pricePerUnit;

  Map<String, dynamic> toMap() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'pricePerUnit': pricePerUnit,
    'total': total,
  };

  factory BillItem.fromMap(Map<String, dynamic> map) => BillItem(
    name: map['name']?.toString() ?? '',
    quantity: ((map['quantity'] ?? map['qty'] ?? 0) as num).toDouble(),
    unit: map['unit']?.toString() ?? 'kg',
    pricePerUnit: ((map['pricePerUnit'] ?? map['price'] ?? 0) as num).toDouble(),
  );
}

// ─────────────── WIDGET ───────────────

class BillItemRow extends StatefulWidget {
  final BillItem item;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const BillItemRow({
    super.key,
    required this.item,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<BillItemRow> createState() => _BillItemRowState();
}

class _BillItemRowState extends State<BillItemRow> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  static const List<String> _units = [
    'kg',
    'g',
    'l',
    'ml',
    'packet',
    'piece',
    'bottle',
    'box',
    'dozen',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _qtyCtrl = TextEditingController(
      text: widget.item.quantity == 0 ? '' : widget.item.quantity.toString(),
    );
    _priceCtrl = TextEditingController(
      text: widget.item.pricePerUnit == 0 ? '' : widget.item.pricePerUnit.toString(),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    widget.item.name = _nameCtrl.text;
    widget.item.quantity = double.tryParse(_qtyCtrl.text) ?? 0;
    widget.item.pricePerUnit = double.tryParse(_priceCtrl.text) ?? 0;
    widget.onChanged();
    setState(() {}); // refresh total
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.grey200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // Row 1: Name + Delete
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    controller: _nameCtrl,
                    hint: 'Product name',
                    inputType: TextInputType.text,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: widget.onDelete,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: Qty | Unit | Price | Total
            Row(
              children: [
                // Qty
                Expanded(
                  flex: 2,
                  child: _buildField(
                    controller: _qtyCtrl,
                    hint: 'Qty',
                    inputType: const TextInputType.numberWithOptions(decimal: true),
                    formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  ),
                ),
                const SizedBox(width: 6),
                // Unit dropdown
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.grey300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _units.contains(widget.item.unit) ? widget.item.unit : 'kg',
                        isExpanded: true,
                        style: const TextStyle(fontSize: 12, color: AppTheme.grey900),
                        items: _units
                            .map(
                              (u) => DropdownMenuItem(
                                value: u,
                                child: Text(u, style: const TextStyle(fontSize: 12)),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => widget.item.unit = val);
                            widget.onChanged();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Price
                Expanded(
                  flex: 2,
                  child: _buildField(
                    controller: _priceCtrl,
                    hint: '₹/unit',
                    inputType: const TextInputType.numberWithOptions(decimal: true),
                    formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  ),
                ),
                const SizedBox(width: 6),
                // Total (read-only)
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.grey100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '₹${widget.item.total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required TextInputType inputType,
    List<TextInputFormatter>? formatters,
  }) {
    return SizedBox(
      height: 40,
      child: TextFormField(
        controller: controller,
        keyboardType: inputType,
        inputFormatters: formatters,
        style: const TextStyle(fontSize: 12, color: AppTheme.grey900),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 11, color: AppTheme.grey400),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.grey300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.grey300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primary),
          ),
        ),
        onChanged: (_) => _onFieldChanged(),
      ),
    );
  }
}
