# Phase 15: Wallet & Rewards - Implementation Checklist

## Overview
Complete wallet balance management, cashback calculation, reward points, and membership tiers.

## Current Status
- ✅ WalletService: Implemented
- ✅ RewardSystem: Implemented
- ✅ MembershipTierCalculator: Implemented
- ✅ CashbackCalculator: Implemented
- ✅ WalletProvider: Implemented
- ✅ WalletHistoryScreen: 95% complete
- ⏳ Checkout integration: Needs completion
- ⏳ Profile integration: Needs completion

## Task 15.1: Complete WalletHistoryScreen UI
**Status:** 95% Complete
**File:** `lib/screens/customer/wallet_history_screen.dart`

### Remaining Work:
- [ ] Add wallet balance display at top
- [ ] Add export transaction history button
- [ ] Add empty state UI improvements
- [ ] Add transaction detail view
- [ ] Test with real data

### Code to Add:
```dart
// Add at top of build method
Container(
  padding: const EdgeInsets.all(16),
  color: Colors.blue[50],
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Wallet Balance',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      Text(
        '₹${walletProvider.walletBalance.toStringAsFixed(2)}',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    ],
  ),
)
```

## Task 15.2: Integrate Wallet at Checkout
**Status:** Not Started
**File:** `lib/screens/customer/checkout_screen.dart`

### Implementation Steps:
1. [ ] Add wallet balance display
2. [ ] Add "Use Wallet" toggle
3. [ ] Calculate max wallet usage (50% of order)
4. [ ] Update order total
5. [ ] Deduct wallet on order placement
6. [ ] Record wallet transaction

### Code Template:
```dart
// Add to checkout screen
bool _useWallet = false;
double _walletAmount = 0.0;

// In build method
CheckboxListTile(
  title: const Text('Use Wallet'),
  subtitle: Text('Available: ₹${walletProvider.walletBalance}'),
  value: _useWallet,
  onChanged: (value) {
    setState(() {
      _useWallet = value ?? false;
      if (_useWallet) {
        _walletAmount = min(
          walletProvider.walletBalance,
          totalAmount * 0.5, // Max 50%
        );
      } else {
        _walletAmount = 0.0;
      }
    });
  },
)
```

## Task 15.3: Implement Cashback System
**Status:** Service Complete, Integration Needed
**File:** `lib/services/cashback_calculator.dart`

### Integration Points:
- [ ] Call applyCashback() on order completion
- [ ] Display cashback in order confirmation
- [ ] Add Firebase Function for automatic cashback
- [ ] Test with various order amounts

### Firebase Function Template:
```typescript
// functions/src/wallet-cashback.ts
export const applyCashbackOnOrderCompletion = functions
  .firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    
    // Check if status changed to delivered
    if (oldData.status !== 'delivered' && newData.status === 'delivered') {
      const cashback = newData.totalAmount * 0.01; // 1% cashback
      
      // Add to wallet
      await admin.firestore()
        .collection('users')
        .doc(newData.customerId)
        .update({
          walletBalance: admin.firestore.FieldValue.increment(cashback)
        });
      
      // Record transaction
      await admin.firestore()
        .collection('users')
        .doc(newData.customerId)
        .collection('wallet_transactions')
        .add({
          type: 'cashback',
          amount: cashback,
          orderReference: context.params.orderId,
          timestamp: admin.firestore.Timestamp.now(),
          description: 'Cashback earned on order'
        });
    }
  });
```

## Task 15.4: Implement Reward Points System
**Status:** Service Complete, Integration Needed
**File:** `lib/services/reward_system.dart`

### Integration Points:
- [ ] Call awardOrderPoints() on order completion
- [ ] Display points in order confirmation
- [ ] Add points display in profile
- [ ] Implement points redemption UI
- [ ] Add Firebase Function for automatic points

### Code to Add in OrderConfirmationScreen:
```dart
// Display earned points
Container(
  padding: const EdgeInsets.all(16),
  color: Colors.amber[50],
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reward Points Earned'),
          Text(
            '${(order.totalAmount / 10).toInt()} points',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.amber[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      Icon(Icons.stars, color: Colors.amber[700]),
    ],
  ),
)
```

