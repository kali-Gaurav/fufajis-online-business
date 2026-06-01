# Wallet and Rewards System Implementation (Phase 7)

## Overview

This document describes the complete implementation of the Wallet and Rewards system for the Hyperlocal Market app. The system includes wallet balance management, cashback calculation, reward points, and membership tier tracking.

## Architecture

### Services

#### 1. WalletService (`lib/services/wallet_service.dart`)
**Responsibility**: Core wallet balance management and transaction tracking

**Key Features**:
- Add/deduct wallet balance with Firestore sync
- Track transaction history with pagination
- Filter transactions by type
- Real-time balance monitoring via streams
- Atomic transactions for data consistency

**Methods**:
- `addToWallet()`: Add amount to wallet and record transaction
- `deductFromWallet()`: Deduct amount from wallet with balance check
- `getWalletBalance()`: Get current wallet balance
- `getTransactionHistory()`: Fetch transaction history with pagination
- `getTransactionsByType()`: Filter transactions by type
- `getTransactionsByOrder()`: Get transactions for specific order
- `watchWalletBalance()`: Stream wallet balance changes
- `watchTransactionHistory()`: Stream transaction history changes

**Transaction Types**:
- `cashback`: Cashback earned from orders
- `rewardPointsRedeemed`: Reward points converted to wallet
- `walletPayment`: Payment from wallet
- `refund`: Refund to wallet
- `referralBonus`: Referral bonus
- `reviewBonus`: Review bonus
- `firstOrderBonus`: First order bonus

#### 2. RewardSystem (`lib/services/reward_system.dart`)
**Responsibility**: Reward points calculation and management

**Key Features**:
- Calculate points based on spending (1 point per ₹10)
- Award bonus points for first order (100 points)
- Award points for reviews (20 points)
- Award points for referrals (50 points)
- Convert points to currency (100 points = ₹1)
- Track points transactions

**Methods**:
- `calculateOrderPoints()`: Calculate points from order amount
- `awardFirstOrderPoints()`: Award 100 points for first order
- `awardReviewPoints()`: Award 20 points for review
- `awardReferralPoints()`: Award 50 points for referral
- `awardOrderPoints()`: Award points for order completion
- `redeemPoints()`: Convert points to wallet credit
- `getRewardPoints()`: Get current reward points
- `convertPointsToCurrency()`: Convert points to ₹
- `convertCurrencyToPoints()`: Convert ₹ to points
- `watchRewardPoints()`: Stream reward points changes

**Constants**:
- `pointsPerRupee`: 0.1 (1 point per ₹10)
- `firstOrderPoints`: 100
- `reviewPoints`: 20
- `referralPoints`: 50
- `pointsToCurrencyRate`: 0.01 (100 points = ₹1)

#### 3. MembershipTierCalculator (`lib/services/membership_tier_calculator.dart`)
**Responsibility**: Membership tier calculation and management

**Key Features**:
- Calculate tier based on lifetime spending
- Track tier progression
- Provide tier-specific benefits
- Update tier on order completion
- Monitor tier changes

**Tier Structure**:
- **Bronze**: ₹0-999 (1% cashback, 1x points multiplier)
- **Silver**: ₹1000-4999 (1.5% cashback, 1.2x points multiplier)
- **Gold**: ₹5000-19999 (2% cashback, 1.5x points multiplier)
- **Platinum**: ₹20000+ (3% cashback, 2x points multiplier)

**Methods**:
- `calculateTier()`: Calculate tier from spending amount
- `updateMembershipTier()`: Update user's tier
- `getUserTier()`: Get current tier
- `getTierBenefits()`: Get benefits for tier
- `getNextTierInfo()`: Get next tier and spending required
- `getTierProgress()`: Get progress to next tier
- `getTierDisplayName()`: Get tier display name
- `getTierColor()`: Get tier color for UI
- `watchMembershipTier()`: Stream tier changes

#### 4. CashbackCalculator (`lib/services/cashback_calculator.dart`)
**Responsibility**: Cashback calculation and application

**Key Features**:
- Calculate 1% base cashback
- Apply tier multipliers
- Track cashback history
- Calculate total cashback earned

