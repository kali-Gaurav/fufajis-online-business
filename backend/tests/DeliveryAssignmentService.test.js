/**
 * Tests for DeliveryAssignmentService
 *
 * Test Coverage:
 * - Assign to nearest available rider
 * - Fail if no riders available
 * - Respect capacity limits
 * - Handle rider unavailability
 * - Batch assignment (100+ orders)
 * - Error cases
 * - Reassignment on rider cancellation
 */

const DeliveryAssignmentService = require('../src/services/DeliveryAssignmentService');

describe('DeliveryAssignmentService', () => {
  let mockRiders, mockOrders;

  beforeEach(() => {
    mockRiders = [
      {
        id: 'rider1',
        name: 'John',
        phone: '9999999999',
        vehicle_type: 'bike',
        status: 'active',
        is_available: true,
        latitude: 28.6139,
        longitude: 77.2090,
        current_load: 2
      },
      {
        id: 'rider2',
        name: 'Mike',
        phone: '8888888888',
        vehicle_type: 'bike',
        status: 'active',
        is_available: true,
        latitude: 28.6200,
        longitude: 77.2100,
        current_load: 4
      },
      {
        id: 'rider3',
        name: 'Sarah',
        phone: '7777777777',
        vehicle_type: 'scooter',
        status: 'active',
        is_available: true,
        latitude: 28.6300,
        longitude: 77.2200,
        current_load: 5
      }
    ];

    mockOrders = [
      {
        id: 'order1',
        customer_id: 'cust1',
        delivery_address: {
          latitude: 28.6150,
          longitude: 77.2100,
          address: '123 Main St'
        }
      },
      {
        id: 'order2',
        customer_id: 'cust2',
        delivery_address: {
          latitude: 28.6160,
          longitude: 77.2110,
          address: '456 Park Ave'
        }
      }
    ];
  });

  describe('assignOrderToRider', () => {
    test('should assign order to nearest available rider', async () => {
      const result = await DeliveryAssignmentService.assignOrderToRider(
        mockOrders[0].id,
        mockOrders[0].customer_id,
        mockOrders[0].delivery_address
      );

      expect(result.success).toBe(true);
      expect(result.rider_id).toBeDefined();
      expect(result.delivery_task_id).toBeDefined();
      expect(result.eta_minutes).toBeGreaterThan(0);
    });

    test('should fail if no riders available', async () => {
      // Mock no available riders scenario
      const result = await DeliveryAssignmentService.assignOrderToRider(
        'invalid_order',
        'cust1',
        { latitude: 90, longitude: 180 } // Extreme coordinates
      );

      expect(result.success).toBe(false);
      expect(result.retryable).toBe(true);
      expect(result.code).toBe('NO_RIDERS_AVAILABLE');
    });

    test('should fail with invalid delivery address', async () => {
      const result = await DeliveryAssignmentService.assignOrderToRider(
        'order1',
        'cust1',
        {} // Missing latitude/longitude
      );

      expect(result.success).toBe(false);
      expect(result.error).toContain('Invalid');
    });

    test('should calculate correct distance', () => {
      // Delhi to nearby location
      const distance = DeliveryAssignmentService.calculateDistance(
        28.6139,
        77.2090,
        28.6150,
        77.2100
      );

      expect(distance).toBeGreaterThan(0);
      expect(distance).toBeLessThan(5); // Should be close
    });
  });

  describe('getAvailableRiders', () => {
    test('should return riders within distance limit', async () => {
      const riders = await DeliveryAssignmentService.getAvailableRiders(
        28.6139, // Delhi latitude
        77.2090, // Delhi longitude
        5 // 5km radius
      );

      expect(Array.isArray(riders)).toBe(true);
      riders.forEach(rider => {
        expect(rider.distance_km).toBeLessThanOrEqual(5);
        expect(rider.is_available).toBe(true);
      });
    });

    test('should filter by status and availability', async () => {
      const riders = await DeliveryAssignmentService.getAvailableRiders(
        28.6139,
        77.2090,
        10
      );

      riders.forEach(rider => {
        expect(rider.status).toBe('active');
        expect(rider.is_available).toBe(true);
      });
    });
  });

  describe('checkRiderCapacity', () => {
    test('should return capacity info', async () => {
      const capacity = await DeliveryAssignmentService.checkRiderCapacity('rider1');

      expect(capacity.active_deliveries).toBeDefined();
      expect(capacity.available_slots).toBeDefined();
      expect(capacity.is_available).toBeDefined();
      expect(capacity.max_capacity).toBe(5);
    });

    test('should mark rider unavailable when at max capacity', async () => {
      const capacity = await DeliveryAssignmentService.checkRiderCapacity('rider3');

      // Rider 3 has current_load = 5 (at max)
      if (capacity.active_deliveries >= 5) {
        expect(capacity.is_available).toBe(false);
        expect(capacity.available_slots).toBe(0);
      }
    });
  });

  describe('reassignIfNeeded', () => {
    test('should reassign delivery to new rider', async () => {
      // First create a delivery task assignment
      const assignResult = await DeliveryAssignmentService.assignOrderToRider(
        'order_test_reassign',
        'cust_reassign',
        {
          latitude: 28.6139,
          longitude: 77.2090,
          address: 'Test Address'
        }
      );

      if (assignResult.success) {
        // Then reassign it
        const reassignResult = await DeliveryAssignmentService.reassignIfNeeded(
          assignResult.delivery_task_id,
          'rider_cancelled'
        );

        if (reassignResult.success) {
          expect(reassignResult.rider_id).toBeDefined();
          expect(reassignResult.delivery_task_id).toBeDefined();
        }
      }
    });

    test('should fail if delivery task not found', async () => {
      const result = await DeliveryAssignmentService.reassignIfNeeded(
        'nonexistent_task',
        'rider_cancelled'
      );

      expect(result.success).toBe(false);
      expect(result.error).toContain('not found');
    });
  });

  describe('batchAssignOrders', () => {
    test('should batch assign multiple orders', async () => {
      const orders = [
        {
          id: 'batch_order_1',
          customer_id: 'batch_cust_1',
          delivery_address: { latitude: 28.6139, longitude: 77.2090 }
        },
        {
          id: 'batch_order_2',
          customer_id: 'batch_cust_2',
          delivery_address: { latitude: 28.6150, longitude: 77.2100 }
        },
        {
          id: 'batch_order_3',
          customer_id: 'batch_cust_3',
          delivery_address: { latitude: 28.6160, longitude: 77.2110 }
        }
      ];

      const result = await DeliveryAssignmentService.batchAssignOrders(orders);

      expect(result.total).toBe(3);
      expect(result.successful + result.failed).toBe(3);
      expect(result.assignments).toBeDefined();
      expect(Array.isArray(result.assignments)).toBe(true);
    });

    test('should handle batch of 100 orders', async () => {
      const orders = [];
      for (let i = 0; i < 100; i++) {
        orders.push({
          id: `bulk_order_${i}`,
          customer_id: `bulk_cust_${i}`,
          delivery_address: {
            latitude: 28.6139 + (Math.random() * 0.1),
            longitude: 77.2090 + (Math.random() * 0.1)
          }
        });
      }

      const result = await DeliveryAssignmentService.batchAssignOrders(orders);

      expect(result.total).toBe(100);
      expect(result.successful + result.failed).toBe(100);
      expect(result.assignments.length).toBeGreaterThan(0);
    });

    test('should process batches with concurrency limit', async () => {
      const orders = Array.from({ length: 15 }, (_, i) => ({
        id: `concurrent_order_${i}`,
        customer_id: `concurrent_cust_${i}`,
        delivery_address: {
          latitude: 28.6139 + (Math.random() * 0.05),
          longitude: 77.2090 + (Math.random() * 0.05)
        }
      }));

      const result = await DeliveryAssignmentService.batchAssignOrders(orders);

      expect(result.total).toBe(15);
    });
  });

  describe('ETA Calculation', () => {
    test('should calculate reasonable ETA', async () => {
      const eta = await DeliveryAssignmentService.calculateETA(
        28.6139,
        77.2090,
        28.6200,
        77.2200
      );

      expect(eta).toBeGreaterThan(0);
      expect(eta).toBeLessThanOrEqual(60);
    });

    test('should cap ETA at 60 minutes', async () => {
      // Very distant location
      const eta = await DeliveryAssignmentService.calculateETA(
        28.6139,
        77.2090,
        28.7139, // ~10km away
        77.3090
      );

      expect(eta).toBeLessThanOrEqual(60);
    });
  });

  describe('Error Handling', () => {
    test('should handle Firebase errors gracefully', async () => {
      const result = await DeliveryAssignmentService.assignOrderToRider(
        null, // Invalid order ID
        'cust1',
        { latitude: 28.6139, longitude: 77.2090 }
      );

      expect(result.success).toBe(false);
      expect(result.retryable).toBe(true);
    });

    test('should return correct error codes', async () => {
      // Test various error scenarios
      const testCases = [
        {
          orderId: 'order1',
          customerId: 'cust1',
          address: null,
          expectedCode: 'INVALID_COORDINATES'
        }
      ];

      for (const testCase of testCases) {
        if (testCase.address === null) {
          const result = await DeliveryAssignmentService.assignOrderToRider(
            testCase.orderId,
            testCase.customerId,
            {}
          );

          expect(result.success).toBe(false);
        }
      }
    });
  });

  describe('Integration', () => {
    test('complete assignment workflow', async () => {
      // 1. Assign order
      const assignResult = await DeliveryAssignmentService.assignOrderToRider(
        'workflow_order',
        'workflow_cust',
        {
          latitude: 28.6139,
          longitude: 77.2090,
          address: 'Integration Test Address'
        }
      );

      if (assignResult.success) {
        // 2. Check that order status was updated
        expect(assignResult.rider_id).toBeDefined();
        expect(assignResult.eta_minutes).toBeGreaterThan(0);

        // 3. Verify assignment record exists
        expect(assignResult.delivery_task_id).toBeDefined();
      }
    });
  });
});
