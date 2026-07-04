const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.cancelOrder = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be logged in to cancel an order.');
    }

    const { orderId, reason } = data;
    const actorId = context.auth.uid;

    if (!orderId || !reason) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing orderId or reason.');
    }

    const db = admin.firestore();

    try {
        const userDoc = await db.collection('users').doc(actorId).get();
        if (!userDoc.exists || userDoc.data().isActive === false) {
            throw new functions.https.HttpsError('permission-denied', 'User is inactive or not found.');
        }
        
        const role = userDoc.data().role;
        const actorName = userDoc.data().name || 'Unknown';

        const orderRef = db.collection('orders').doc(orderId);

        return await db.runTransaction(async (transaction) => {
            const orderDoc = await transaction.get(orderRef);
            if (!orderDoc.exists) {
                throw new functions.https.HttpsError('not-found', 'Order not found.');
            }

            const orderData = orderDoc.data();
            const currentStatus = orderData.status;

            if (['cancelled', 'delivered', 'returned', 'refunded'].includes(currentStatus)) {
                throw new functions.https.HttpsError('failed-precondition', `Cannot cancel order in ${currentStatus} state.`);
            }

            // Customer checks
            if (role === 'customer') {
                if (orderData.customerId !== actorId) {
                    throw new functions.https.HttpsError('permission-denied', 'Cannot cancel another customer\'s order.');
                }
                if (!['pending_payment', 'confirmed'].includes(currentStatus)) {
                    throw new functions.https.HttpsError('permission-denied', 'You can only cancel an order before it is processed.');
                }
            } else if (!['owner', 'admin', 'employee', 'deliveryAgent'].includes(role)) {
                throw new functions.https.HttpsError('permission-denied', 'Insufficient permissions.');
            }

            // If it's already shipped, the cancellation must go through Failed Delivery / Return flow
            if (currentStatus === 'shipped') {
                throw new functions.https.HttpsError('failed-precondition', 'Order is already shipped. Use failed delivery workflow.');
            }

            // --- REVERSALS ---
            // 1. Inventory Reversal (only if confirmed, processing, or packed)
            // If it was pending_payment, it might have an active reservation instead of sold.
            if (['pending_payment', 'confirmed', 'processing', 'packed'].includes(currentStatus)) {
                if (orderData.items && Array.isArray(orderData.items)) {
                    for (const item of orderData.items) {
                        const productRef = db.collection('products').doc(item.productId);
                        const productDoc = await transaction.get(productRef);
                        if (productDoc.exists) {
                            const pData = productDoc.data();
                            const branchMap = pData.branchStockMap || {};
                            const shopId = orderData.shopId || 'primary';
                            const shopStock = branchMap[shopId] || { available: 0, reserved: 0, sold: 0 };
                            
                            const qty = item.quantity;
                            if (currentStatus === 'pending_payment') {
                                // Undo reservation
                                shopStock.reserved = Math.max(0, shopStock.reserved - qty);
                                shopStock.available += qty;
                            } else {
                                // Undo sold
                                shopStock.sold = Math.max(0, shopStock.sold - qty);
                                shopStock.available += qty;
                            }
                            
                            branchMap[shopId] = shopStock;
                            transaction.update(productRef, { branchStockMap: branchMap });
                        }
                    }
                }
            }

            // 2. Refund Wallet (if wallet used)
            if (orderData.walletAmountUsed > 0) {
                const customerRef = db.collection('users').doc(orderData.customerId);
                const customerDoc = await transaction.get(customerRef);
                if (customerDoc.exists) {
                    const currentBalance = customerDoc.data().walletBalance || 0;
                    const newBalance = currentBalance + orderData.walletAmountUsed;
                    transaction.update(customerRef, {
                        walletBalance: newBalance,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp()
                    });

                    // Log Wallet Transaction
                    const txnId = `txn_refund_${orderId}`;
                    const txnRef = customerRef.collection('wallet_transactions').doc(txnId);
                    transaction.set(txnRef, {
                        id: txnId,
                        userId: orderData.customerId,
                        type: 'walletRefund',
                        amount: orderData.walletAmountUsed,
                        orderReference: orderId,
                        timestamp: admin.firestore.FieldValue.serverTimestamp(),
                        description: `Refund for cancelled order ${orderId}`,
                        balanceAfter: newBalance
                    });
                }
            }

            // 3. Mark Refund needed if payment was captured via online payment
            let paymentRefundStatus = 'none';
            if (orderData.paymentStatus === 'captured' && orderData.finalPayable > 0) {
                paymentRefundStatus = 'pending_refund';
            }

            const updates = {
                status: 'cancelled',
                cancellationReason: reason,
                cancelledBy: actorId,
                cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
                paymentRefundStatus: paymentRefundStatus,
                reservationStatus: 'cancelled', // Stop background sweep from hitting it
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            };

            const history = orderData.statusHistory || [];
            history.push({
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                status: 'cancelled',
                actorId: actorId,
                actorName: actorName,
                note: reason
            });
            updates.statusHistory = history;

            transaction.update(orderRef, updates);

            return { success: true, orderId: orderId, message: 'Order cancelled successfully.' };
        });

    } catch (error) {
        console.error(`[cancelOrder] Error cancelling order ${orderId}:`, error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Internal error while cancelling order.');
    }
});