**Methods**:
- `calculateCashback()`: Calculate cashback with optional multiplier
- `applyCashback()`: Apply cashback to wallet
- `getCashbackAmount()`: Get cashback for order based on tier
- `getCashbackPercentage()`: Get cashback percentage for tier
- `getCashbackHistory()`: Get cashback transaction history
- `getTotalCashbackEarned()`: Get total cashback earned
- `watchCashbackHistory()`: Stream cashback history changes

### Provider

#### WalletProvider (`lib/providers/wallet_provider.dart`)
**Responsibility**: State management for wallet and rewards

**State Variables**:
- `walletBalance`: Current wallet balance
- `rewardPoints`: Current reward points
- `membershipTier`: Current membership tier
- `transactions`: Transaction history
- `isLoading`: Loading state
- `errorMessage`: Error messages

**Methods**:
- `initializeWallet()`: Initialize wallet data
- `fetchTransactions()`: Fetch transaction history
- `filterTransactionsByType()`: Filter transactions
- `applyCashback()`: Apply cashback for order
- `awardOrderPoints()`: Award points for order
- `awardFirstOrderBonus()`: Award first order bonus
- `awardReviewBonus()`: Award review bonus
- `awardReferralBonus()`: Award referral bonus
- `redeemRewardPoints()`: Redeem points for wallet credit
- `updateMembershipTier()`: Update tier
- `getTierProgress()`: Get tier progress info
- `watchWalletBalance()`: Stream wallet balance
- `watchRewardPoints()`: Stream reward points
- `watchMembershipTier()`: Stream tier changes

### UI Components

#### WalletHistoryScreen (`lib/screens/customer/wallet_history_screen.dart`)
**Responsibility**: Display wallet transaction history

**Features**:
- Display transaction history with pagination
- Filter by transaction type
- Show transaction details (type, amount, order reference, timestamp)
- Real-time balance display
- Transaction icons and colors

**Filters**:
- All transactions
- Cashback
- Refund
- Payment
- Reward Points Redeemed

## Data Models

### WalletTransaction
```dart
class WalletTransaction {
  final String id;
  final String userId;
  final WalletTransactionType type;
  final double amount;
  final String? orderReference;
  final DateTime timestamp;
  final String? description;
  final double balanceAfter;
}
```

## Integration Points

### Order Completion Flow
1. Order is marked as delivered
2. Calculate cashback (1% of order total)
3. Apply cashback to wallet
4. Calculate reward points (1 point per ₹10)
5. Award order points
6. Update membership tier based on lifetime spending
7. Record all transactions in history

### Checkout Integration
1. Display wallet balance on checkout screen
2. Allow using up to 50% of order value from wallet
3. Deduct wallet balance on order placement
4. Record wallet payment transaction

### Cancellation Flow
1. Order is cancelled
2. Refund wallet amount if used
3. Reverse cashback if already applied
4. Reverse reward points if already awarded
5. Record refund transaction

## Firestore Structure

```
users/{userId}
  ├── walletBalance: double
  ├── rewardPoints: int
  ├── membershipTier: string
  └── wallet_transactions/{transactionId}
      ├── id: string
      ├── userId: string
      ├── type: string
      ├── amount: double
      ├── orderReference: string
      ├── timestamp: datetime
      ├── description: string
      └── balanceAfter: double

users/{userId}/reward_transactions/{transactionId}
  ├── id: string
  ├── userId: string
  ├── points: int
  ├── description: string
  ├── orderId: string
  └── timestamp: datetime

users/{userId}/tier_history/{upgradeId}
  ├── id: string
  ├── userId: string
  ├── oldTier: string
  ├── newTier: string
  └── timestamp: datetime
```

## Test Coverage

### Unit Tests
- `test/services/wallet_service_test.dart`: Wallet transaction logic
- `test/services/reward_system_test.dart`: Points calculation
- `test/services/membership_tier_calculator_test.dart`: Tier calculation
- `test/services/cashback_calculator_test.dart`: Cashback calculation

### Integration Tests
- `test/integration/wallet_rewards_integration_test.dart`: Complete flow testing

