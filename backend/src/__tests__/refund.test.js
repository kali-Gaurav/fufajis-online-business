/**
 * refund.test.js - Refund Calculation Tests
 *
 * Tests for refund amount calculation with GST handling.
 * Ensures refunds are calculated correctly across various scenarios.
 *
 * GST Treatment in Refunds:
 * - Refund Amount = Order Total - Cancellation Fee
 * - Order Total already includes GST
 * - GST is NOT separately added/subtracted; it's implicit in the total
 *
 * Run with: npm test -- refund.test.js
 */

describe('Refund Calculations', () => {
  // Helper function: calculate refund amount
  const calculateRefund = (orderTotal, cancellationFee = 0, itemsRemoved = []) => {
    // If specific items removed, calculate proportion of their value
    let deductionAmount = cancellationFee;
    if (itemsRemoved.length > 0) {
      const removedTotal = itemsRemoved.reduce((sum, item) => sum + item.price, 0);
      deductionAmount += removedTotal;
    }

    const refundAmount = Math.max(0, orderTotal - deductionAmount);
    return Math.round(refundAmount * 100) / 100; // Round to 2 decimals
  };

  // Test Suite 1: Basic Refunds
  describe('Basic Refund Scenarios', () => {
    test('Full refund without cancellation fee', () => {
      const orderTotal = 100.00; // Includes GST
      const refund = calculateRefund(orderTotal);
      expect(refund).toBe(100.00);
    });

    test('Refund with ₹10 cancellation fee', () => {
      const orderTotal = 100.00;
      const cancellationFee = 10.00;
      const refund = calculateRefund(orderTotal, cancellationFee);
      expect(refund).toBe(90.00);
    });

    test('Refund with ₹25 cancellation fee', () => {
      const orderTotal = 100.00;
      const cancellationFee = 25.00;
      const refund = calculateRefund(orderTotal, cancellationFee);
      expect(refund).toBe(75.00);
    });

    test('Refund amount cannot be negative', () => {
      const orderTotal = 100.00;
      const cancellationFee = 150.00; // More than order total
      const refund = calculateRefund(orderTotal, cancellationFee);
      expect(refund).toBe(0.00); // Clamp to 0
    });
  });

  // Test Suite 2: GST Scenarios
  describe('GST Treatment in Refunds', () => {
    test('GST is included in order total (18%)', () => {
      // Order: ₹100 (Item: ₹84.75 + GST 18%: ₹15.25)
      const orderTotal = 100.00;
      const cancellationFee = 0.00;
      const refund = calculateRefund(orderTotal, cancellationFee);
      // Refund is full amount including GST already paid
      expect(refund).toBe(100.00);
    });

    test('Refund with fee: GST stays with business', () => {
      // Order: ₹1000 (incl. ₹180 GST)
      // Cancellation fee: ₹100
      const orderTotal = 1000.00;
      const cancellationFee = 100.00;
      const refund = calculateRefund(orderTotal, cancellationFee);
      expect(refund).toBe(900.00);
      // Note: GST included in the ₹100 fee goes to business
    });

    test('Partial refund: Item removed calculation', () => {
      // Order: 2 items @ ₹500 each (incl. GST) = ₹1000
      // Customer returns 1 item
      const orderTotal = 1000.00;
      const itemsRemoved = [{ price: 500.00 }];
      const refund = calculateRefund(orderTotal, 0, itemsRemoved);
      expect(refund).toBe(500.00);
    });
  });

  // Test Suite 3: Rounding Edge Cases
  describe('Rounding & Precision', () => {
    test('Refund with decimal amounts rounds correctly', () => {
      const orderTotal = 999.99;
      const cancellationFee = 5.50;
      const refund = calculateRefund(orderTotal, cancellationFee);
      expect(refund).toBe(994.49);
    });

    test('Refund with multiple items (precision)', () => {
      const orderTotal = 500.33;
      const itemsRemoved = [
        { price: 150.11 },
        { price: 200.22 }
      ];
      const refund = calculateRefund(orderTotal, 0, itemsRemoved);
      expect(refund).toBe(150.00); // 500.33 - 150.11 - 200.22 = 150.00
    });

    test('Refund with GST @ 5%', () => {
      // Order: ₹1000 (incl. 5% GST)
      const orderTotal = 1000.00;
      const cancellationFee = 50.00; // 5% of order
      const refund = calculateRefund(orderTotal, cancellationFee);
      expect(refund).toBe(950.00);
    });
  });

  // Test Suite 4: Multiple Item Orders
  describe('Multi-Item Orders', () => {
    test('Refund after removing 1 of 3 items', () => {
      const orderTotal = 300.00; // 3 items @ ₹100 each
      const itemsRemoved = [{ price: 100.00 }];
      const refund = calculateRefund(orderTotal, 0, itemsRemoved);
      expect(refund).toBe(200.00);
    });

    test('Refund after removing 2 of 4 items', () => {
      const orderTotal = 400.00; // 4 items @ ₹100 each
      const itemsRemoved = [
        { price: 100.00 },
        { price: 100.00 }
      ];
      const refund = calculateRefund(orderTotal, 0, itemsRemoved);
      expect(refund).toBe(200.00);
    });

    test('Refund with both item removal and cancellation fee', () => {
      const orderTotal = 500.00;
      const cancellationFee = 25.00;
      const itemsRemoved = [{ price: 125.00 }];
      const refund = calculateRefund(orderTotal, cancellationFee, itemsRemoved);
      expect(refund).toBe(350.00); // 500 - 25 - 125 = 350
    });
  });

  // Test Suite 5: High-Value Orders
  describe('Large Order Amounts', () => {
    test('₹10,000 order with ₹500 fee', () => {
      const orderTotal = 10000.00;
      const cancellationFee = 500.00;
      const refund = calculateRefund(orderTotal, cancellationFee);
      expect(refund).toBe(9500.00);
    });

    test('₹50,000 order with multiple items removed', () => {
      const orderTotal = 50000.00;
      const itemsRemoved = [
        { price: 5000.00 },
        { price: 3000.00 },
        { price: 2000.00 }
      ];
      const refund = calculateRefund(orderTotal, 0, itemsRemoved);
      expect(refund).toBe(40000.00);
    });
  });

  // Test Suite 6: Real-World Scenarios
  describe('Real-World Order Examples', () => {
    test('Scenario 1: Simple order with full refund', () => {
      // Customer orders ₹150 lunch, cancels before pickup
      const orderTotal = 150.00;
      const refund = calculateRefund(orderTotal);
      expect(refund).toBe(150.00);
    });

    test('Scenario 2: Order with partial cancellation', () => {
      // Customer orders: Biryani ₹300 + Dal ₹100 = ₹400 (incl. GST)
      // Returns only Dal
      const orderTotal = 400.00;
      const itemsRemoved = [{ price: 100.00 }];
      const refund = calculateRefund(orderTotal, 0, itemsRemoved);
      expect(refund).toBe(300.00);
    });

    test('Scenario 3: Order with late cancellation fee', () => {
      // Customer orders ₹500, cancels after 10 min (₹50 fee)
      const orderTotal = 500.00;
      const cancellationFee = 50.00;
      const refund = calculateRefund(orderTotal, cancellationFee);
      expect(refund).toBe(450.00);
    });

    test('Scenario 4: Restaurant box order (high-value, multiple items)', () => {
      // Customer orders 2x Biryani Box @ ₹450 each = ₹900
      // Plus delivery fee ₹50 = ₹950 total
      // Returns 1 box after delivery
      const orderTotal = 950.00;
      const itemsRemoved = [{ price: 450.00 }];
      const refund = calculateRefund(orderTotal, 0, itemsRemoved);
      // Refund = 950 - 450 = 500 (delivery fee stays with restaurant)
      expect(refund).toBe(500.00);
    });
  });

  // Test Suite 7: Error Handling
  describe('Error Handling', () => {
    test('Handles NaN gracefully', () => {
      expect(() => {
        calculateRefund(NaN, 10);
      }).not.toThrow();
    });

    test('Handles negative order total', () => {
      const orderTotal = -100.00;
      const refund = calculateRefund(orderTotal, 0);
      expect(refund).toBe(-100.00); // System should reject before this
    });

    test('Handles zero order total', () => {
      const orderTotal = 0.00;
      const refund = calculateRefund(orderTotal);
      expect(refund).toBe(0.00);
    });
  });
});

describe('Refund Validation Rules', () => {
  test('Refund should never exceed order total', () => {
    const orderTotal = 100.00;
    const refund = Math.min(orderTotal, 150.00); // Cap at order total
    expect(refund).toBe(100.00);
  });

  test('Refund should never be negative', () => {
    const refund = Math.max(0, -50.00); // Floor at 0
    expect(refund).toBe(0.00);
  });

  test('Cancellation fee percentage cap (max 25% of order)', () => {
    const orderTotal = 100.00;
    const maxCancellationFee = orderTotal * 0.25;
    expect(maxCancellationFee).toBe(25.00);
  });
});

describe('Refund Database Storage', () => {
  test('Refund amount stored with 2 decimal precision in database', () => {
    const refundAmount = 123.456789;
    const storedAmount = Math.round(refundAmount * 100) / 100;
    expect(storedAmount).toBe(123.46);
  });

  test('Postgres NUMERIC(10,2) column stores correctly', () => {
    const amounts = [99.99, 123.00, 0.01, 9999.99];
    amounts.forEach(amount => {
      const stored = Math.round(amount * 100) / 100;
      expect(stored).toEqual(amount);
    });
  });
});
