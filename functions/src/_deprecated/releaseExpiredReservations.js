const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Runs every 5 minutes to sweep and release stuck inventory
exports.releaseExpiredReservations = functions.pubsub.schedule('every 5 minutes').onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    // Requires a composite index: status ASC, reservationExpiresAt ASC
    const expiredOrdersQuery = db.collection('orders')
        .where('status', '==', 'pending_payment')
        .where('reservationExpiresAt', '<', now);

    const snapshot = await expiredOrdersQuery.get();

    if (snapshot.empty) {
        console.log('[releaseExpiredReservations] No expired reservations found.');
        return null;
    }

    console.log(`[releaseExpiredReservations] Found ${snapshot.docs.length} expired orders. Processing...`);

    // Process each expired order inside its own transaction
    for (const doc of snapshot.docs) {
        const orderId = doc.id;
        const orderRef = doc.ref;

        try {
            await db.runTransaction(async (transaction) => {
                const orderDoc = await transaction.get(orderRef);
                if (!orderDoc.exists) return;

                const orderData = orderDoc.data();

                // Double check to ensure it wasn't confirmed in the milliseconds between query and transaction
                if (orderData.status !== 'pending_payment') {
                    console.log(`[releaseExpiredReservations] Order ${orderId} is no longer pending. Skipping.`);
                    return;
                }

                const items = orderData.items || [];
                const shopId = orderData.shopId || 'primary';
                const walletAmountUsed = orderData.walletAmountUsed || 0;
                const customerId = orderData.customerId;

                // 1. Fetch products for rollback
                const productRefs = items.map(item => db.collection('products').doc(item.productId));
                const productSnaps = await transaction.getAll(...productRefs);

                // 2. Rollback Wallet if deducted
                if (walletAmountUsed > 0 && customerId) {
                    const refundTxnId = `txn_wallet_refund_${orderId}`;
                    const refundTxnRef = db.collection('users').doc(customerId).collection('wallet_transactions').doc(refundTxnId);
                    
                    // Idempotency: Ensure we haven't already refunded
                    const refundDoc = await transaction.get(refundTxnRef);
                    
                    if (!refundDoc.exists) {
                        const userRef = db.collection('users').doc(customerId);
                        const userDoc = await transaction.get(userRef);
                        
                        if (userDoc.exists) {
                            const currentBalance = userDoc.data().walletBalance || 0;
                            const newBalance = currentBalance + walletAmountUsed;

                            transaction.update(userRef, {
                                walletBalance: newBalance,
                                updatedAt: admin.firestore.FieldValue.serverTimestamp()
                            });

                            transaction.set(refundTxnRef, {
                                id: refundTxnId,
                                userId: customerId,
                                type: 'refund',
                                amount: walletAmountUsed,
                                orderReference: orderId,
                                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                                description: `Wallet refund for expired checkout ${orderId}`,
                                balanceAfter: newBalance
                            });
                        }
                    }
                }

                // 3. Rollback Inventory Reservations
                for (let i = 0; i < items.length; i++) {
                    const clientItem = items[i];
                    const snap = productSnaps[i];

                    if (snap.exists) {
                        const productData = snap.data();
                        const branchStockMap = productData.branchStockMap || {};
                        const branchStock = branchStockMap[shopId] || { available: 0, reserved: 0, sold: 0 };
                        
                        let available = branchStock.available ?? (productData.stockQuantity || 0);
                        let reserved = branchStock.reserved ?? 0;
                        let sold = branchStock.sold ?? 0;

                        // Release the reserved stock back to available
                        if (reserved >= clientItem.quantity) {
                            reserved -= clientItem.quantity;
                            available += clientItem.quantity;

                            branchStockMap[shopId] = { available, reserved, sold };
                            
                            const globalAvailable = Object.values(branchStockMap).reduce((sum, b) => sum + (b.available || 0), 0);
                            const globalReserved = Object.values(branchStockMap).reduce((sum, b) => sum + (b.reserved || 0), 0);

                            transaction.update(snap.ref, {
                                branchStockMap,
                                availableStock: globalAvailable,
                                reservedStock: globalReserved,
                                isAvailable: globalAvailable > 0
                            });
                        } else {
                            console.warn(`[releaseExpiredReservations] Reservation anomaly on ${clientItem.productId} for order ${orderId}. Expected ${clientItem.quantity}, found ${reserved}`);
                        }
                    }
                }

                // 4. Update Order Status
                transaction.update(orderRef, {
                    status: 'cancelled',
                    reservationStatus: 'released',
                    cancellationReason: 'payment_timeout',
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
            });

            console.log(`[releaseExpiredReservations] Successfully rolled back expired order ${orderId}`);
        } catch (error) {
            console.error(`[releaseExpiredReservations] Failed to rollback order ${orderId}:`, error);
        }
    }

    // --- SLA SWEEP ENGINE ---
    try {
        const twentyMinsAgo = new Date(Date.now() - 20 * 60 * 1000);
        const fortyFiveMinsAgo = new Date(Date.now() - 45 * 60 * 1000);

        // 1. Stuck Packed Orders (> 20 mins)
        const stuckPacked = await db.collection('orders')
            .where('status', '==', 'packed')
            .where('updatedAt', '<', twentyMinsAgo)
            .get();

        for (const doc of stuckPacked.docs) {
            const orderData = doc.data();
            const alertSnap = await db.collection('operational_alerts')
                .where('orderId', '==', doc.id)
                .where('type', '==', 'packed_sla_violation')
                .where('resolved', '==', false)
                .limit(1)
                .get();

            if (alertSnap.empty) {
                await db.collection('operational_alerts').add({
                    type: 'packed_sla_violation',
                    orderId: doc.id,
                    orderNumber: orderData.orderNumber || doc.id,
                    reportedAt: admin.firestore.FieldValue.serverTimestamp(),
                    message: `Order #${orderData.orderNumber || doc.id} has been stuck in packed state for over 20 minutes.`,
                    resolved: false
                });
            }
        }

        // 2. Stuck Shipped Orders (> 45 mins)
        const stuckShipped = await db.collection('orders')
            .where('status', '==', 'shipped')
            .where('updatedAt', '<', fortyFiveMinsAgo)
            .get();

        for (const doc of stuckShipped.docs) {
            const orderData = doc.data();
            const alertSnap = await db.collection('operational_alerts')
                .where('orderId', '==', doc.id)
                .where('type', '==', 'shipped_sla_violation')
                .where('resolved', '==', false)
                .limit(1)
                .get();

            if (alertSnap.empty) {
                await db.collection('operational_alerts').add({
                    type: 'shipped_sla_violation',
                    orderId: doc.id,
                    orderNumber: orderData.orderNumber || doc.id,
                    reportedAt: admin.firestore.FieldValue.serverTimestamp(),
                    message: `Order #${orderData.orderNumber || doc.id} has been out for delivery for over 45 minutes.`,
                    resolved: false
                });
            }
        }

    } catch (slaError) {
        console.error('[releaseExpiredReservations] SLA sweep failed:', slaError);
    }

    return null;
});
