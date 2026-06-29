/**
 * InventoryTransactionService.js
 * Manages atomic inventory operations with rollback & retry logic
 */

const { admin, db } = require('../firestore');

class InventoryTransactionService {
  /**
   * Validate stock availability before transaction
   * @param {Array} items - [{productId, quantity}]
   * @returns {Object} - {valid, errors, warnings}
   */
  static async validateStockAvailability(items) {
    const errors = [];
    const warnings = [];
    const validatedItems = [];

    for (const item of items) {
      if (!item.productId || typeof item.quantity !== 'number') {
        errors.push(`Invalid item: ${JSON.stringify(item)}`);
        continue;
      }

      if (item.quantity <= 0) {
        errors.push(`Quantity must be > 0 for product ${item.productId}`);
        continue;
      }

      if (item.quantity > 1000000) {
        errors.push(`Quantity too large for product ${item.productId}: ${item.quantity}`);
        continue;
      }

      try {
        const productSnap = await db().collection('products').doc(item.productId).get();
        if (!productSnap.exists) {
          errors.push(`Product not found: ${item.productId}`);
          continue;
        }

        const productData = productSnap.data();
        const availableStock = productData.stockQuantity || 0;

        if (availableStock < item.quantity) {
          warnings.push({
            productId: item.productId,
            productName: productData.name,
            requestedQty: item.quantity,
            availableQty: availableStock,
            shortBy: item.quantity - availableStock,
          });
        }

        validatedItems.push({ ...item, currentStock: availableStock, productName: productData.name });
      } catch (err) {
        errors.push(`Failed to fetch product ${item.productId}: ${err.message}`);
      }
    }

    return {
      valid: errors.length === 0,
      errors,
      warnings,
      validatedItems,
    };
  }

