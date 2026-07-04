const pool = require('../db/pool');

/**
 * Shipping Service - Calculate delivery fees based on type and distance
 * Implements: standard, express, scheduled delivery with distance + weight-based pricing
 */
class ShippingService {
  /**
   * Calculate delivery fee for order
   * @param {Object} params
   * @param {string} params.deliveryType - 'standard' | 'express' | 'scheduled'
   * @param {string} params.deliveryAddressId - UUID of delivery address
   * @param {number} params.subtotal - Order subtotal in rupees
   * @param {Array} params.items - Order items with product info
   * @returns {Object} {fee, breakdown, estimatedDeliveryDate}
   */
  static async calculateFee({deliveryType = 'standard', deliveryAddressId, subtotal, items, shopId = null}) {
    try {
      if (!deliveryAddressId) {
        throw new Error('deliveryAddressId required');
      }

      // ✅ FIX: Validate delivery type
      const validDeliveryTypes = ['standard', 'express', 'scheduled'];
      if (!validDeliveryTypes.includes(deliveryType)) {
        throw new Error(`INVALID_DELIVERY_TYPE: ${deliveryType}. Must be one of: ${validDeliveryTypes.join(', ')}`);
      }

      // Fetch delivery address coordinates with validation
      const addressResult = await pool.query(
        `SELECT latitude, longitude FROM users_addresses WHERE id = $1`,
        [deliveryAddressId]
      );

      if (addressResult.rows.length === 0) {
        throw new Error('Delivery address not found');
      }

      const {latitude, longitude} = addressResult.rows[0];

      // ✅ FIX: Validate coordinates exist and are valid numbers
      if (latitude === null || longitude === null) {
        throw new Error('INVALID_ADDRESS: Address coordinates are missing');
      }

      if (typeof latitude !== 'number' || typeof longitude !== 'number' || isNaN(latitude) || isNaN(longitude)) {
        throw new Error('INVALID_COORDINATES: Address has invalid coordinates');
      }

      // ✅ FIX: Fetch shop location from database (don't hardcode)
      let shopLat, shopLon;
      if (shopId) {
        const shopRes = await pool.query(
          `SELECT latitude, longitude FROM shops WHERE id = $1`,
          [shopId]
        );
        if (shopRes.rows.length === 0 || !shopRes.rows[0].latitude || !shopRes.rows[0].longitude) {
          console.warn(`[ShippingService] Shop ${shopId} has no coordinates, using default Delhi location`);
          shopLat = 28.6139;
          shopLon = 77.2090;
        } else {
          shopLat = shopRes.rows[0].latitude;
          shopLon = shopRes.rows[0].longitude;
        }
      } else {
        // Default to Delhi if no shopId provided
        shopLat = 28.6139;
        shopLon = 77.2090;
      }

      // Calculate distance using Haversine formula
      const distanceKm = this.haversineDistance(shopLat, shopLon, latitude, longitude);
      if (isNaN(distanceKm)) {
        throw new Error('DISTANCE_CALCULATION_FAILED');
      }

      // ✅ FIX: Calculate and validate total weight
      const totalWeight = items.reduce((sum, item) => {
        const itemWeight = item.weight_kg || 0.5; // Default 0.5kg per item

        // Validate weight is a positive number
        if (typeof itemWeight !== 'number' || itemWeight < 0) {
          throw new Error(`INVALID_ITEM_WEIGHT: ${itemWeight}`);
        }

        return sum + itemWeight;
      }, 0);

      // ✅ FIX: Add weight limit check
      if (totalWeight > 100) {
        throw new Error(`WEIGHT_EXCEEDS_LIMIT: Order weight ${totalWeight}kg exceeds 100kg limit. Heavy items require special handling.`);
      }

      // Rate structure
      let baseFee = 50;
      let distanceFee = 0;
      let weightFee = 0;

      // ✅ Free shipping for orders > ₹500
      if (subtotal > 500) {
        baseFee = 0;
      }

      // Distance-based fees (in km)
      if (distanceKm <= 2) {
        distanceFee = 0;
      } else if (distanceKm <= 5) {
        distanceFee = 20;
      } else if (distanceKm <= 10) {
        distanceFee = 40;
      } else if (distanceKm <= 25) {
        distanceFee = 60;
      } else {
        distanceFee = 100; // >25km
      }

      // Weight-based fees (in kg)
      if (totalWeight <= 1) {
        weightFee = 0;
      } else if (totalWeight <= 5) {
        weightFee = 20;
      } else if (totalWeight <= 10) {
        weightFee = 50;
      } else {
        weightFee = 100; // >10kg
      }

      // Delivery type multiplier
      let multiplier = 1.0;
      if (deliveryType === 'express') {
        multiplier = 1.5; // 50% extra for express
      } else if (deliveryType === 'scheduled') {
        multiplier = 0.8; // 20% discount for scheduled
      }

      const totalFee = Math.round((baseFee + distanceFee + weightFee) * multiplier);

      // Estimate delivery date
      const estimatedDeliveryDate = this.estimateDeliveryDate(distanceKm, deliveryType);

      console.log(`[ShippingService] Calculated fee: ₹${totalFee}, distance: ${distanceKm.toFixed(2)}km, weight: ${totalWeight}kg, type: ${deliveryType}`);

      return {
        fee: totalFee,
        breakdown: {
          base: baseFee,
          distance: distanceFee,
          weight: weightFee,
          multiplier
        },
        distance: distanceKm,
        weight: totalWeight,
        estimatedDeliveryDate,
      };
    } catch (error) {
      console.error('[ShippingService] Calculate fee failed:', error.message);
      throw error;
    }
  }

  /**
   * Haversine formula: Calculate distance between two lat/lon points
   * @returns {number} Distance in kilometers
   */
  static haversineDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth's radius in km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;

    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  /**
   * Estimate delivery date based on distance and delivery type
   * ✅ FIX: Uses IST (India Standard Time) for calculations
   * @returns {string} ISO 8601 date string
   */
  static estimateDeliveryDate(distanceKm, deliveryType) {
    // ✅ FIX: Convert to IST (UTC+5:30)
    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000; // IST is UTC+5:30
    const nowIST = new Date(now.getTime() + istOffset);

    let deliveryDays = 1;

    // Distance-based estimation
    if (distanceKm < 5) {
      deliveryDays = 0; // Same-day delivery for <5km
    } else if (distanceKm < 15) {
      deliveryDays = 1; // Next day for <15km
    } else if (distanceKm < 30) {
      deliveryDays = 2; // 2 days for <30km
    } else {
      deliveryDays = 3; // 3+ days for >30km
    }

    // Delivery type adjustments
    if (deliveryType === 'express') {
      deliveryDays = Math.max(0, deliveryDays - 1); // 1 day faster
    } else if (deliveryType === 'scheduled') {
      deliveryDays += 1; // 1 day slower (scheduled)
    }

    // Set delivery time to 6 PM IST
    const deliveryDateIST = new Date(nowIST);
    deliveryDateIST.setDate(deliveryDateIST.getDate() + deliveryDays);
    deliveryDateIST.setHours(18, 0, 0, 0);

    // Convert back to UTC for ISO 8601
    const deliveryDateUTC = new Date(deliveryDateIST.getTime() - istOffset);

    return deliveryDateUTC.toISOString();
  }
}

module.exports = ShippingService;
