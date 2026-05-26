import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/services/membership_tier_calculator.dart';
import 'package:fufajis_online/models/user_model.dart';

void main() {
  group('MembershipTierCalculator', () {
    late MembershipTierCalculator calculator;

    setUp(() {
      calculator = MembershipTierCalculator();
    });

    group('calculateTier', () {
      test('should return Bronze tier for spending ₹0-999', () {
        expect(calculator.calculateTier(0.0), MembershipTier.bronze);
        expect(calculator.calculateTier(500.0), MembershipTier.bronze);
        expect(calculator.calculateTier(999.0), MembershipTier.bronze);
      });

      test('should return Silver tier for spending ₹1000-4999', () {
        expect(calculator.calculateTier(1000.0), MembershipTier.silver);
        expect(calculator.calculateTier(2500.0), MembershipTier.silver);
        expect(calculator.calculateTier(4999.0), MembershipTier.silver);
      });

      test('should return Gold tier for spending ₹5000-19999', () {
        expect(calculator.calculateTier(5000.0), MembershipTier.gold);
        expect(calculator.calculateTier(10000.0), MembershipTier.gold);
        expect(calculator.calculateTier(19999.0), MembershipTier.gold);
      });

      test('should return Platinum tier for spending ₹20000+', () {
        expect(calculator.calculateTier(20000.0), MembershipTier.platinum);
        expect(calculator.calculateTier(50000.0), MembershipTier.platinum);
        expect(calculator.calculateTier(100000.0), MembershipTier.platinum);
      });

      test('should handle boundary values correctly', () {
        // Just below Silver threshold
        expect(calculator.calculateTier(999.99), MembershipTier.bronze);
        // At Silver threshold
        expect(calculator.calculateTier(1000.0), MembershipTier.silver);
        // Just below Gold threshold
        expect(calculator.calculateTier(4999.99), MembershipTier.silver);
        // At Gold threshold
        expect(calculator.calculateTier(5000.0), MembershipTier.gold);
        // Just below Platinum threshold
        expect(calculator.calculateTier(19999.99), MembershipTier.gold);
        // At Platinum threshold
        expect(calculator.calculateTier(20000.0), MembershipTier.platinum);
      });
    });

    group('getTierBenefits', () {
      test('should return Bronze benefits', () {
        final benefits = calculator.getTierBenefits(MembershipTier.bronze);
        expect(benefits['name'], 'Bronze');
        expect(benefits['cashbackPercentage'], 1.0);
        expect(benefits['pointsMultiplier'], 1.0);
        expect(benefits['freeDeliveryThreshold'], 500.0);
      });

      test('should return Silver benefits', () {
        final benefits = calculator.getTierBenefits(MembershipTier.silver);
        expect(benefits['name'], 'Silver');
        expect(benefits['cashbackPercentage'], 1.5);
        expect(benefits['pointsMultiplier'], 1.2);
        expect(benefits['freeDeliveryThreshold'], 300.0);
      });

      test('should return Gold benefits', () {
        final benefits = calculator.getTierBenefits(MembershipTier.gold);
        expect(benefits['name'], 'Gold');
        expect(benefits['cashbackPercentage'], 2.0);
        expect(benefits['pointsMultiplier'], 1.5);
        expect(benefits['freeDeliveryThreshold'], 200.0);
      });

      test('should return Platinum benefits', () {
        final benefits = calculator.getTierBenefits(MembershipTier.platinum);
        expect(benefits['name'], 'Platinum');
        expect(benefits['cashbackPercentage'], 3.0);
        expect(benefits['pointsMultiplier'], 2.0);
        expect(benefits['freeDeliveryThreshold'], 0.0);
      });
    });

    group('getNextTierInfo', () {
      test('should return next tier info for Bronze', () {
        final info = calculator.getNextTierInfo(500.0);
        expect(info['currentTier'], MembershipTier.bronze);
        expect(info['nextTier'], MembershipTier.silver);
        expect(info['spendingRequired'], 500.0);
      });

      test('should return next tier info for Silver', () {
        final info = calculator.getNextTierInfo(2500.0);
        expect(info['currentTier'], MembershipTier.silver);
        expect(info['nextTier'], MembershipTier.gold);
        expect(info['spendingRequired'], 2500.0);
      });

      test('should return next tier info for Gold', () {
        final info = calculator.getNextTierInfo(10000.0);
        expect(info['currentTier'], MembershipTier.gold);
        expect(info['nextTier'], MembershipTier.platinum);
        expect(info['spendingRequired'], 10000.0);
      });

      test('should return null next tier for Platinum', () {
        final info = calculator.getNextTierInfo(50000.0);
        expect(info['currentTier'], MembershipTier.platinum);
        expect(info['nextTier'], isNull);
      });
    });

    group('getTierProgress', () {
      test('should calculate progress for Bronze tier', () {
        // 500 out of 1000 = 50%
        final progress = calculator.getTierProgress(500.0);
        expect(progress, 50.0);
      });

      test('should calculate progress for Silver tier', () {
        // 2500 out of 5000 = 50%
        final progress = calculator.getTierProgress(3500.0);
        expect(progress, 50.0);
      });

      test('should calculate progress for Gold tier', () {
        // 7500 out of 15000 = 50%
        final progress = calculator.getTierProgress(12500.0);
        expect(progress, 50.0);
      });

      test('should return 100% for Platinum tier', () {
        final progress = calculator.getTierProgress(50000.0);
        expect(progress, 100.0);
      });

      test('should clamp progress between 0 and 100', () {
        final progress1 = calculator.getTierProgress(0.0);
        expect(progress1, greaterThanOrEqualTo(0.0));
        expect(progress1, lessThanOrEqualTo(100.0));

        final progress2 = calculator.getTierProgress(100000.0);
        expect(progress2, greaterThanOrEqualTo(0.0));
        expect(progress2, lessThanOrEqualTo(100.0));
      });
    });

    group('getTierDisplayName', () {
      test('should return correct display names', () {
        expect(calculator.getTierDisplayName(MembershipTier.bronze), 'Bronze');
        expect(calculator.getTierDisplayName(MembershipTier.silver), 'Silver');
        expect(calculator.getTierDisplayName(MembershipTier.gold), 'Gold');
        expect(calculator.getTierDisplayName(MembershipTier.platinum), 'Platinum');
      });
    });

    group('Tier thresholds', () {
      test('should have correct tier thresholds', () {
        expect(MembershipTierCalculator.tierThresholds[MembershipTier.bronze], 0.0);
        expect(MembershipTierCalculator.tierThresholds[MembershipTier.silver], 1000.0);
        expect(MembershipTierCalculator.tierThresholds[MembershipTier.gold], 5000.0);
        expect(MembershipTierCalculator.tierThresholds[MembershipTier.platinum], 20000.0);
      });
    });
  });
}
