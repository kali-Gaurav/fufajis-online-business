import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

const db = admin.firestore();

/**
 * Process refund with stock restoration
 *
 * When an order is refunded:
 * 1. Restore stock for each item to the product inventory
 * 2. Credit wallet balance to customer
 * 3. Mark order as refunded with timestamp
 * 4. Create refund transaction record for audit
 *
 * This ensures inventory consistency when orders are cancelled/refunded.
 */
export const processRefundWithStockRestore = functions.https.onCall(
  async (data: {
    orderId: string;
    refundAmount: number;
    reason?: string;
  }, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const { orderId, refundAmount, reason = 'Customer requested refund' } = data;

    // Validate inputs
    if (!orderId || typeof orderId !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'orderId must be a non-empty string'
      );
    }

    if (typeof refundAmount !== 'number' || refundAmount <= 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'refundAmount must be a positive number'
      );
    }

    try {
      // Verify user is admin or order owner
      const orderRef = db.collection('orders').doc(orderId);
      const orderSnapshot = await orderRef.get();

      if (!orderSnapshot.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          `Order ${orderId} not found`
        );
      }

      const orderData = orderSnapshot.data()!;
      const customerId = orderData.customerId;
      const orderStatus = orderData.status;

      // Authorization check
      const userDoc = await db.collection('users').doc(context.auth.uid).get();
      const userRole = userDoc.data()?.role;
      const isAdmin =
        userRole === 'admin' || userRole === 'UserRole.admin';
      const isOrderOwner = customerId === context.auth.uid;
      const isEmployee =
        userRole === 'employee' || userRole === 'UserRole.employee';

      if (!isAdmin && !isOrderOwner && !isEmployee) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Only admin, employee, or order owner can process refunds'
        );
      }

      // Verify order can be refunded
      if (orderStatus === 'refunded' || orderStatus === 'OrderStatus.refunded') {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Order has already been refunded'
        );
      }

      // ======================================================================
      // BEGIN TRANSACTION: Restore stock + credit wallet + mark refunded
      // ======================================================================
      const result = await db.runTransaction(async (transaction) => {
        // 1. Restore stock for each item
        const items = orderData.items || [];
        const shopId = orderData.shopId || 'primary';

        for (const item of items) {
          const productId = item.productId;
          const quantity = item.quantity;

          if (!productId || !quantity) {
            functions.logger.warn(
              `[processRefundWithStockRestore] Invalid item in order ${orderId}:`,
              item
            );
            continue;
          }

          const productRef = db.collection('products').doc(productId);
          const productSnapshot = await transaction.get(productRef);

          if (!productSnapshot.exists) {
            functions.logger.warn(
              `[processRefundWithStockRestore] Product ${productId} not found for restoring stock`
            );
            continue;
          }

          const productData = productSnapshot.data()!;
          const branchStockMap = productData.branchStock || {};
          let currentStock = 0;

          if (branchStockMap[shopId]) {
            currentStock = branchStockMap[shopId] as number;
          } else if (shopId === 'primary' || Object.keys(branchStockMap).length === 0) {
            currentStock = productData.stockQuantity || 0;
          }

          // Restore stock
          const restoredStock = currentStock + quantity;
          const updatedBranchStock = { ...branchStockMap };
          updatedBranchStock[shopId] = restoredStock;

          // Calculate new global stock
          let newGlobalStock = 0;
          if (updatedBranchStock['primary']) {
            newGlobalStock = updatedBranchStock['primary'] as number;
          } else {
            newGlobalStock = Object.values(updatedBranchStock).reduce(
              (sum, val) => sum + (typeof val === 'number' ? val : 0),
              0
            );
          }

          // Update product
          transaction.update(productRef, {
            branchStock: updatedBranchStock,
            stockQuantity: newGlobalStock,
            isAvailable: newGlobalStock > 0,
            lastStockUpdate: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Record restoration event
          const eventRef = db.collection('inventory_events').doc();
          transaction.set(eventRef, {
            id: eventRef.id,
            type: 'stock_restoration',
            productId,
            orderId,
            quantity,
            shopId,
            stockBefore: currentStock,
            stockAfter: restoredStock,
            reason: 'Order refunded',
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            performedBy: context.auth!.uid,
          });

          functions.logger.info(
            `[processRefundWithStockRestore] Restored ${quantity} units for product ${productId}`
          );
        }

        // 2. Credit wallet balance to customer
        const userRef = db.collection('users').doc(customerId);
        const userSnapshot = await transaction.get(userRef);

        if (userSnapshot.exists) {
          const userData = userSnapshot.data()!;
          const currentBalance = (userData.walletBalance || 0) as number;
          const newBalance = currentBalance + refundAmount;

          transaction.update(userRef, {
            walletBalance: newBalance,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Create wallet transaction record
          const txnRef = db
            .collection('users')
            .doc(customerId)
            .collection('wallet_transactions')
            .doc();

          transaction.set(txnRef, {
            id: txnRef.id,
            userId: customerId,
            type: 'WalletTransactionType.refund',
            amount: refundAmount,
            orderReference: orderId,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            description: `Refund for order #${orderData.orderNumber}`,
            balanceAfter: newBalance,
            reason,
          });

          functions.logger.info(
            `[processRefundWithStockRestore] Credited ${refundAmount} to wallet for customer ${customerId}`
          );
        } else {
          functions.logger.warn(
            `[processRefundWithStockRestore] Customer ${customerId} not found`
          );
        }

        // 3. Mark order as refunded
        transaction.update(orderRef, {
          status: 'refunded',
          refundedAt: admin.firestore.FieldValue.serverTimestamp(),
          refundAmount,
          refundReason: reason,
          refundProcessedBy: context.auth!.uid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 4. Create refund audit log
        const auditRef = db.collection('refund_logs').doc();
        transaction.set(auditRef, {
          id: auditRef.id,
          orderId,
          customerId,
          refundAmount,
          reason,
          itemCount: items.length,
          processedBy: context.auth!.uid,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          status: 'completed',
        });

        return {
          success: true,
          orderId,
          customerId,
          refundAmount,
          itemsRestored: items.length,
        };
      });

      return result;
    } catch (error: any) {
      functions.logger.error(
        `[processRefundWithStockRestore] Error processing refund for order ${orderId}:`,
        error
      );

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        'internal',
        `Failed to process refund: ${error.message || 'Unknown error'}`
      );
    }
  }
);
