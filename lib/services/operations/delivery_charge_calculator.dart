class DeliveryChargeCalculator {
  // Base constants - could be fetched from Firebase Remote Config
  static const double baseFee = 20.0;
  static const double freeDeliveryThreshold = 500.0;
  static const double perKmRate = 10.0;
  static const double perKgRate = 5.0;

  /// Calculates the delivery charge based on distance, weight, and surge conditions.
  static double calculate({
    required double cartTotal,
    required double distanceKm,
    required double totalWeightKg,
    bool isSurgeHour = false,
  }) {
    // Free delivery over a certain threshold
    if (cartTotal >= freeDeliveryThreshold) {
      return 0.0;
    }

    double fee = baseFee;

    // Distance fee: First 2km free, then 10/km
    if (distanceKm > 2.0) {
      fee += (distanceKm - 2.0) * perKmRate;
    }

    // Weight fee: First 5kg free, then 5/kg
    if (totalWeightKg > 5.0) {
      fee += (totalWeightKg - 5.0) * perKgRate;
    }

    // Surge pricing (weather, high demand, late night)
    if (isSurgeHour) {
      fee *= 1.5;
    }

    return fee.roundToDouble();
  }
}
