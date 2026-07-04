const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Ensure we don't send duplicate notifications
const processedEvents = new Set();

exports.onOrderUpdated = functions.firestore
    .document('orders/{orderId}')
    .onUpdate(async (change, context) => {
        const orderId = context.params.orderId;
        const beforeData = change.before.data();
        const afterData = change.after.data();

        // 1. Detect Status Change
        if (beforeData.status === afterData.status) {
            return null; // Status didn't change
        }

        const newStatus = afterData.status;
        const customerId = afterData.customerId;

        // Dedup check (Cloud Functions can sometimes trigger more than once)
        const eventKey = `${orderId}_${newStatus}`;
        if (processedEvents.has(eventKey)) {
            console.log(`[onOrderUpdated] Duplicate event ignored for ${eventKey}`);
            return null;
        }
        processedEvents.add(eventKey);
        
        // Clean up cache to avoid memory leak
        if (processedEvents.size > 1000) processedEvents.clear();

        console.log(`[onOrderUpdated] Order ${orderId} transitioned to ${newStatus}`);

        const db = admin.firestore();

        try {
            // 2. Fetch Customer FCM Token
            const userDoc = await db.collection('users').doc(customerId).get();
            let fcmToken = null;
            let customerName = 'Customer';
            
            if (userDoc.exists) {
                fcmToken = userDoc.data().fcmToken;
                customerName = userDoc.data().name || customerName;
            }

            const messages = [];

            // 3. Event Bus Logic based on newStatus
            switch (newStatus) {
                case 'confirmed':
                    // Analytics & Push Notification
                    if (fcmToken) {
                        messages.push({
                            token: fcmToken,
                            notification: {
                                title: 'Order Confirmed! 🎉',
                                body: `Hey ${customerName}, your order #${afterData.orderNumber || orderId} has been confirmed. We are preparing it now!`,
                            },
                            data: { type: 'order_status', orderId: orderId, status: newStatus }
                        });
                    }
                    break;

                case 'processing':
                    break;

                case 'packed':
                    if (fcmToken) {
                        messages.push({
                            token: fcmToken,
                            notification: {
                                title: 'Order Packed 📦',
                                body: `Your order is packed and waiting for a delivery agent.`,
                            },
                            data: { type: 'order_status', orderId: orderId, status: newStatus }
                        });
                    }
                    break;

                case 'shipped':
                    if (fcmToken) {
                        messages.push({
                            token: fcmToken,
                            notification: {
                                title: 'Out for Delivery! 🛵',
                                body: `Your order is on the way! Please be ready.`,
                            },
                            data: { type: 'order_status', orderId: orderId, status: newStatus }
                        });
                    }
                    break;

                case 'delivered':
                    if (fcmToken) {
                        messages.push({
                            token: fcmToken,
                            notification: {
                                title: 'Order Delivered ✅',
                                body: `Thank you for shopping with Fufaji! Enjoy your order.`,
                            },
                            data: { type: 'order_status', orderId: orderId, status: newStatus }
                        });
                    }
                    // Trigger Settlement & Analytics
                    await db.collection('analytics_events').add({
                        type: 'order_delivered',
                        orderId: orderId,
                        totalAmount: afterData.totalAmount,
                        deliveryAgentId: afterData.deliveryAgentId,
                        timestamp: admin.firestore.FieldValue.serverTimestamp()
                    });
                    break;

                case 'cancelled':
                    if (fcmToken) {
                        messages.push({
                            token: fcmToken,
                            notification: {
                                title: 'Order Cancelled ❌',
                                body: `Your order #${afterData.orderNumber || orderId} has been cancelled.`,
                            },
                            data: { type: 'order_status', orderId: orderId, status: newStatus }
                        });
                    }
                    break;

                default:
                    break;
            }

            // 4. Dispatch Notifications
            if (messages.length > 0) {
                await admin.messaging().sendAll(messages);
                console.log(`[onOrderUpdated] Sent ${messages.length} notifications for order ${orderId}`);
            }

            return null;
        } catch (error) {
            console.error(`[onOrderUpdated] Error processing workflow for order ${orderId}:`, error);
            return null;
        }
    });