## Task 15.5: Implement Membership Tier System
**Status:** Service Complete, Integration Needed
**File:** `lib/services/membership_tier_calculator.dart`

### Integration Points:
- [ ] Display tier in profile
- [ ] Show tier benefits
- [ ] Show progress to next tier
- [ ] Apply tier discounts at checkout
- [ ] Add tier upgrade notifications

### Code to Add in ProfileScreen:
```dart
// Display membership tier
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: _getTierColors(walletProvider.membershipTier),
    ),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Membership Tier',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        walletProvider.membershipTier.displayName,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Cashback: ${walletProvider.membershipTier.cashbackPercentage}%',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white,
        ),
      ),
    ],
  ),
)
```

## Task 15.6: Profile Integration
**Status:** Not Started
**File:** `lib/screens/customer/profile_screen.dart`

### Implementation Steps:
1. [ ] Add wallet balance widget
2. [ ] Add reward points widget
3. [ ] Add membership tier badge
4. [ ] Add quick action buttons
5. [ ] Test layout on various screen sizes

### Code Template:
```dart
// Add to profile screen
Column(
  children: [
    // Wallet Card
    Card(
      child: ListTile(
        leading: Icon(Icons.wallet),
        title: const Text('Wallet Balance'),
        trailing: Text('₹${walletProvider.walletBalance}'),
        onTap: () => context.push('/wallet-history'),
      ),
    ),
    // Reward Points Card
    Card(
      child: ListTile(
        leading: Icon(Icons.stars),
        title: const Text('Reward Points'),
        trailing: Text('${walletProvider.rewardPoints} pts'),
        onTap: () => context.push('/reward-points'),
      ),
    ),
    // Membership Tier Card
    Card(
      child: ListTile(
        leading: Icon(Icons.card_membership),
        title: const Text('Membership Tier'),
        trailing: Text(walletProvider.membershipTier.displayName),
        onTap: () => context.push('/membership-benefits'),
      ),
    ),
  ],
)
```

## Testing Checklist

### Unit Tests
- [ ] Cashback calculation (1% of order)
- [ ] Points calculation (1 point per ₹10)
- [ ] Tier calculation based on spending
- [ ] Points redemption (100 points = ₹50)
- [ ] Wallet balance updates

### Widget Tests
- [ ] Wallet history screen displays correctly
- [ ] Filter chips work
- [ ] Transaction list renders
- [ ] Empty state shows

### Integration Tests
- [ ] Complete order flow with cashback
- [ ] Complete order flow with points
- [ ] Tier upgrade on spending
- [ ] Wallet usage at checkout
- [ ] Points redemption

### Manual Testing
- [ ] Test on Android device
- [ ] Test on iOS device
- [ ] Test with various order amounts
- [ ] Test tier transitions
- [ ] Test offline functionality

## Firebase Firestore Structure

```
users/{userId}
  ├── walletBalance: double
  ├── rewardPoints: int
  ├── membershipTier: string
  └── wallet_transactions/{transactionId}
      ├── type: string (cashback, refund, payment, etc.)
      ├── amount: double
      ├── orderReference: string
      ├── timestamp: datetime
      ├── description: string
      └── balanceAfter: double

users/{userId}/reward_transactions/{transactionId}
  ├── points: int
  ├── description: string
  ├── orderId: string
  └── timestamp: datetime

users/{userId}/tier_history/{upgradeId}
  ├── oldTier: string
  ├── newTier: string
  └── timestamp: datetime
```

## Success Criteria

- [ ] Wallet balance displays correctly
- [ ] Cashback is calculated and added automatically
- [ ] Reward points are awarded on order completion
- [ ] Membership tier updates based on spending
- [ ] Wallet can be used at checkout
- [ ] Transaction history shows all transactions
- [ ] Filtering works correctly
- [ ] All tests pass
- [ ] No critical bugs
- [ ] Performance is optimized

## Estimated Time: 40-50 hours

### Breakdown:
- Checkout integration: 8-10 hours
- Cashback system: 6-8 hours
- Reward points: 6-8 hours
- Membership tiers: 8-10 hours
- Profile integration: 4-6 hours
- Testing: 8-10 hours

## Next Phase
After completing Phase 15, move to Phase 16: Notifications System

