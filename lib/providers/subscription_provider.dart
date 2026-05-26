import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_model.dart';

class SubscriptionProvider with ChangeNotifier {
  List<SubscriptionModel> _subscriptions = [];
  bool _isLoading = false;

  List<SubscriptionModel> get subscriptions => _subscriptions;
  bool get isLoading => _isLoading;

  /// Loads subscriptions for the active customer
  Future<void> loadSubscriptions(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> rawList = prefs.getStringList('customer_subscriptions_$userId') ?? [];
      
      _subscriptions = rawList
          .map((item) => SubscriptionModel.fromMap(json.decode(item)))
          .toList();
    } catch (e) {
      debugPrint('Error loading subscriptions: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Alias for loadSubscriptions to maintain compatibility
  Future<void> fetchSubscriptions(String userId) => loadSubscriptions(userId);

  /// Creates a new essentials subscription
  Future<bool> createSubscription({
    required String customerId,
    required String productId,
    required String productName,
    required String productImage,
    required String unit,
    required double price,
    required int quantity,
    required SubscriptionFrequency frequency,
    required DateTime startDate,
    required String timeSlot,
  }) async {
    final newSubscription = SubscriptionModel(
      id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
      customerId: customerId,
      productId: productId,
      productName: productName,
      productImage: productImage,
      unit: unit,
      price: price,
      quantity: quantity,
      frequency: frequency,
      status: SubscriptionStatus.active,
      startDate: startDate,
      timeSlot: timeSlot,
      createdAt: DateTime.now(),
    );

    _subscriptions.insert(0, newSubscription);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> rawList = _subscriptions
          .map((item) => json.encode(item.toMap()))
          .toList();
      await prefs.setStringList('customer_subscriptions_$customerId', rawList);
      return true;
    } catch (e) {
      debugPrint('Error saving subscription: $e');
      return false;
    }
  }

  /// Pauses or cancels an active subscription
  Future<void> updateSubscriptionStatus(String subscriptionId, SubscriptionStatus status) async {
    final index = _subscriptions.indexWhere((sub) => sub.id == subscriptionId);
    if (index >= 0) {
      final updated = _subscriptions[index].copyWith(status: status);
      _subscriptions[index] = updated;
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        final List<String> rawList = _subscriptions
            .map((item) => json.encode(item.toMap()))
            .toList();
        await prefs.setStringList('customer_subscriptions_${updated.customerId}', rawList);
      } catch (e) {
        debugPrint('Error updating subscription status: $e');
      }
    }
  }

  /// Activates vacation mode: pauses all subscriptions until a date (Feature 14)
  Future<void> setVacationMode(String userId, DateTime until) async {
    _isLoading = true;
    notifyListeners();

    for (int i = 0; i < _subscriptions.length; i++) {
      if (_subscriptions[i].status == SubscriptionStatus.active) {
        _subscriptions[i] = _subscriptions[i].copyWith(pauseUntil: until);
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> rawList = _subscriptions
          .map((item) => json.encode(item.toMap()))
          .toList();
      await prefs.setStringList('customer_subscriptions_$userId', rawList);
    } catch (e) {
      debugPrint('Error setting vacation mode: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Returns active deliveries for a specific date (Calendar logic)
  List<SubscriptionModel> getDeliveriesForDate(DateTime date) {
    return _subscriptions.where((sub) {
      if (!sub.isActive) return false;
      
      // Vacation check
      if (sub.pauseUntil != null && date.isBefore(sub.pauseUntil!)) return false;

      // Frequency check
      switch (sub.frequency) {
        case SubscriptionFrequency.daily:
          return true;
        case SubscriptionFrequency.weekly:
          return sub.startDate.weekday == date.weekday;
        case SubscriptionFrequency.alternateDays:
          return date.difference(sub.startDate).inDays % 2 == 0;
        case SubscriptionFrequency.custom:
          return sub.deliveryDates.any((d) => 
            d.year == date.year && d.month == date.month && d.day == date.day);
      }
    }).toList();
  }
}
