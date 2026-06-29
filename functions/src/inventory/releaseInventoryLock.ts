import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

const db = admin.firestore();

/**
 * Manual lock release function
 *
 * Use this to forcibly release a lock in case of transaction failure.
 * Only accessible by admin role or the order creator.
 */
export const releaseInventoryLock = functions.https.onCall(
  async (data: {
    productId: string;
    orderId: string;
  }, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const { productId, orderId } = data;

    if (!productId || typeof productId !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'productId must be a non-empty string'
      );
    }

    if (!orderId || typeof orderId !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'orderId must be a non-empty string'
      );
    }

    try {
      // Verify user is admin or order creator
      const lockRef = db.collection('product_locks').doc(productId);
      const lockSnapshot = await lockRef.get();

      if (lockSnapshot.exists) {
        const lockData = lockSnapshot.data();
        const lockOrderId = lockData?.orderId;
        const lockAcquiredBy = lockData?.acquiredBy;

        // Check authorization: admin OR order creator
        const userDoc = await db.collection('users').doc(context.auth.uid).get();
        const userRole = userDoc.data()?.role;
        const isAdmin = userRole === 'admin' || userRole === 'UserRole.admin';

        const isOrderCreator = lockAcquiredBy === context.auth.uid;
        const isCorrectOrder = lockOrderId === orderId;

        if (!isAdmin && !isOrderCreator) {
          throw new functions.https.HttpsError(
            'permission-denied',
            'Only admin or order creator can release locks'
          );
        }

        if (!isCorrectOrder) {
          functions.logger.warn(
            `[releaseInventoryLock] Lock exists for different order. Lock: ${lockOrderId}, Requested: ${orderId}`
          );
        }

        await lockRef.delete();
        functions.logger.info(
          `[releaseInventoryLock] Lock released for product ${productId}, order ${orderId}`
        );

        return {
          success: true,
          message: `Lock released for product ${productId}`,
        };
      } else {
        // Lock doesn't exist
        return {
          success: true,
          message: `No lock found for product ${productId}`,
        };
      }
    } catch (error: any) {
      functions.logger.error(
        `[releaseInventoryLock] Error releasing lock for product ${productId}:`,
        error
      );

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        'internal',
        `Failed to release lock: ${error.message || 'Unknown error'}`
      );
    }
  }
);