### Test Scenarios
1. Wallet balance updates
2. Transaction history tracking
3. Points calculation (1 point per ₹10)
4. Bonus points (first order, review, referral)
5. Points redemption (100 points = ₹1)
6. Tier calculation based on spending
7. Tier benefits progression
8. Cashback calculation with tier multipliers
9. Complete customer journey

## Requirements Mapping

### Requirement 11.1: Wallet Balance Management
- ✅ Add walletBalance field to UserModel
- ✅ Implement wallet balance updates with Firestore sync
- ✅ Implement wallet history tracking (transaction type, amount, order reference, timestamp)
- ✅ Calculate 1% cashback on order completion
- ✅ Add cashback to wallet balance

### Requirement 11.2: Reward Points
- ✅ Award 1 point per ₹10 spent
- ✅ Award 100 points for first order
- ✅ Award 20 points for reviews
- ✅ Award 50 points for referrals

### Requirement 11.3: Points Conversion
- ✅ Implement points-to-currency conversion (100 points = ₹1)

### Requirement 11.4: Wallet at Checkout
- ✅ Display wallet balance on checkout screen
- ✅ Allow using up to 50% of order value from wallet
- ✅ Deduct wallet balance on order placement
- ✅ Refund to wallet on cancellation

### Requirement 11.5: Membership Tiers
- ✅ Bronze tier (₹0-999)
- ✅ Silver tier (₹1000-4999)
- ✅ Gold tier (₹5000-19999)
- ✅ Platinum tier (₹20000+)
- ✅ Update tier on order completion

### Requirement 11.6: Wallet Sync
- ✅ Update wallet balance with Firestore sync

### Requirement 11.7: Wallet History
- ✅ Display transaction history with pagination
- ✅ Show transaction type, amount, order reference, timestamp
- ✅ Add filter by transaction type

## Usage Examples

### Apply Cashback for Order
```dart
final walletProvider = context.read<WalletProvider>();
await walletProvider.applyCashback(
  userId: userId,
  orderAmount: 500.0,
  orderId: 'order_123',
);
```

### Award Reward Points
```dart
await walletProvider.awardOrderPoints(
  userId: userId,
  orderAmount: 500.0,
  orderId: 'order_123',
);
```

### Redeem Points
```dart
final success = await walletProvider.redeemRewardPoints(
  userId: userId,
  pointsToRedeem: 500,
);
```

### Update Membership Tier
```dart
await walletProvider.updateMembershipTier(userId);
```

### Get Tier Progress
```dart
final progress = await walletProvider.getTierProgress(userId);
print('Next tier: ${progress['nextTier']}');
print('Spending required: ${progress['spendingRequired']}');
```

## Performance Considerations

1. **Firestore Transactions**: All wallet operations use transactions for atomicity
2. **Pagination**: Transaction history supports pagination (20 items per page)
3. **Caching**: Real-time streams for efficient updates
4. **Indexing**: Firestore indexes on userId, type, and timestamp for fast queries

## Security Considerations

1. **Firestore Rules**: Only users can access their own wallet data
2. **Atomic Operations**: Transactions prevent race conditions
3. **Audit Trail**: All transactions are recorded with timestamps
4. **Balance Verification**: Wallet balance is verified before deduction

## Future Enhancements

1. Wallet top-up functionality
2. Wallet transfer between users
3. Wallet expiry policies
4. Seasonal bonus points
5. Tier-specific promotions
6. Wallet analytics dashboard
7. Automatic tier downgrade after inactivity
8. Wallet notifications for milestones

## Troubleshooting

### Wallet Balance Not Updating
- Check Firestore security rules
- Verify user ID is correct
- Check network connectivity
- Review error messages in logs

### Points Not Awarded
- Verify order status is 'delivered'
- Check if points were already awarded
- Review reward system configuration
- Check Firestore transaction logs

### Tier Not Updating
- Verify lifetime spending calculation
- Check order status filtering
- Review tier threshold configuration
- Check Firestore tier history

## Conclusion

The Wallet and Rewards system provides a comprehensive solution for managing customer loyalty through wallet balance, reward points, and membership tiers. The implementation follows best practices for state management, data consistency, and user experience.
