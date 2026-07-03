import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/hybrid_substitute_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/monetary_value.dart';

/// Feature 5 — Missing Item Protection: Customer Choice Screen
///
/// When an ordered item is out of stock, this screen gives the customer
/// Three explicit choices:
///   1. Refund to original payment method
///   2. Wallet Credit (instant, higher perceived value)
///   3. Accept a suggested Replacement product
///
/// Customer preference for future orders is saved in Firestore.
class MissingItemChoiceScreen extends StatefulWidget {
  final String orderId;
  final OrderItem missingItem;
  final ProductModel? suggestedReplacement;

  const MissingItemChoiceScreen({
    super.key,
    required this.orderId,
    required this.missingItem,
    this.suggestedReplacement,
  });

  @override
  State<MissingItemChoiceScreen> createState() => _MissingItemChoiceScreenState();
}

class _MissingItemChoiceScreenState extends State<MissingItemChoiceScreen> {
  MissingItemChoice? _selectedChoice;
  bool _savePreference = false;
  bool _isSubmitting = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  MonetaryValue get _itemValue => widget.missingItem.totalPrice;
  bool get _hasReplacement => widget.suggestedReplacement != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text('Item Unavailable', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMissingItemCard(),
              const SizedBox(height: 24),
              _buildChoiceSection(),
              const SizedBox(height: 24),
              if (_selectedChoice != null) _buildPreferenceToggle(),
              const SizedBox(height: 32),
              _buildConfirmButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────── MISSING ITEM CARD ───────────────

  Widget _buildMissingItemCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 14, color: AppTheme.warning),
                    SizedBox(width: 4),
                    Text(
                      'Out of Stock',
                      style: TextStyle(
                        color: AppTheme.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '₹${_itemValue.round()}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.missingItem.productName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.missingItem.quantity} × ₹${widget.missingItem.price.round()}',
            style: const TextStyle(color: AppTheme.grey600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: AppTheme.info),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You are fully protected. Choose how you\'d like to proceed.',
                    style: TextStyle(color: AppTheme.info, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── CHOICES ───────────────

  Widget _buildChoiceSection() {
    return RadioGroup<MissingItemChoice>(
      groupValue: _selectedChoice,
      onChanged: (v) => setState(() => _selectedChoice = v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What would you like to do?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.grey900),
          ),
          const SizedBox(height: 14),
          _buildChoiceCard(
            choice: MissingItemChoice.walletCredit,
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFF2E7D32),
            title: 'Wallet Credit',
            subtitle: '₹${_itemValue.round()} added to your Fufaji Wallet instantly',
            badge: 'Recommended',
            badgeColor: const Color(0xFF2E7D32),
          ),
          const SizedBox(height: 10),
          _buildChoiceCard(
            choice: MissingItemChoice.refund,
            icon: Icons.currency_rupee,
            color: AppTheme.ownerAccent,
            title: 'Refund',
            subtitle: '₹${_itemValue.round()} refunded to your original payment method (2–5 days)',
          ),
          if (_hasReplacement) ...[const SizedBox(height: 10), _buildReplacementCard()],
        ],
      ),
    );
  }

  Widget _buildChoiceCard({
    required MissingItemChoice choice,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
  }) {
    final isSelected = _selectedChoice == choice;
    return GestureDetector(
      onTap: () => setState(() => _selectedChoice = choice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isSelected ? color : AppTheme.grey900,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor ?? color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: AppTheme.grey500, fontSize: 12)),
                ],
              ),
            ),
            Radio<MissingItemChoice>(value: choice, activeColor: color),
          ],
        ),
      ),
    );
  }

  Widget _buildReplacementCard() {
    final replacement = widget.suggestedReplacement!;
    final isSelected = _selectedChoice == MissingItemChoice.replacement;
    return GestureDetector(
      onTap: () => setState(() => _selectedChoice = MissingItemChoice.replacement),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.purple : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.swap_horiz, color: Colors.purple, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Accept Replacement',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.arrow_forward, size: 12, color: Colors.purple),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${replacement.name} (₹${replacement.price.round()} / ${replacement.unit})',
                          style: const TextStyle(
                            color: Colors.purple,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    replacement.price > _itemValue
                        ? 'You pay ₹${(replacement.price - _itemValue).round()} extra'
                        : replacement.price < _itemValue
                        ? 'You save ₹${(_itemValue - replacement.price).round()}'
                        : 'Same price — no change',
                    style: TextStyle(
                      color: replacement.price > _itemValue ? AppTheme.warning : AppTheme.success,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Radio<MissingItemChoice>(
              value: MissingItemChoice.replacement,
              activeColor: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── PREFERENCE TOGGLE ───────────────

  Widget _buildPreferenceToggle() {
    return Row(
      children: [
        Checkbox(
          value: _savePreference,
          onChanged: (v) => setState(() => _savePreference = v ?? false),
          activeColor: AppTheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        const Expanded(
          child: Text(
            'Remember my preference for future orders',
            style: TextStyle(color: AppTheme.grey700, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // ─────────────── CONFIRM BUTTON ───────────────

  Widget _buildConfirmButton() {
    final canConfirm = _selectedChoice != null && !_isSubmitting;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: canConfirm ? _submitChoice : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: canConfirm ? 2 : 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'Confirm Choice',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  // ─────────────── SUBMIT ───────────────

  Future<void> _submitChoice() async {
    if (_selectedChoice == null) return;
    setState(() => _isSubmitting = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?.uid ?? '';

      // 1. Record choice on the order item
      await _firestore.collection('orders').doc(widget.orderId).update({
        'missingItemResolution': {
          'itemId': widget.missingItem.id,
          'productId': widget.missingItem.productId,
          'productName': widget.missingItem.productName,
          'choice': _selectedChoice!.name,
          'resolvedAt': FieldValue.serverTimestamp(),
          'replacementProductId': _selectedChoice == MissingItemChoice.replacement
              ? widget.suggestedReplacement?.id
              : null,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. If wallet credit: apply immediately
      if (_selectedChoice == MissingItemChoice.walletCredit && userId.isNotEmpty) {
        await WalletService().addToWallet(
          userId: userId,
          amount: _itemValue.toDouble(),
          transactionType: WalletTransactionType.refund,
          orderReference: widget.orderId,
          description: 'Wallet Credit: ${widget.missingItem.productName} unavailable',
          transactionId:
              'walletcredit_${widget.missingItem.id}_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      // 3. If replacement: wire to HybridSubstituteService
      if (_selectedChoice == MissingItemChoice.replacement && widget.suggestedReplacement != null) {
        await HybridSubstituteService().resolveSubstitution(
          orderId: widget.orderId,
          itemId: widget.missingItem.id,
          approved: true,
        );
      }

      // 4. Save preference for future orders
      if (_savePreference && userId.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update({
          'defaultMissingItemChoice': _selectedChoice!.name,
        });
      }

      if (mounted) {
        _showSuccessAndClose();
      }
    } catch (e) {
      debugPrint('[MissingItemChoice] Submit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessAndClose() {
    final message = switch (_selectedChoice!) {
      MissingItemChoice.walletCredit => '✅ ₹${_itemValue.round()} added to your Fufaji Wallet!',
      MissingItemChoice.refund => '✅ Refund of ₹${_itemValue.round()} initiated (2–5 days)',
      MissingItemChoice.replacement =>
        '✅ Replacement confirmed: ${widget.suggestedReplacement?.name}',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 3),
      ),
    );

    Navigator.of(context).pop(true);
  }
}

enum MissingItemChoice { walletCredit, refund, replacement }
