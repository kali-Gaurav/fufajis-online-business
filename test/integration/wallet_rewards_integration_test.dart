import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/services/wallet_service.dart';
import 'package:fufajis_online/services/reward_system.dart';
import 'package:fufajis_online/services/membership_tier_calculator.dart';
import 'package:fufajis_online/services/cashback_calculator.dart';
import 'package:fufajis_online/models/user_model.dart';

void main() {
  group('Wallet and Rewards Integration', () {
    late RewardSystem rewardSystem;
    late MembershipTierCalculator tierCalculator;
    late CashbackCalculator cashbackCalculator;

    setUp(() {
      rewardSystem = RewardSystem();
      tierCalculator = MembershipTierCalculator();
      cashbackCalculator = CashbackCalculator();
    });

    group('Complete order flow with rewards', () {
      test('should calculate all rewards for a ₹500 order', () {
        const orderAmount = 500.0;

        // Calculate order points (1 point per ₹10)
        final orderPoints = rewardSystem.calculateOrderPoints(orderAmount);
        expect(orderPoints, 50);

        // Calculate cashback (1%)
        final cashback = cashbackCalculator.calculateCashback(orderAmount);
        expect(cashback, 5.0);

        // Total rewards: 50 points + ₹5 cashback
        expect(orderPoints, 50);
        expect(cashback, 5.0);
      });

      test('should calculate rewards with first order bonus', () {
        const orderAmount = 500.0;

        // Order points
        final orderPoints = rewardSystem.calculateOrderPoints(orderAmount);
        // First order bonus
        final firstOrderBonus = RewardSystem.firstOrderPoints;
        // Total points
        final totalPoints = orderPoints + firstOrderBonus;

        expect(orderPoints, 50);
        expect(firstOrderBonus, 100);
        expect(totalPoints, 150);

        // Cashback
        final cashback = cashbackCalculator.calculateCashback(orderAmount);
        expect(cashback, 5.0);
      });

      test('should calculate tier upgrade after order', () {
        // Simulate customer spending progression
        var currentSpending = 0.0;
        var currentTier = tierCalculator.calculateTier(currentSpending);
        expect(currentTier, MembershipTier.bronze);

        // After first order of ₹500
        currentSpending += 500.0;
        currentTier = tierCalculator.calculateTier(currentSpending);
        expect(currentTier, MembershipTier.bronze);

        // After multiple orders totaling ₹1000
        currentSpending = 1000.0;
        currentTier = tierCalculator.calculateTier(currentSpending);
        expect(currentTier, MembershipTier.silver);

        // After spending ₹5000
        currentSpending = 5000.0;
        currentTier = tierCalculator.calculateTier(currentSpending);
        expect(currentTier, MembershipTier.gold);

        // After spending ₹20000
        currentSpending = 20000.0;
        currentTier = tierCalculator.calculateTier(currentSpending);
        expect(currentTier, MembershipTier.platinum);
      });
    });

    group('Tier benefits progression', () {
      test('should provide increasing cashback with tier upgrades', () {
        // Bronze: 1%
        var benefits = tierCalculator.getTierBenefits(MembershipTier.bronze);
        expect(benefits['cashbackPercentage'], 1.0);

        // Silver: 1.5%
        benefits = tierCalculator.getTierBenefits(MembershipTier.silver);
        expect(benefits['cashbackPercentage'], 1.5);

        // Gold: 2%
        benefits = tierCalculator.getTierBenefits(MembershipTier.gold);
        expect(benefits['cashbackPercentage'], 2.0);

        // Platinum: 3%
        benefits = tierCalculator.getTierBenefits(MembershipTier.platinum);
        expect(benefits['cashbackPercentage'], 3.0);
      });

      test('should provide increasing points multiplier with tier upgrades', () {
        // Bronze: 1x
        var benefits = tierCalculator.getTierBenefits(MembershipTier.bronze);
        expect(benefits['pointsMultiplier'], 1.0);

        // Silver: 1.2x
        benefits = tierCalculator.getTierBenefits(MembershipTier.silver);
        expect(benefits['pointsMultiplier'], 1.2);

        // Gold: 1.5x
        benefits = tierCalculator.getTierBenefits(MembershipTier.gold);
        expect(benefits['pointsMultiplier'], 1.5);

        // Platinum: 2x
        benefits = tierCalculator.getTierBenefits(MembershipTier.platinum);
        expect(benefits['pointsMultiplier'], 2.0);
      });

      test('should provide decreasing free delivery threshold with tier upgrades', () {
        // Bronze: ₹500
        var benefits = tierCalculator.getTierBenefits(MembershipTier.bronze);
        expect(benefits['freeDeliveryThreshold'], 500.0);

        // Silver: ₹300
        benefits = tierCalculator.getTierBenefits(MembershipTier.silver);
        expect(benefits['freeDeliveryThreshold'], 300.0);

        // Gold: ₹200
        benefits = tierCalculator.getTierBenefits(MembershipTier.gold);
        expect(benefits['freeDeliveryThreshold'], 200.0);

        // Platinum: ₹0 (free delivery always)
        benefits = tierCalculator.getTierBenefits(MembershipTier.platinum);
        expect(benefits['freeDeliveryThreshold'], 0.0);
      });
    });

    group('Points redemption flow', () {
      test('should convert points to wallet credit correctly', () {
        // 100 points = ₹1
        var walletCredit = rewardSystem.convertPointsToCurrency(100);
        expect(walletCredit, 1.0);

        // 500 points = ₹5
        walletCredit = rewardSystem.convertPointsToCurrency(500);
        expect(walletCredit, 5.0);

        // 1000 points = ₹10
        walletCredit = rewardSystem.convertPointsToCurrency(1000);
        expect(walletCredit, 10.0);
      });

      test('should allow partial points redemption', () {
        // Redeem 250 points = ₹2.50
        final walletCredit = rewardSystem.convertPointsToCurrency(250);
        expect(walletCredit, 2.5);
      });
    });

    group('Bonus points accumulation', () {
      test('should accumulate all bonus points correctly', () {
        var totalPoints = 0;

        // First order: 100 points
        totalPoints += RewardSystem.firstOrderPoints;
        expect(totalPoints, 100);

        // Review: 20 points
        totalPoints += RewardSystem.reviewPoints;
        expect(totalPoints, 120);

        // Referral: 50 points
        totalPoints += RewardSystem.referralPoints;
        expect(totalPoints, 170);

        // Convert to wallet: ₹1.70
        final walletCredit = rewardSystem.convertPointsToCurrency(totalPoints);
        expect(walletCredit, 1.7);
      });
    });

    group('Cashback calculation with tier multipliers', () {
      test('should calculate cashback with tier multipliers', () {
        const orderAmount = 1000.0;

        // Bronze tier (1x multiplier)
        var cashback = cashbackCalculator.calculateCashback(
          orderAmount,
          multiplier: 1.0,
        );
        expect(cashback, 10.0);

        // Silver tier (1.5x multiplier)
        cashback = cashbackCalculator.calculateCashback(
          orderAmount,
          multiplier: 1.5,
        );
        expect(cashback, 15.0);

        // Gold tier (2x multiplier)
        cashback = cashbackCalculator.calculateCashback(
          orderAmount,
          multiplier: 2.0,
        );
        expect(cashback, 20.0);

        // Platinum tier (3x multiplier)
        cashback = cashbackCalculator.calculateCashback(
          orderAmount,
          multiplier: 3.0,
        );
        expect(cashback, 30.0);
      });
    });

    group('Tier progress tracking', () {
      test('should calculate progress to next tier', () {
        // Bronze: 500 out of 1000 = 50%
        var progress = tierCalculator.getTierProgress(500.0);
        expect(progress, 50.0);

        // Silver: 2500 out of 5000 = 50%
        progress = tierCalculator.getTierProgress(3500.0);
        expect(progress, 50.0);

        // Gold: 7500 out of 15000 = 50%
        progress = tierCalculator.getTierProgress(12500.0);
        expect(progress, 50.0);

        // Platinum: 100%
        progress = tierCalculator.getTierProgress(50000.0);
        expect(progress, 100.0);
      });

      test('should provide next tier information', () {
        // From Bronze
        var info = tierCalculator.getNextTierInfo(500.0);
        expect(info['currentTier'], MembershipTier.bronze);
        expect(info['nextTier'], MembershipTier.silver);
        expect(info['spendingRequired'], 500.0);

        // From Silver
        info = tierCalculator.getNextTierInfo(2500.0);
        expect(info['currentTier'], MembershipTier.silver);
        expect(info['nextTier'], MembershipTier.gold);
        expect(info['spendingRequired'], 2500.0);

        // From Gold
        info = tierCalculator.getNextTierInfo(10000.0);
        expect(info['currentTier'], MembershipTier.gold);
        expect(info['nextTier'], MembershipTier.platinum);
        expect(info['spendingRequired'], 10000.0);

        // At Platinum
        info = tierCalculator.getNextTierInfo(50000.0);
        expect(info['currentTier'], MembershipTier.platinum);
        expect(info['nextTier'], isNull);
      });
    });

    group('Realistic customer journey', () {
      test('should track complete customer journey with rewards', () {
        // Customer starts at Bronze tier
        var currentTier = tierCalculator.calculateTier(0.0);
        expect(currentTier, MembershipTier.bronze);

        // First order: ₹500
        var orderAmount = 500.0;
        var orderPoints = rewardSystem.calculateOrderPoints(orderAmount);
        var cashback = cashbackCalculator.calculateCashback(orderAmount);
        var totalPoints = orderPoints + RewardSystem.firstOrderPoints;

        expect(orderPoints, 50);
        expect(cashback, 5.0);
        expect(totalPoints, 150);

        // After 2 more orders of ₹500 each, total spending = ₹1500
        var totalSpending = 1500.0;
        currentTier = tierCalculator.calculateTier(totalSpending);
        expect(currentTier, MembershipTier.silver);

        // Silver tier benefits
        var benefits = tierCalculator.getTierBenefits(currentTier);
        expect(benefits['cashbackPercentage'], 1.5);

        // Next order with Silver tier: ₹500
        orderAmount = 500.0;
        cashback = cashbackCalculator.calculateCashback(
          orderAmount,
          multiplier: 1.5,
        );
        expect(cashback, 7.5);

        // Continue spending to reach Gold tier (₹5000 total)
        totalSpending = 5000.0;
        currentTier = tierCalculator.calculateTier(totalSpending);
        expect(currentTier, MembershipTier.gold);

        // Gold tier benefits
        benefits = tierCalculator.getTierBenefits(currentTier);
        expect(benefits['cashbackPercentage'], 2.0);
        expect(benefits['freeDeliveryThreshold'], 200.0);

        // Continue to Platinum tier (₹20000 total)
        totalSpending = 20000.0;
        currentTier = tierCalculator.calculateTier(totalSpending);
        expect(currentTier, MembershipTier.platinum);

        // Platinum tier benefits
        benefits = tierCalculator.getTierBenefits(currentTier);
        expect(benefits['cashbackPercentage'], 3.0);
        expect(benefits['freeDeliveryThreshold'], 0.0);
      });
    });
  });
}
