import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/services/reward_system.dart';

void main() {
  group('RewardSystem', () {
    late RewardSystem rewardSystem;

    setUp(() {
      rewardSystem = RewardSystem();
    });

    group('calculateOrderPoints', () {
      test('should calculate 1 point per ₹10 spent', () {
        // 1 point per ₹10
        expect(rewardSystem.calculateOrderPoints(100.0), 10);
        expect(rewardSystem.calculateOrderPoints(50.0), 5);
        expect(rewardSystem.calculateOrderPoints(25.0), 2);
        expect(rewardSystem.calculateOrderPoints(10.0), 1);
      });

      test('should floor the result', () {
        // 15 rupees = 1.5 points, should floor to 1
        expect(rewardSystem.calculateOrderPoints(15.0), 1);
        // 99 rupees = 9.9 points, should floor to 9
        expect(rewardSystem.calculateOrderPoints(99.0), 9);
      });

      test('should handle zero amount', () {
        expect(rewardSystem.calculateOrderPoints(0.0), 0);
      });

      test('should handle large amounts', () {
        expect(rewardSystem.calculateOrderPoints(10000.0), 1000);
      });
    });

    group('convertPointsToCurrency', () {
      test('should convert 100 points to ₹1', () {
        expect(rewardSystem.convertPointsToCurrency(100), 1.0);
      });

      test('should convert 50 points to ₹0.50', () {
        expect(rewardSystem.convertPointsToCurrency(50), 0.5);
      });

      test('should convert 1000 points to ₹10', () {
        expect(rewardSystem.convertPointsToCurrency(1000), 10.0);
      });

      test('should handle zero points', () {
        expect(rewardSystem.convertPointsToCurrency(0), 0.0);
      });
    });

    group('convertCurrencyToPoints', () {
      test('should convert ₹1 to 100 points', () {
        expect(rewardSystem.convertCurrencyToPoints(1.0), 100.0);
      });

      test('should convert ₹10 to 1000 points', () {
        expect(rewardSystem.convertCurrencyToPoints(10.0), 1000.0);
      });

      test('should convert ₹0.50 to 50 points', () {
        expect(rewardSystem.convertCurrencyToPoints(0.5), 50.0);
      });
    });

    group('Reward constants', () {
      test('should have correct first order points', () {
        expect(RewardSystem.firstOrderPoints, 100);
      });

      test('should have correct review points', () {
        expect(RewardSystem.reviewPoints, 20);
      });

      test('should have correct referral points', () {
        expect(RewardSystem.referralPoints, 50);
      });

      test('should have correct points per rupee', () {
        expect(RewardSystem.pointsPerRupee, 0.1);
      });

      test('should have correct points to currency rate', () {
        expect(RewardSystem.pointsToCurrencyRate, 0.01);
      });
    });

    group('Reward calculations', () {
      test('should calculate total points for order with first order bonus', () {
        // Order amount: ₹500 = 50 points
        // First order bonus: 100 points
        // Total: 150 points
        final orderPoints = rewardSystem.calculateOrderPoints(500.0);
        final totalPoints = orderPoints + RewardSystem.firstOrderPoints;
        expect(totalPoints, 150);
      });

      test('should calculate total points with review bonus', () {
        // Order amount: ₹500 = 50 points
        // Review bonus: 20 points
        // Total: 70 points
        final orderPoints = rewardSystem.calculateOrderPoints(500.0);
        final totalPoints = orderPoints + RewardSystem.reviewPoints;
        expect(totalPoints, 70);
      });

      test('should calculate total points with referral bonus', () {
        // Order amount: ₹500 = 50 points
        // Referral bonus: 50 points
        // Total: 100 points
        final orderPoints = rewardSystem.calculateOrderPoints(500.0);
        final totalPoints = orderPoints + RewardSystem.referralPoints;
        expect(totalPoints, 100);
      });
    });

    group('Points redemption', () {
      test('should calculate wallet credit from points redemption', () {
        // 100 points = ₹1
        final walletCredit = rewardSystem.convertPointsToCurrency(100);
        expect(walletCredit, 1.0);
      });

      test('should calculate wallet credit for 500 points', () {
        // 500 points = ₹5
        final walletCredit = rewardSystem.convertPointsToCurrency(500);
        expect(walletCredit, 5.0);
      });

      test('should calculate wallet credit for 1000 points', () {
        // 1000 points = ₹10
        final walletCredit = rewardSystem.convertPointsToCurrency(1000);
        expect(walletCredit, 10.0);
      });
    });
  });
}