  /**
   * Atomic checkout (deduct stock) with rollback support
   * @param {string} orderId
   * @param {Array} items - [{productId, quantity}]
   * @param {string} userId
   * @param {number} maxRetries - max retry attempts
   * @returns {Object} - {success, message, transactionId, rollback()}
   */
  static async checkoutOrder(orderId, items, userId, maxRetries = 3) {
    // Validate before attempting transaction
    const validation = await this.validateStockAvailability(items);
    if (!validation.valid) {
      return {
        success: false,
        error: 'Validation failed',
        validationErrors: validation.errors,
      };
    }

    if (validation.warnings.length > 0) {
      console.warn(`[Inventory] Warnings for order ${orderId}:`, validation.warnings);
    }

    let lastError = null;
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const transactionId = `${orderId}-${Date.now()}-${attempt}`;
        const firestore = db();
        const FieldValue = admin.firestore.FieldValue;

        const result = await firestore.runTransaction(async (transaction) => {
          const orderRef = firestore.collection('orders').doc(orderId);
          const orderSnap = await transaction.get(orderRef);

          if (!orderSnap.exists) {
            throw new Error(`Order not found: ${orderId}`);
          }

          const orderData = orderSnap.data();

          // ─── Validate order status ─────────────────────────────────────
          const validStatuses = ['OrderStatus.confirmed', 'OrderStatus.processing'];
          if (!validStatuses.includes(orderData.status)) {
            throw new Error(
              `Invalid order status for checkout: ${orderData.status}. Must be one of: ${validStatuses.join(', ')}`
            );
          }

          // ─── Re-validate stock within transaction (for concurrency) ─────
          for (const item of items) {
            const productRef = firestore.collection('products').doc(item.productId);
            const productSnap = await transaction.get(productRef);

            if (!productSnap.exists) {
              throw new Error(`Product deleted mid-transaction: ${item.productId}`);
            }

            const currentStock = productSnap.data().stockQuantity || 0;
            if (currentStock < item.quantity) {
              throw new Error(
                `Insufficient stock for product ${item.productId}. Available: ${currentStock}, Requested: ${item.quantity}`
              );
            }
          }

          // ─── Record inventory events & deduct stock atomically ──────────
          const eventRefs = [];
          for (const item of items) {
            const productRef = firestore.collection('products').doc(item.productId);

            // Deduct from product inventory
            transaction.update(productRef, {
              stockQuantity: FieldValue.increment(-item.quantity),
              lastInventoryUpdateAt: FieldValue.serverTimestamp(),
            });

            // Create inventory ledger entry
            const eventRef = firestore.collection('inventory_events').doc();
            eventRefs.push(eventRef.id);
            transaction.set(eventRef, {
              transaction_id: transactionId,
              product_id: item.productId,
              event_type: 'STOCK_DEDUCTED',
              quantity_change: -item.quantity,
              reference_id: orderId,
              reference_type: 'order',
              actor_id: userId,
              actor_role: 'checkout_service',
              source: 'order_checkout',
              timestamp: FieldValue.serverTimestamp(),
              status: 'COMMITTED',
            });
          }

          // ─── Update order status ───────────────────────────────────────
          transaction.update(orderRef, {
            status: 'OrderStatus.packed',
            packingCompletedAt: FieldValue.serverTimestamp(),
            inventoryTransactionId: transactionId,
            checkoutEventIds: eventRefs,
            updatedAt: FieldValue.serverTimestamp(),
          });

          return { success: true, transactionId };
        });

        console.log(
          `[Inventory] Checkout successful for order ${orderId}. Transaction: ${result.transactionId}, Attempt: ${attempt}`
        );

        return {
          success: true,
          message: `Order ${orderId} checked out successfully`,
          transactionId: result.transactionId,
          itemsDeducted: items.length,
          warnings: validation.warnings,
        };
      } catch (error) {
        lastError = error;
        console.error(`[Inventory] Checkout attempt ${attempt}/${maxRetries} failed for order ${orderId}:`, error.message);

        // Exponential backoff before retry
        if (attempt < maxRetries) {
          const backoffMs = Math.pow(2, attempt) * 100 + Math.random() * 100;
          await new Promise((resolve) => setTimeout(resolve, backoffMs));
        }
      }
    }

    return {
      success: false,
      error: 'Checkout failed after retries',
      lastError: lastError.message,
      attempts: maxRetries,
    };
  }

  /**
   * Atomic check-in (restore stock) for returns/cancellations
   * @param {string} orderId
   * @param {string} reason - Return reason
   * @param {string} userId
   * @returns {Object} - {success, message}
   */
  static async checkinOrder(orderId, reason = 'System check-in', userId) {
    try {
      const firestore = db();
      const FieldValue = admin.firestore.FieldValue;
      const transactionId = `RETURN-${orderId}-${Date.now()}`;

      const result = await firestore.runTransaction(async (transaction) => {
        const orderRef = firestore.collection('orders').doc(orderId);
        const orderSnap = await transaction.get(orderRef);

        if (!orderSnap.exists) {
          throw new Error(`Order not found: ${orderId}`);
        }

        const orderData = orderSnap.data();
        const eventRefs = [];

        // ─── Restore stock for each item ────────────────────────────────
        for (const item of orderData.items || []) {
          const productRef = firestore.collection('products').doc(item.productId);

          // Restore stock
          transaction.update(productRef, {
            stockQuantity: FieldValue.increment(item.quantity),
            lastInventoryUpdateAt: FieldValue.serverTimestamp(),
          });

          // Create inventory event
          const eventRef = firestore.collection('inventory_events').doc();
          eventRefs.push(eventRef.id);
          transaction.set(eventRef, {
            transaction_id: transactionId,
            product_id: item.productId,
            event_type: 'STOCK_RESTORED',
            quantity_change: item.quantity,
            reference_id: orderId,
            reference_type: 'order_return',
            actor_id: userId,
            source: 'order_recovery',
            return_reason: reason,
            timestamp: FieldValue.serverTimestamp(),
            status: 'COMMITTED',
          });
        }

        // ─── Update order status to returned ────────────────────────────
        transaction.update(orderRef, {
          status: 'OrderStatus.returned',
          returnReason: reason,
          checkinTransactionId: transactionId,
          checkinEventIds: eventRefs,
          returnedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        return { success: true, transactionId, itemsRestored: (orderData.items || []).length };
      });

      console.log(
        `[Inventory] Check-in successful for order ${orderId}. Transaction: ${result.transactionId}, Items restored: ${result.itemsRestored}`
      );

      return {
        success: true,
        message: `Order ${orderId} items restored to inventory`,
        transactionId: result.transactionId,
        itemsRestored: result.itemsRestored,
      };
    } catch (error) {
      console.error(`[Inventory] Check-in failed for order ${orderId}:`, error.message);
      return {
        success: false,
        error: error.message,
      };
    }
  }

  /**
   * Get inventory audit trail for an order
   * @param {string} orderId
   * @returns {Object} - {events, timeline}
   */
  static async getOrderInventoryAudit(orderId) {
    try {
      const events = await db()
        .collection('inventory_events')
        .where('reference_id', '==', orderId)
        .orderBy('timestamp', 'desc')
        .get();

      const eventDocs = events.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));

      const timeline = eventDocs.map((e) => ({
        timestamp: e.timestamp?.toDate?.() || new Date(e.timestamp),
        event: e.event_type,
        product: e.product_id,
        quantity: e.quantity_change,
        transactionId: e.transaction_id,
      }));

      return {
        success: true,
        orderId,
        totalEvents: eventDocs.length,
        events: eventDocs,
        timeline,
      };
    } catch (error) {
      console.error(`[Inventory] Failed to fetch audit for order ${orderId}:`, error);
      return {
        success: false,
        error: error.message,
      };
    }
  }
}

module.exports = InventoryTransactionService;
