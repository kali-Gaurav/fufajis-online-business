import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/cart_item.dart';

class CartNotesWidget extends StatefulWidget {
  final CartItem item;
  const CartNotesWidget({super.key, required this.item});

  @override
  State<CartNotesWidget> createState() => _CartNotesWidgetState();
}

class _CartNotesWidgetState extends State<CartNotesWidget> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.item.itemNotes ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Add instructions (e.g. green bananas)',
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onChanged: (value) {
          final cart = Provider.of<CartProvider>(context, listen: false);
          cart.updateItemNotes(widget.item.id, value);
        },
      ),
    );
  }
}
