import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'membership_tier_calculator.dart';
import 'reward_system.dart';
import 'whatsapp_notification_service.dart';

/// Production-grade Loyalty Membership Service
///
/// Handles:
/// - Tier-based benefits (Bronze, Silver, Gold, Platinum)
/// - Priority delivery slot queuing for higher tiers
/// - Streak tracking (consecutive orders = bonus multiplier)
/// - Tier-aware free delivery thresholds
/// - Birthday/anniversary bonus rewards
/// - Exclusive early access to deals for Gold+ tiers
/// - Automated tier upgrade/downgrade notifications
class LoyaltyMembershipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MembershipTierCalculator _tierCalculator = MembershipTierCalculator();
  final RewardSystem _rewardSystem = RewardSystem();

  static final LoyaltyMembershipService _instance = LoyaltyMembershipService._internal();
  factory LoyaltyMembershipService() => _instance;
  LoyaltyMembershipService._internal();

  // ===== PRIORITY SLOT SYSTEM =====

  /// Priority slot multiplier per tier
  static const Map<MembershipTier, int> _priorityWeights = {
    MembershipTier.bronze: 1,
    MembershipTier.silver: 2,
    MembershipTier.gold: 3,
    MembershipTier.platinum: 5,
  };
  /// Check if a delivery slot is available for a given tier
  Future<bool> isSlotAvailable({
    required String slotId,
    required MembershipTier userTier,
    required int currentSlotOrders,
    required int maxSlotOrders,
  }) async {
    // If slot is full for everyone, only Platinum can still book
    if (currentSlotOrders >= maxSlotOrders) {
      return userTier == MembershipTier.platinum;
    }

    // Reserve last 20% of slots for Gold+ members
    final reservedThreshold = (maxSlotOrders * 0.8).floor();
    if (currentSlotOrders >= reservedThreshold) {
      return userTier == MembershipTier.gold || userTier == MembershipTier.platinum;
    }

    return true;
  }

  /// Book a priority delivery slot
  Future<Map<String, dynamic>?> bookPrioritySlot({
    required String userId,
    required String orderId,
    required String slotId,
    required String slotLabel,  // e.g., "2:00 PM - 4:00 PM"
    required DateTime slotDate,
  }) async {
    try {
      final tier = await _tierCalculator.getUserTier(userId);
      final slotRef = _firestore
          .collection('delivery_slots')
          .doc('${slotDate.toIso8601String().split('T')[0]}_$slotId');

      final result = await _firestore.runTransaction((transaction) async {
        final slotDoc = await transaction.get(slotRef);
        
        int currentOrders = 0;
        int maxOrders = 10; // Default max orders per slot

        if (slotDoc.exists) {
          final data = slotDoc.data()!;
          currentOrders = (data['currentOrders'] as num? ?? 0).toInt();
          maxOrders = (data['maxOrders'] as num? ?? 10).toInt();
        }

        final available = await isSlotAvailable(
          slotId: slotId,
          userTier: tier,
          currentSlotOrders: currentOrders,
          maxSlotOrders: maxOrders,
        );

        if (!available) {
          throw Exception('This slot is not available for your membership tier');
        }

        // Calculate priority position (higher tier = earlier in queue)
        final priorityWeight = _priorityWeights[tier] ?? 1;
        final queuePosition = (currentOrders + 1) - (priorityWeight - 1);

        final booking = {
          'userId': userId,
          'orderId': orderId,
          'tier': tier.toString(),
          'queuePosition': queuePosition.clamp(1, maxOrders),
          'slotLabel': slotLabel,
          'slotDate': slotDate,
          'bookedAt': DateTime.now(),
          'isPriority': tier == MembershipTier.gold || tier == MembershipTier.platinum,
        };

        if (!slotDoc.exists) {
          transaction.set(slotRef, {
            'slotId': slotId,
            'slotLabel': slotLabel,
            'slotDate': slotDate,
            'maxOrders': maxOrders,
            'currentOrders': 1,
            'bookings': [booking],
          });
        } else {
          transaction.update(slotRef, {
            'currentOrders': FieldValue.increment(1),
            'bookings': FieldValue.arrayUnion([booking]),
          });
        }

        return booking;
      });

      return result;
    } catch (e) {
      debugPrint('Error booking priority slot: $e');
      return null;
    }
  }

  /// Get available slots with priority indicators
  Future<List<Map<String, dynamic>>> getAvailableSlots({
    required DateTime date,
    required MembershipTier userTier,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      
      // Generate time slots (10 AM to 9 PM, 2-hour windows)
      final slots = <Map<String, dynamic>>[];
      const startHour = 10;
      const endHour = 21;

      for (var hour = startHour; hour < endHour; hour += 2) {
        final slotId = 'slot_${hour}_${hour + 2}';
        final slotLabel = '${_formatHour(hour)} - ${_formatHour(hour + 2)}';

        // Check Firestore for existing bookings
        final slotDoc = await _firestore
            .collection('delivery_slots')
            .doc('${dateStr}_$slotId')
            .get();

        int currentOrders = 0;
        int maxOrders = 10;

        if (slotDoc.exists) {
          currentOrders = (slotDoc.data()?['currentOrders'] as num? ?? 0).toInt();
          maxOrders = (slotDoc.data()?['maxOrders'] as num? ?? 10).toInt();
        }

        final available = await isSlotAvailable(
          slotId: slotId,
          userTier: userTier,
          currentSlotOrders: currentOrders,
          maxSlotOrders: maxOrders,
        );

        slots.add({
          'slotId': slotId,
          'slotLabel': slotLabel,
          'date': date,
          'currentOrders': currentOrders,
          'maxOrders': maxOrders,
          'isAvailable': available,
          'isPriority': currentOrders >= (maxOrders * 0.8).floor(),
          'fillPercentage': currentOrders / maxOrders,
        });
      }

      return slots;
    } catch (e) {
      debugPrint('Error getting available slots: $e');
      return [];
    }
  }

  String _formatHour(int hour) {
    if (hour == 12) return '12:00 PM';
    if (hour > 12) return '${hour - 12}:00 PM';
    return '$hour:00 AM';
  }

  // ===== STREAK TRACKING =====

  /// Record an order and update the user's ordering streak
  Future<Map<String, dynamic>> updateOrderStreak(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final streakRef = userRef.collection('loyalty_data').doc('streak');

      final result = await _firestore.runTransaction((transaction) async {
        final streakDoc = await transaction.get(streakRef);

        int currentStreak = 0;
        int longestStreak = 0;
        DateTime? lastOrderDate;

        if (streakDoc.exists) {
          final data = streakDoc.data()!;
          currentStreak = (data['currentStreak'] as num? ?? 0).toInt();
          longestStreak = (data['longestStreak'] as num? ?? 0).toInt();
          lastOrderDate = (data['lastOrderDate'] as Timestamp?)?.toDate();
        }

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        if (lastOrderDate != null) {
          final lastDate = DateTime(lastOrderDate.year, lastOrderDate.month, lastOrderDate.day);
          final daysDiff = today.difference(lastDate).inDays;

          if (daysDiff == 0) {
            // Same day, no change
            return {
              'currentStreak': currentStreak,
              'longestStreak': longestStreak,
              'bonusMultiplier': _getStreakMultiplier(currentStreak),
            };
          } else if (daysDiff <= 7) {
            // Within a week, continue streak
            currentStreak++;
          } else {
            // Streak broken
            currentStreak = 1;
          }
        } else {
          currentStreak = 1;
        }

        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }

        final streakData = {
          'currentStreak': currentStreak,
          'longestStreak': longestStreak,
          'lastOrderDate': now,
          'bonusMultiplier': _getStreakMultiplier(currentStreak),
        };

        transaction.set(streakRef, streakData, SetOptions(merge: true));
        return streakData;
      });

      // Award streak bonus points
      final multiplier = result['bonusMultiplier'] as double;
      if (multiplier > 1.0) {
        final bonusPoints = ((multiplier - 1.0) * 10).round();
        await _rewardSystem.awardOrderPoints(
          userId: userId,
          orderAmount: bonusPoints.toDouble() * 10, // Convert back
          orderId: 'streak_bonus_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      return result;
    } catch (e) {
      debugPrint('Error updating order streak: $e');
      return {'currentStreak': 0, 'longestStreak': 0, 'bonusMultiplier': 1.0};
    }
  }

  /// Get streak bonus multiplier
  double _getStreakMultiplier(int streak) {
    if (streak >= 20) return 2.5;  // 150% bonus
    if (streak >= 15) return 2.0;  // 100% bonus
    if (streak >= 10) return 1.75; // 75% bonus
    if (streak >= 5) return 1.5;   // 50% bonus
    if (streak >= 3) return 1.25;  // 25% bonus
    return 1.0; // No bonus
  }

  /// Get user's streak data
  Future<Map<String, dynamic>> getStreakData(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('loyalty_data')
          .doc('streak')
          .get();

      if (!doc.exists) {
        return {'currentStreak': 0, 'longestStreak': 0, 'bonusMultiplier': 1.0};
      }

      final data = doc.data()!;
      return {
        'currentStreak': data['currentStreak'] ?? 0,
        'longestStreak': data['longestStreak'] ?? 0,
        'bonusMultiplier': data['bonusMultiplier'] ?? 1.0,
        'lastOrderDate': data['lastOrderDate']?.toDate(),
      };
    } catch (e) {
      debugPrint('Error getting streak data: $e');
      return {'currentStreak': 0, 'longestStreak': 0, 'bonusMultiplier': 1.0};
    }
  }

  // ===== TIER-AWARE CHECKOUT BENEFITS =====

  /// Calculate checkout benefits based on membership tier
  Map<String, dynamic> calculateTierBenefits({
    required MembershipTier tier,
    required double orderAmount,
    required double deliveryCharge,
  }) {
    final benefits = _tierCalculator.getTierBenefits(tier);
    final cashbackPct = (benefits['cashbackPercentage'] as double?) ?? 0.0;
    final freeDeliveryThreshold = (benefits['freeDeliveryThreshold'] as double?) ?? 500.0;
    final pointsMultiplier = (benefits['pointsMultiplier'] as double?) ?? 1.0;

    final cashbackAmount = orderAmount * (cashbackPct / 100);
    final isFreeDelivery = orderAmount >= freeDeliveryThreshold;
    final finalDeliveryCharge = isFreeDelivery ? 0.0 : deliveryCharge;
    final pointsEarned = (orderAmount * 0.1 * pointsMultiplier).floor(); // Base: 1pt/₹10

    return {
      'tier': tier,
      'tierName': benefits['name'],
      'cashbackPercentage': cashbackPct,
      'cashbackAmount': cashbackAmount,
      'isFreeDelivery': isFreeDelivery,
      'freeDeliveryThreshold': freeDeliveryThreshold,
      'deliveryChargeSaved': isFreeDelivery ? deliveryCharge : 0.0,
      'finalDeliveryCharge': finalDeliveryCharge,
      'pointsEarned': pointsEarned,
      'pointsMultiplier': pointsMultiplier,
      'totalSavings': cashbackAmount + (isFreeDelivery ? deliveryCharge : 0.0),
    };
  }

  // ===== BIRTHDAY / SPECIAL REWARDS =====

  /// Set user's birthday for birthday bonus
  Future<void> setBirthday(String userId, DateTime birthday) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('loyalty_data')
          .doc('profile')
          .set({
        'birthday': birthday,
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error setting birthday: $e');
    }
  }

  /// Check and award birthday bonus (called daily)
  Future<void> checkBirthdayBonus(String userId) async {
    try {
      final profileDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('loyalty_data')
          .doc('profile')
          .get();

      if (!profileDoc.exists) return;
      final birthday = profileDoc.data()?['birthday']?.toDate();
      if (birthday == null) return;

      final now = DateTime.now();
      if (birthday.month == now.month && birthday.day == now.day) {
        // Check if already awarded this year
        final lastBirthdayBonus = profileDoc.data()?['lastBirthdayBonusYear'];
        if (lastBirthdayBonus == now.year) return;

        // Award 200 bonus points
        await _rewardSystem.awardOrderPoints(
          userId: userId,
          orderAmount: 2000, // 200 points worth
          orderId: 'birthday_bonus_${now.year}',
        );

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('loyalty_data')
            .doc('profile')
            .update({'lastBirthdayBonusYear': now.year});

        // Get user phone for WhatsApp
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final phone = userDoc.data()?['phoneNumber'] as String?;
        if (phone != null) {
          WhatsAppNotificationService.sendOrderUpdate(
            phoneNumber: phone,
            message: '🎂 Happy Birthday from Fufaji! You\'ve earned 200 bonus reward points as our gift. Enjoy shopping today!',
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking birthday bonus: $e');
    }
  }

  // ===== EXCLUSIVE EARLY ACCESS =====

  /// Check if user has early access to deals (Gold+ only)
  bool hasEarlyAccess(MembershipTier tier) {
    return tier == MembershipTier.gold || tier == MembershipTier.platinum;
  }

  /// Get exclusive deals for tier
  Future<List<Map<String, dynamic>>> getExclusiveDeals(MembershipTier tier) async {
    try {
      final now = DateTime.now();
      QuerySnapshot snapshot;

      if (tier == MembershipTier.platinum) {
        // Platinum sees all exclusive deals
        snapshot = await _firestore
            .collection('exclusive_deals')
            .where('isActive', isEqualTo: true)
            .where('expiresAt', isGreaterThan: now)
            .orderBy('expiresAt')
            .limit(20)
            .get();
      } else if (tier == MembershipTier.gold) {
        // Gold sees Gold+ deals
        snapshot = await _firestore
            .collection('exclusive_deals')
            .where('isActive', isEqualTo: true)
            .where('minTier', whereIn: ['MembershipTier.gold', 'MembershipTier.silver', 'MembershipTier.bronze'])
            .limit(15)
            .get();
      } else {
        // Silver/Bronze see basic deals
        snapshot = await _firestore
            .collection('exclusive_deals')
            .where('isActive', isEqualTo: true)
            .where('minTier', isEqualTo: tier.toString())
            .limit(10)
            .get();
      }

      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error getting exclusive deals: $e');
      return [];
    }
  }

  // ===== MEMBERSHIP DASHBOARD DATA =====

  /// Get comprehensive membership dashboard data for a user
  Future<Map<String, dynamic>> getMembershipDashboard(String userId) async {
    try {
      final tier = await _tierCalculator.getUserTier(userId);
      final benefits = _tierCalculator.getTierBenefits(tier);
      final nextTierInfo = _tierCalculator.getNextTierInfo(
        await _getLifetimeSpending(userId),
      );
      final progress = _tierCalculator.getTierProgress(
        await _getLifetimeSpending(userId),
      );
      final streakData = await getStreakData(userId);
      final points = await _rewardSystem.getRewardPoints(userId);

      return {
        'tier': tier,
        'tierName': benefits['name'],
        'tierColor': _tierCalculator.getTierColor(tier),
        'benefits': benefits,
        'nextTierInfo': nextTierInfo,
        'tierProgress': progress,
        'streak': streakData,
        'rewardPoints': points,
        'pointsValue': _rewardSystem.convertPointsToCurrency(points),
        'hasEarlyAccess': hasEarlyAccess(tier),
      };
    } catch (e) {
      debugPrint('Error getting membership dashboard: $e');
      return {};
    }
  }

  Future<double> _getLifetimeSpending(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .where('status', isNotEqualTo: 'OrderStatus.cancelled')
          .get();

      double total = 0.0;
      for (final doc in snapshot.docs) {
        total += ((doc.data()['totalAmount'] as num?) ?? 0.0).toDouble();
      }
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  // ===== TIER NOTIFICATIONS =====

  /// Send tier upgrade celebration notification
  Future<void> notifyTierUpgrade(String userId, MembershipTier oldTier, MembershipTier newTier) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final phone = userDoc.data()?['phoneNumber'] as String?;
      final name = userDoc.data()?['name'] as String? ?? 'Valued Customer';
      final newTierName = _tierCalculator.getTierDisplayName(newTier);

      if (phone != null) {
        WhatsAppNotificationService.sendOrderUpdate(
          phoneNumber: phone,
          message: '🎉 Congratulations $name! You\'ve been upgraded to $newTierName tier! '
              'Enjoy enhanced benefits including higher cashback, priority delivery slots, and exclusive deals.',
        );
      }
    } catch (e) {
      debugPrint('Error notifying tier upgrade: $e');
    }
  }
}
