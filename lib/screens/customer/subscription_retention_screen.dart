import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/subscription_service.dart';
import '../../utils/app_theme.dart';

class SubscriptionRetentionScreen extends StatefulWidget {
  final Subscription? subscription;

  const SubscriptionRetentionScreen({Key? key, this.subscription}) : super(key: key);

  @override
  State<SubscriptionRetentionScreen> createState() =>
      _SubscriptionRetentionScreenState();
}

class _SubscriptionRetentionScreenState extends State<SubscriptionRetentionScreen> {
  final _subscriptionService = SubscriptionService();
  final _supabase = Supabase.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Special Offers'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 24),
            _buildActiveOffersSection(),
            const SizedBox(height: 24),
            _buildExpiredOffersSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'We Value Your Loyalty!',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: 8),
        const Text(
          'Here are exclusive offers to help you continue enjoying our service',
          style: TextStyle(color: AppTheme.grey600, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildActiveOffersSection() {
    final userId = _supabase.client.auth.currentUser?.id ?? '';

    return FutureBuilder<List<RetentionOffer>>(
      future: _loadActiveOffers(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final offers = snapshot.data ?? [];
        if (offers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.grey200),
            ),
            child: Column(
              children: [
                Icon(Icons.card_giftcard, size: 48, color: Colors.amber),
                const SizedBox(height: 12),
                const Text(
                  'No Active Offers',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check back soon for exclusive deals!',
                  style: TextStyle(color: AppTheme.grey600),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Offers',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Column(
              children: offers.map((offer) {
                return _buildOfferCard(offer, isActive: true);
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpiredOffersSection() {
    final userId = _supabase.client.auth.currentUser?.id ?? '';

    return FutureBuilder<List<RetentionOffer>>(
      future: _loadExpiredOffers(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final offers = snapshot.data ?? [];
        if (offers.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Past Offers',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.grey600),
            ),
            const SizedBox(height: 12),
            Column(
              children: offers.take(3).map((offer) {
                return _buildOfferCard(offer, isActive: false);
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOfferCard(RetentionOffer offer, {required bool isActive}) {
    final icon = _getOfferIcon(offer.offerType);
    final discount = offer.discountPercentage ?? 0.0;
    final hasExpired = offer.expiresAt?.isBefore(DateTime.now()) ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isActive ? 2 : 0,
      color: hasExpired ? Colors.grey[50] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getOfferTitle(offer.offerType),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (discount > 0)
                        Text(
                          '${discount.toStringAsFixed(0)}% Discount',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (offer.description != null && offer.description!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.description!,
                    style: const TextStyle(fontSize: 13, color: AppTheme.grey600),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            if (isActive && !hasExpired)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (offer.expiresAt != null)
                    Text(
                      'Expires: ${_formatDate(offer.expiresAt!)}',
                      style: const TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            if (offer.status == 'pending' && isActive && !hasExpired)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejectOffer(offer),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptOffer(offer),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                      child: const Text('Accept', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              )
            else if (offer.status == 'accepted')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'You accepted this offer',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )
            else if (offer.status == 'rejected')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Offer Declined',
                  style: TextStyle(color: AppTheme.grey600),
                ),
              )
            else if (hasExpired)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Offer Expired',
                  style: TextStyle(color: AppTheme.grey600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptOffer(RetentionOffer offer) async {
    try {
      await _subscriptionService.acceptRetentionOffer(offer.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer accepted! It will be applied to your next subscription billing.'),
            duration: Duration(seconds: 3),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _rejectOffer(RetentionOffer offer) async {
    try {
      await _subscriptionService.rejectRetentionOffer(offer.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer declined')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<List<RetentionOffer>> _loadActiveOffers(String userId) async {
    // This would need to be implemented in the service
    return [];
  }

  Future<List<RetentionOffer>> _loadExpiredOffers(String userId) async {
    // This would need to be implemented in the service
    return [];
  }

  IconData _getOfferIcon(String offerType) {
    switch (offerType.toLowerCase()) {
      case 'discount':
        return Icons.local_offer;
      case 'free_delivery':
        return Icons.local_shipping;
      case 'extended_pause':
        return Icons.pause_circle;
      case 'gift':
        return Icons.card_giftcard;
      default:
        return Icons.star;
    }
  }

  String _getOfferTitle(String offerType) {
    switch (offerType.toLowerCase()) {
      case 'discount':
        return 'Special Discount';
      case 'free_delivery':
        return 'Free Delivery';
      case 'extended_pause':
        return 'Extended Pause';
      case 'gift':
        return 'Special Gift';
      default:
        return 'Special Offer';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
