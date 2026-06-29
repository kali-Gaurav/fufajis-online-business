import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

const db = admin.firestore();

const LOCK_TIMEOUT_MS = 30000; // 30 seconds
const LOCK_COLLECTION = 'product_locks';

/**
 * Atomic inventory deduction with pessimistic locking
 *
 * Solves the race condition where two concurrent orders can both read stock=5,
 * both pass validation, and both deduct, resulting in negative inventory.
 *
 * This function:
 * 1. Acquires a lock on the product (blocks other transactions)
 * 2. Reads current stock (guaranteed fresh, no stale reads)
 * 3. Validates sufficient stock
 * 4. Deducts inventory atomically
 * 5. Releases lock
 *
 * If lock is held, caller receives 'Product locked by another transaction' error
 */
export const deductInventoryAtomic = functions.https.onCall(
  async (data: {
    productId: string;
    quantity: number;
    orderId: string;
    shopId?: string;
  }, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const { productId, quantity, orderId, shopId = 'primary' } = data;

    // Validate inputs
    if (!productId || typeof productId !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'productId must be a non-empty string'
      );
    }

    if (!quantity || typeof quantity !== 'number' || quantity <= 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'quantity must be a positive number'
      );
    }

    if (!orderId || typeof orderId !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'orderId must be a non-empty string'
      );
    }

    const lockRef = db.collection(LOCK_COLLECTION).doc(productId);
    const productRef = db.collection('products').doc(productId);

    try {
      // ========================================================================
      // PHASE 1: ACQUIRE LOCK
      // ========================================================================
      const lockSnapshot = await lockRef.get();
      const now = Date.now();

      if (lockSnapshot.exists) {
        const lockData = lockSnapshot.data();
        const lockTimestamp = lockData?.timestamp || 0;
        const isLockExpired = now - lockTimestamp > LOCK_TIMEOUT_MS;

        // Lock is held by another transaction and hasn't expired
        if (!isLockExpired && lockData?.locked === true) {
          throw new functions.https.HttpsError(
            'resource-exhausted',
            `Product locked by another transaction. Lock held by order: ${lockData?.orderId || 'unknown'}`
          );
        }

        // Lock has expired - forcibly release it (stale lock recovery)
        functions.logger.warn(
          `[deductInventoryAtomic] Stale lock detected for product ${productId}, releasing...`
        );
      }

      // Set lock atomically
      await lockRef.set({
        locked: true,
        orderId,
        timestamp: now,
        acquiredBy: context.auth.uid,
      });

      functions.logger.info(
        `[deductInventoryAtomic] Lock acquired for product ${productId}, order ${orderId}`
      );

      // ========================================================================
      // PHASE 2: READ STOCK WITHIN TRANSACTION (guaranteed fresh)
      // ========================================================================
      const result = await db.runTransaction(async (transaction) => {
        // Read product document (within transaction)
        const productSnapshot = await transaction.get(productRef);

        if (!productSnapshot.exists) {
          throw new functions.https.HttpsError(
            'not-found',
            `Product ${productId} not found in inventory`
          );
        }

        const productData = productSnapshot.data()!;

        // Get current stock for the branch
        const branchStockMap = productData.branchStock || {};
        let currentStock = 0;

        if (branchStockMap[shopId]) {
          currentStock = branchStockMap[shopId] as number;
        } else if (shopId === 'primary' || Object.keys(branchStockMap).length === 0) {
          // Fallback to global stockQuantity if branch not found
          currentStock = productData.stockQuantity || 0;
        }

        functions.logger.info(
          `[deductInventoryAtomic] Current stock for product ${productId} at branch ${shopId}: ${currentStock}, requested: ${quantity}`
        );

        // ====================================================================
        // PHASE 3: VALIDATE STOCK
        // ====================================================================
        if (currentStock < quantity) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            `Insufficient stock. Available: ${currentStock}, Requested: ${quantity}`
          );
        }

        // ====================================================================
        // PHASE 4: DEDUCT STOCK ATOMICALLY
        // ====================================================================
        const newStock = currentStock - quantity;
        const updatedBranchStock = { ...branchStockMap };
        updatedBranchStock[shopId] = newStock;

        // Calculate new global stock for backward compatibility
        let newGlobalStock = 0;
        if (updatedBranchStock['primary']) {
          newGlobalStock = updatedBranchStock['primary'] as number;
        } else {
          // Sum all branch stocks
          newGlobalStock = Object.values(updatedBranchStock).reduce(
            (sum, val) => sum + (typeof val === 'number' ? val : 0),
            0
          );
        }

        // Update product document
        transaction.update(productRef, {
          branchStock: updatedBranchStock,
          stockQuantity: newGlobalStock,
          isAvailable: newGlobalStock > 0,
          lastStockUpdate: admin.firestore.FieldValue.serverTimestamp(),
          lastStockUpdateBy: context.auth!.uid,
        });

        // Record stock deduction event
        const eventRef = db.collection('inventory_events').doc();
        transaction.set(eventRef, {
          id: eventRef.id,
          type: 'stock_deduction',
          productId,
          orderId,
          quantity,
          shopId,
          stockBefore: currentStock,
          stockAfter: newStock,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          performedBy: context.auth!.uid,
        });

        return {
          success: true,
          stockBefore: currentStock,
          stockAfter: newStock,
          productId,
          orderId,
        };
      });

      return result;
    } catch (error: any) {
      functions.logger.error(
        `[deductInventoryAtomic] Error processing order ${orderId} for product ${productId}:`,
        error
      );

      // Re-throw Https errors as-is
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      // Wrap other errors
      throw new functions.https.HttpsError(
        'internal',
        `Failed to deduct inventory: ${error.message || 'Unknown error'}`
      );
    } finally {
      // ========================================================================
      // PHASE 5: RELEASE LOCK (always, even on error)
      // ========================================================================
      try {
        await lockRef.delete();
        functions.logger.info(
          `[deductInventoryAtomic] Lock released for product ${productId}`
        );
      } catch (unlockError) {
        functions.logger.error(
          `[deductInventoryAtomic] Failed to release lock for product ${productId}:`,
          unlockError
        );
      }
    }
  }
);
