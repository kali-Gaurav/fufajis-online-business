const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const twilio = require('twilio');

admin.initializeApp();

exports.razorpayWebhook = functions.runWith({
    secrets: ['RAZORPAY_WEBHOOK_SECRET']
}).https.onRequest(async (req, res) => {
    // Only accept POST requests
    if (req.method !== 'POST') {
        return res.status(405).send('Method Not Allowed');
    }

    const RAZORPAY_WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET;
    const signature = req.headers['x-razorpay-signature'];

    // 1. Verify HMAC-SHA256 signature
    const body = req.rawBody || JSON.stringify(req.body);
    const expectedSignature = crypto
        .createHmac('sha256', RAZORPAY_WEBHOOK_SECRET || '')
        .update(body)
        .digest('hex');

    if (signature !== expectedSignature) {
        console.error('[RazorpayWebhook] SECURITY: Invalid signature rejected');
        await admin.firestore().collection('payment_reconciliation_log').add({
            action: 'webhook_signature_rejected',
            signature: signature ? signature.substring(0, 12) + '...' : 'missing',
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        return res.status(400).send('Invalid signature');
    }

    const event = req.body.event;
    const payload = req.body.payload;
    const webhookEventId = req.body.id || `unknown_${Date.now()}`;

    console.log(`[RazorpayWebhook] Received event: ${event} (ID: ${webhookEventId})`);

    try {
        // 2. Idempotency guard — skip already-processed events
        const eventRef = admin.firestore().collection('webhook_events').doc(`razorpay_${webhookEventId}`);
        const eventDoc = await eventRef.get();
        if (eventDoc.exists) {
            console.log(`[RazorpayWebhook] Event ${webhookEventId} already processed. Skipping.`);
            return res.status(200).send('Already processed');
        }

        // ── PAYMENT CAPTURED / AUTHORIZED ──
        if (event === 'payment.captured' || event === 'payment.authorized') {
            const payment = payload.payment.entity;
            const orderId = payment.notes?.order_id || payment.order_id;
            const amountPaise = payment.amount; // Amount in paise
            const amountRupees = amountPaise / 100;

            if (!orderId) {
                console.error('[RazorpayWebhook] No order_id found in payment notes');
                await eventRef.set({ processedAt: admin.firestore.FieldValue.serverTimestamp(), eventId: webhookEventId, type: event, error: 'missing_order_id' });
                return res.status(400).send('Missing order_id');
            }

            const orderRef = admin.firestore().collection('orders').doc(orderId);
            const orderDoc = await orderRef.get();

            if (!orderDoc.exists) {
                console.error(`[RazorpayWebhook] Order ${orderId} not found`);
                await eventRef.set({ processedAt: admin.firestore.FieldValue.serverTimestamp(), eventId: webhookEventId, type: event, error: 'order_not_found', orderId });
                return res.status(404).send('Order not found');
            }

            // 3. Amount validation — ensure webhook amount matches order
            const orderData = orderDoc.data();
            const orderAmount = orderData.totalAmount || 0;
            const tolerance = 1.0; // ₹1 tolerance for rounding
            if (Math.abs(amountRupees - orderAmount) > tolerance) {
                console.error(`[RazorpayWebhook] AMOUNT MISMATCH: Webhook ₹${amountRupees} vs Order ₹${orderAmount}`);
                await admin.firestore().collection('payment_reconciliation_log').add({
                    paymentId: payment.id,
                    orderId: orderId,
                    action: 'amount_mismatch',
                    webhookAmount: amountRupees,
                    orderAmount: orderAmount,
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                });
                // Still process but flag for manual review
            }

            // 4. Transactional update
            await admin.firestore().runTransaction(async (transaction) => {
                // Update order
                transaction.update(orderRef, {
                    paymentStatus: 'paid',
                    paymentId: payment.id,
                    paymentMethod: 'PaymentMethod.' + (payment.method || 'razorpay'),
                    status: 'OrderStatus.confirmed',
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    reconciliationSource: 'razorpay_webhook',
                    reconciledAt: admin.firestore.FieldValue.serverTimestamp(),
                    financeCategory: 'online_revenue'
                });

                // Create/update payment record
                const paymentRef = admin.firestore().collection('payments').doc(payment.id);
                transaction.set(paymentRef, {
                    paymentId: payment.id,
                    orderId: orderId,
                    orderNumber: orderData.orderNumber || '',
                    amount: amountRupees,
                    currency: payment.currency || 'INR',
                    method: payment.method || 'unknown',
                    status: 'captured',
                    verified: true,
                    verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
                    source: 'webhook',
                    customerId: orderData.customerId || '',
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    financeType: 'credit'
                }, { merge: true });

                // Mark webhook event as processed
                transaction.set(eventRef, {
                    processedAt: admin.firestore.FieldValue.serverTimestamp(),
                    eventId: webhookEventId,
                    orderId: orderId,
                    paymentId: payment.id,
                    amount: amountRupees,
                    type: event,
                });
            });

            // 5. Reconciliation audit log
            await admin.firestore().collection('payment_reconciliation_log').add({
                paymentId: payment.id,
                orderId: orderId,
                amount: amountRupees,
                action: 'webhook_reconcile',
                event: event,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`[RazorpayWebhook] Order ${orderId} → PAID + CONFIRMED (₹${amountRupees})`);

        // ── PAYMENT FAILED ──
        } else if (event === 'payment.failed') {
            const payment = payload.payment.entity;
            const orderId = payment.notes?.order_id || payment.order_id;
            if (orderId) {
                await admin.firestore().collection('orders').doc(orderId).update({
                    paymentStatus: 'failed',
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                await eventRef.set({ processedAt: admin.firestore.FieldValue.serverTimestamp(), eventId: webhookEventId, orderId, type: event });
            }

        // ── PAYMENT REFUNDED ──
        } else if (event === 'refund.created' || event === 'payment.refunded') {
            const refundEntity = event === 'refund.created' 
                ? payload.refund?.entity 
                : payload.payment?.entity;
            
            if (refundEntity) {
                const paymentId = refundEntity.payment_id || refundEntity.id;
                const refundAmount = (refundEntity.amount || 0) / 100;

                // Find order by payment ID
                const ordersQuery = await admin.firestore().collection('orders')
                    .where('paymentId', '==', paymentId)
                    .limit(1)
                    .get();

                if (!ordersQuery.empty) {
                    const orderDoc = ordersQuery.docs[0];
                    await orderDoc.ref.update({
                        paymentStatus: 'refunded',
                        refundAmount: refundAmount,
                        refundedAt: admin.firestore.FieldValue.serverTimestamp(),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                    console.log(`[RazorpayWebhook] Order ${orderDoc.id} refunded ₹${refundAmount}`);
                }

                await eventRef.set({ processedAt: admin.firestore.FieldValue.serverTimestamp(), eventId: webhookEventId, paymentId, type: event });

                await admin.firestore().collection('payment_reconciliation_log').add({
                    paymentId: paymentId,
                    action: 'refund_processed',
                    amount: refundAmount,
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                });
            }

        // ── ORDER PAID ──
        } else if (event === 'order.paid') {
            const order = payload.order?.entity;
            if (order) {
                await eventRef.set({ processedAt: admin.firestore.FieldValue.serverTimestamp(), eventId: webhookEventId, razorpayOrderId: order.id, type: event });
            }
        }

        res.status(200).send('Webhook processed');
    } catch (error) {
        console.error('[RazorpayWebhook] Error processing webhook:', error);

        // Log failure for manual review
        await admin.firestore().collection('payment_reconciliation_log').add({
            action: 'webhook_processing_error',
            eventId: webhookEventId,
            event: event,
            error: error.message,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        }).catch(() => {});

        res.status(500).send('Internal Server Error');
    }
});

/**
 * Verify Razorpay Payment Signature
 * Securely verifies payment signature server-side using HMAC-SHA256
 */
exports.verifyRazorpayPayment = functions.runWith({
    secrets: ['RAZORPAY_KEY_SECRET']
}).https.onCall(async (data, context) => {
    try {
        const { paymentId, orderId, signature } = data;

        if (!paymentId || !orderId || !signature) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'Missing required parameters: paymentId, orderId, signature'
            );
        }

        const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || 'RAZORPAY_SECRET_KEY_PLACEHOLDER';

        // Cryptographically verify signature
        const expectedSignature = crypto
            .createHmac('sha256', RAZORPAY_KEY_SECRET)
            .update(orderId + '|' + paymentId)
            .digest('hex');

        if (signature !== expectedSignature) {
            console.error('Invalid signature for payment: ' + paymentId);
            return {
                success: false,
                error: 'invalid-signature',
                message: 'Payment signature verification failed'
            };
        }

        console.log(`Payment signature verified successfully for order: ${orderId}, payment: ${paymentId}`);

        return {
            success: true,
            status: 'authorized',
            message: 'Signature verified successfully'
        };
    } catch (error) {
        console.error('Error verifying payment:', error);
        throw new functions.https.HttpsError(
            'internal',
            'Failed to verify payment: ' + error.message
        );
    }
});

/**
 * Send Order Confirmation SMS
 * Sends an SMS to the customer with order number and estimated delivery date
 * 
 * [Requirements 4.9]: Send confirmation SMS/notification
 */
exports.sendOrderConfirmationSMS = functions.runWith({
    secrets: ['TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 'TWILIO_PHONE_NUMBER']
}).https.onCall(async (data, context) => {
    const twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
    const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER || '+15017122661';
    try {
        const { phoneNumber, orderNumber, estimatedDeliveryDate, totalAmount } = data;

        if (!phoneNumber || !orderNumber) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'Missing required parameters: phoneNumber, orderNumber'
            );
        }

        // Format phone number
        const formattedPhone = formatPhoneNumber(phoneNumber);

        // Create SMS message
        const message = `Order #${orderNumber} confirmed! 🎉\n\nEstimated Delivery: ${estimatedDeliveryDate}\nTotal: ₹${totalAmount}\n\nTrack your order on Fufaji's Online app.\n\nThank you for shopping with us!`;

        // Send SMS via Twilio
        const result = await twilioClient.messages.create({
            body: message,
            from: twilioPhoneNumber,
            to: formattedPhone,
        });

        console.log(`Order confirmation SMS sent to ${formattedPhone}: ${result.sid}`);

        return {
            success: true,
            messageSid: result.sid,
            message: 'SMS sent successfully',
        };
    } catch (error) {
        console.error('Error sending order confirmation SMS:', error);
        throw new functions.https.HttpsError(
            'internal',
            'Failed to send SMS: ' + error.message
        );
    }
});

/**
 * Send Order Status Update SMS
 * Sends an SMS to the customer with the new order status
 * 
 * [Requirements 5.3]: Send status update notifications
 */
exports.sendOrderStatusUpdateSMS = functions.runWith({
    secrets: ['TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 'TWILIO_PHONE_NUMBER']
}).https.onCall(async (data, context) => {
    const twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
    const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER || '+15017122661';
    try {
        const { phoneNumber, orderNumber, status, additionalInfo } = data;

        if (!phoneNumber || !orderNumber || !status) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'Missing required parameters: phoneNumber, orderNumber, status'
            );
        }

        const formattedPhone = formatPhoneNumber(phoneNumber);

        // Create status-specific message
        let message = '';
        switch (status.toLowerCase()) {
            case 'confirmed':
                message = `Order #${orderNumber} confirmed! Your order is being prepared.`;
                break;
            case 'processing':
                message = `Order #${orderNumber} is being packed. Ready for pickup soon!`;
                break;
            case 'packed':
                message = `Order #${orderNumber} is packed and ready for delivery!`;
                break;
            case 'outfordelivery':
                message = `Order #${orderNumber} is out for delivery! 🚴 Our rider is on the way. ${additionalInfo || ''}`;
                break;
            case 'delivered':
                message = `Order #${orderNumber} delivered! 🎉 Thank you for shopping with Fufaji's Online!`;
                break;
            case 'cancelled':
                message = `Order #${orderNumber} has been cancelled. Refund will be processed within 3-5 business days.`;
                break;
            default:
                message = `Order #${orderNumber} status updated to: ${status}`;
        }

        const result = await twilioClient.messages.create({
            body: message,
            from: twilioPhoneNumber,
            to: formattedPhone,
        });

        console.log(`Order status update SMS sent to ${formattedPhone}: ${result.sid}`);

        return {
            success: true,
            messageSid: result.sid,
            message: 'Status update SMS sent successfully',
        };
    } catch (error) {
        console.error('Error sending order status update SMS:', error);
        throw new functions.https.HttpsError(
            'internal',
            'Failed to send SMS: ' + error.message
        );
    }
});

/**
 * Send Delivery OTP SMS
 * Sends an SMS to the customer with the OTP for delivery verification
 * 
 * [Requirements 5.5]: Send OTP for delivery verification
 */
exports.sendDeliveryOTPSMS = functions.runWith({
    secrets: ['TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 'TWILIO_PHONE_NUMBER']
}).https.onCall(async (data, context) => {
    const twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
    const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER || '+15017122661';
    try {
        const { phoneNumber, orderNumber, otp } = data;

        if (!phoneNumber || !orderNumber || !otp) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'Missing required parameters: phoneNumber, orderNumber, otp'
            );
        }

        const formattedPhone = formatPhoneNumber(phoneNumber);

        const message = `Your delivery OTP for Order #${orderNumber} is: ${otp}\n\nShare this OTP with the delivery agent to complete the delivery.`;

        const result = await twilioClient.messages.create({
            body: message,
            from: twilioPhoneNumber,
            to: formattedPhone,
        });

        console.log(`Delivery OTP SMS sent to ${formattedPhone}: ${result.sid}`);

        return {
            success: true,
            messageSid: result.sid,
            message: 'Delivery OTP SMS sent successfully',
        };
    } catch (error) {
        console.error('Error sending delivery OTP SMS:', error);
        throw new functions.https.HttpsError(
            'internal',
            'Failed to send SMS: ' + error.message
        );
    }
});

/**
 * Send Order Cancellation SMS
 * Sends an SMS to the customer confirming order cancellation and refund
 * 
 * [Requirements 5.7]: Send cancellation notification
 */
exports.sendOrderCancellationSMS = functions.runWith({
    secrets: ['TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 'TWILIO_PHONE_NUMBER']
}).https.onCall(async (data, context) => {
    const twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
    const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER || '+15017122661';
    try {
        const { phoneNumber, orderNumber, refundAmount } = data;

        if (!phoneNumber || !orderNumber) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'Missing required parameters: phoneNumber, orderNumber'
            );
        }

        const formattedPhone = formatPhoneNumber(phoneNumber);

        const message = `Order #${orderNumber} has been cancelled.\n\nRefund Amount: ₹${refundAmount}\nRefund will be processed within 3-5 business days.\n\nFor assistance, contact our support team.`;

        const result = await twilioClient.messages.create({
            body: message,
            from: twilioPhoneNumber,
            to: formattedPhone,
        });

        console.log(`Order cancellation SMS sent to ${formattedPhone}: ${result.sid}`);

        return {
            success: true,
            messageSid: result.sid,
            message: 'Cancellation SMS sent successfully',
        };
    } catch (error) {
        console.error('Error sending order cancellation SMS:', error);
        throw new functions.https.HttpsError(
            'internal',
            'Failed to send SMS: ' + error.message
        );
    }
});

/**
 * Send Delivery Agent Assignment SMS
 * Sends an SMS to the customer with delivery agent details
 * 
 * [Requirements 5.4]: Send delivery agent assignment notification
 */
exports.sendDeliveryAgentAssignmentSMS = functions.runWith({
    secrets: ['TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 'TWILIO_PHONE_NUMBER']
}).https.onCall(async (data, context) => {
    const twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
    const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER || '+15017122661';
    try {
        const { phoneNumber, orderNumber, agentName, agentPhone, estimatedArrivalTime } = data;

        if (!phoneNumber || !orderNumber || !agentName) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'Missing required parameters: phoneNumber, orderNumber, agentName'
            );
        }

        const formattedPhone = formatPhoneNumber(phoneNumber);

        const message = `Order #${orderNumber} assigned to ${agentName}!\n\nAgent Phone: ${agentPhone}\nEstimated Arrival: ${estimatedArrivalTime}\n\nTrack your delivery in real-time on the app.`;

        const result = await twilioClient.messages.create({
            body: message,
            from: twilioPhoneNumber,
            to: formattedPhone,
        });

        console.log(`Delivery agent assignment SMS sent to ${formattedPhone}: ${result.sid}`);

        return {
            success: true,
            messageSid: result.sid,
            message: 'Delivery agent assignment SMS sent successfully',
        };
    } catch (error) {
        console.error('Error sending delivery agent assignment SMS:', error);
        throw new functions.https.HttpsError(
            'internal',
            'Failed to send SMS: ' + error.message
        );
    }
});

/**
 * Send Promotional SMS
 * Sends promotional messages to customers
 */
exports.sendPromotionalSMS = functions.runWith({
    secrets: ['TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 'TWILIO_PHONE_NUMBER']
}).https.onCall(async (data, context) => {
    const twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
    const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER || '+15017122661';
    try {
        const { phoneNumber, message } = data;

        if (!phoneNumber || !message) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'Missing required parameters: phoneNumber, message'
            );
        }

        const formattedPhone = formatPhoneNumber(phoneNumber);

        const result = await twilioClient.messages.create({
            body: message,
            from: twilioPhoneNumber,
            to: formattedPhone,
        });

        console.log(`Promotional SMS sent to ${formattedPhone}: ${result.sid}`);

        return {
            success: true,
            messageSid: result.sid,
            message: 'Promotional SMS sent successfully',
        };
    } catch (error) {
        console.error('Error sending promotional SMS:', error);
        throw new functions.https.HttpsError(
            'internal',
            'Failed to send SMS: ' + error.message
        );
    }
});

/**
 * WhatsApp Webhook Handler
 * Handles verification and incoming messages from Meta WhatsApp Business API
 */
exports.whatsappWebhook = functions.https.onRequest(async (req, res) => {
    // 1. Handle Webhook Verification (GET)
    if (req.method === 'GET') {
        const mode = req.query['hub.mode'];
        const token = req.query['hub.verify_token'];
        const challenge = req.query['hub.challenge'];

        const VERIFY_TOKEN = 'fufaji_whatsapp_verify';

        if (mode && token) {
            if (mode === 'subscribe' && token === VERIFY_TOKEN) {
                console.log('WhatsApp Webhook Verified');
                return res.status(200).send(challenge);
            } else {
                return res.status(403).send('Forbidden');
            }
        }
    }

    // 2. Handle Incoming Messages (POST)
    if (req.method === 'POST') {
        try {
            const body = req.body;

            if (body.object === 'whatsapp_business_account') {
                if (body.entry && body.entry[0].changes && body.entry[0].changes[0].value.messages) {
                    const message = body.entry[0].changes[0].value.messages[0];
                    const from = message.from; // Sender's phone number
                    const messageId = message.id;

                    // Log the incoming message
                    await admin.firestore().collection('whatsapp_incoming').doc(messageId).set({
                        from: from,
                        body: message,
                        receivedAt: admin.firestore.FieldValue.serverTimestamp(),
                        status: 'pending'
                    });

                    console.log(`Received WhatsApp message from ${from}: ${messageId}`);
                }
                return res.status(200).send('EVENT_RECEIVED');
            } else {
                return res.status(404).send('Not Found');
            }
        } catch (error) {
            console.error('Error processing WhatsApp webhook:', error);
            return res.status(500).send('Internal Server Error');
        }
    }

    res.status(405).send('Method Not Allowed');
});

/**
 * Trigger push notifications when order status changes
 */
exports.onOrderUpdate = functions.runWith({
    secrets: ['WHATSAPP_TOKEN', 'WHATSAPP_PHONE_ID']
}).firestore
    .document('orders/{orderId}')
    .onUpdate(async (change, context) => {
        const newValue = change.after.data();
        const previousValue = change.before.data();

        // Only notify if status has changed
        if (newValue.status === previousValue.status) return null;

        const customerId = newValue.customerId;
        const status = (newValue.status || '').replace('OrderStatus.', '');
        const orderNumber = newValue.orderNumber;

        // Get customer's FCM token
        const userRef = admin.firestore().collection('users').doc(customerId);
        const userDoc = await userRef.get();

        if (!userDoc.exists || !userDoc.data().fcmToken) {
            console.log(`No FCM token for user ${customerId}. Skipping notification.`);
            return null;
        }

        const fcmToken = userDoc.data().fcmToken;

        let title = `📦 Order #${orderNumber} Update`;
        let body = `Your order status is now: ${status}`;

        // Custom messages based on status
        switch (status) {
            case 'confirmed':
                body = "Your order has been confirmed by the shop!";
                break;
            case 'processing':
                body = "We are preparing your items for delivery.";
                break;
            case 'packed':
                body = "Your order has been packed and is ready!";
                break;
            case 'outForDelivery':
                const otp = newValue.otp || 'N/A';
                const rider = newValue.deliveryEmployeeName || 'a rider';
                body = `Our rider (${rider}) is on the way! 🚴 Your Delivery OTP is: ${otp}`;
                break;
            case 'delivered':
                body = "Order delivered! Enjoy your purchase. 🎉";
                break;
            case 'cancelled':
                body = "Your order has been cancelled.";
                break;
        }

        const message = {
            notification: { title, body },
            data: {
                orderId: context.params.orderId,
                status: status,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                type: 'orderUpdate'
            },
            token: fcmToken
        };

        try {
            await admin.messaging().send(message);
            console.log(`Notification sent to ${customerId} for order ${orderNumber} (${status})`);

            // Populate In-App Notification Center
            await admin.firestore()
                .collection('users')
                .doc(customerId)
                .collection('notifications')
                .add({
                    title: title,
                    body: body,
                    type: 'orderUpdate',
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    isRead: false,
                    data: { orderId: context.params.orderId }
                });

            // TRIGGER WHATSAPP for Confirmed and OutForDelivery
            if (status === 'confirmed' || status === 'outForDelivery') {
                const userDoc = await admin.firestore().collection('users').doc(customerId).get();
                const phone = userDoc.data()?.phoneNumber;
                if (phone) {
                    const WHATSAPP_TOKEN = process.env.WHATSAPP_TOKEN;
                    const WHATSAPP_PHONE_ID = process.env.WHATSAPP_PHONE_ID;
                    if (WHATSAPP_TOKEN && WHATSAPP_PHONE_ID) {
                        const cleanPhone = phone.replace(/\D/g, '');
                        const waPhone = cleanPhone.length === 10 ? '91' + cleanPhone : cleanPhone;

                        await fetch(`https://graph.facebook.com/v25.0/${WHATSAPP_PHONE_ID}/messages`, {
                            method: 'POST',
                            headers: {
                                'Content-Type': 'application/json',
                                'Authorization': `Bearer ${WHATSAPP_TOKEN}`,
                            },
                            body: JSON.stringify({
                                messaging_product: 'whatsapp',
                                to: waPhone,
                                type: 'text',
                                text: { body: `Fufaji Update: ${body}\nTrack here: https://fufajionline.com/track/${context.params.orderId}` },
                            }),
                        });
                    }
                }
            }
        } catch (error) {
            console.error('Error sending FCM message:', error);
        }

        return null;
    });

/**
 * Trigger push notifications when a new order is created
 */
exports.onOrderCreate = functions.runWith({
    secrets: ['WHATSAPP_TOKEN', 'WHATSAPP_PHONE_ID']
}).firestore
    .document('orders/{orderId}')
    .onCreate(async (snap, context) => {
        const newValue = snap.data();
        const customerId = newValue.customerId;
        const orderNumber = newValue.orderNumber;

        // Get customer's FCM token
        const userRef = admin.firestore().collection('users').doc(customerId);
        const userDoc = await userRef.get();

        if (!userDoc.exists || !userDoc.data().fcmToken) {
            console.log(`No FCM token for user ${customerId}. Skipping notification.`);
            return null;
        }

        const fcmToken = userDoc.data().fcmToken;
        const title = `📦 Order Placed!`;
        const body = `We have received your order #${orderNumber}!`;

        const message = {
            notification: { title, body },
            data: {
                orderId: context.params.orderId,
                status: 'pending',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                type: 'orderUpdate'
            },
            token: fcmToken
        };

        try {
            await admin.messaging().send(message);
            console.log(`Notification sent to ${customerId} for new order ${orderNumber}`);

            // Populate In-App Notification Center
            await admin.firestore()
                .collection('users')
                .doc(customerId)
                .collection('notifications')
                .add({
                    title: title,
                    body: body,
                    type: 'orderUpdate',
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    isRead: false,
                    data: { orderId: context.params.orderId }
                });

            // TRIGGER WHATSAPP
            const phone = userDoc.data()?.phoneNumber;
            if (phone) {
                const WHATSAPP_TOKEN = process.env.WHATSAPP_TOKEN;
                const WHATSAPP_PHONE_ID = process.env.WHATSAPP_PHONE_ID;
                if (WHATSAPP_TOKEN && WHATSAPP_PHONE_ID) {
                    const cleanPhone = phone.replace(/\D/g, '');
                    const waPhone = cleanPhone.length === 10 ? '91' + cleanPhone : cleanPhone;

                    await fetch(`https://graph.facebook.com/v25.0/${WHATSAPP_PHONE_ID}/messages`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'Authorization': `Bearer ${WHATSAPP_TOKEN}`,
                        },
                        body: JSON.stringify({
                            messaging_product: 'whatsapp',
                            to: waPhone,
                            type: 'text',
                            text: { body: `Fufaji Update: ${body}\nTrack here: https://fufajionline.com/track/${context.params.orderId}` },
                        }),
                    });
                }
            }
        } catch (error) {
            console.error('Error sending FCM message on create:', error);
        }

        return null;
    });

/**
 * Automatically assign roles to new users based on pre-authorization
 */
exports.onUserCreate = functions.auth.user().onCreate(async (user) => {
    const phoneNumber = user.phoneNumber;
    if (!phoneNumber) return null;

    const docId = phoneNumber.replace('+', '');
    const authRef = admin.firestore().collection('pre_authorized_users').doc(docId);
    const authDoc = await authRef.get();

    let assignedRole = 'UserRole.customer';
    let assignedName = 'Fufaji User';

    if (authDoc.exists) {
        assignedRole = authDoc.data().role || assignedRole;
        assignedName = authDoc.data().name || assignedName;
    }

    const userRef = admin.firestore().collection('users').doc(user.uid);

    await userRef.set({
        id: user.uid,
        phoneNumber: phoneNumber,
        name: assignedName,
        role: assignedRole,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastLogin: admin.firestore.FieldValue.serverTimestamp(),
        isAuthorized: authDoc.exists
    }, { merge: true });

    console.log(`User created: ${user.uid} (${phoneNumber}). Assigned role: ${assignedRole}`);
    return null;
});

/**
 * Securely set a user's role
 * Only admins can update roles of other users.
 */
exports.setRole = functions.https.onCall(async (data, context) => {
    // 1. Check if the requester is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'The function must be called while authenticated.'
        );
    }

    const { targetUserId, newRole } = data;

    if (!targetUserId || !newRole) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Missing targetUserId or newRole.'
        );
    }

    try {
        // 2. Check if the requester is an admin
        const requesterRef = admin.firestore().collection('users').doc(context.auth.uid);
        const requesterDoc = await requesterRef.get();

        if (!requesterDoc.exists || requesterDoc.data().role !== 'UserRole.admin') {
            throw new functions.https.HttpsError(
                'permission-denied',
                'Only admins can change user roles.'
            );
        }

        // 3. Update the target user's role
        const targetRef = admin.firestore().collection('users').doc(targetUserId);
        await targetRef.update({
            role: newRole,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // 4. Log the action for auditing
        await admin.firestore().collection('audit_logs').add({
            userId: context.auth.uid,
            userName: requesterDoc.data().name || 'Admin',
            action: 'AuditAction.roleChange',
            description: `Changed role of user ${targetUserId} to ${newRole}`,
            metadata: { targetUserId, newRole },
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        return { success: true, message: `Role updated to ${newRole} for user ${targetUserId}` };
    } catch (error) {
        console.error('Error setting role:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});

/**
 * Helper function to format phone number for Twilio
 * Converts Indian phone numbers to international format
 */
function formatPhoneNumber(phoneNumber) {
    // Remove all non-digit characters
    const digits = phoneNumber.replace(/\D/g, '');

    // If it starts with 0, remove it (Indian format)
    if (digits.startsWith('0')) {
        return '+91' + digits.substring(1);
    }

    // If it doesn't start with country code, add +91
    if (!digits.startsWith('91')) {
        return '+91' + digits;
    }

    return '+' + digits;
}

/**
 * Initiate Rider Payout via Razorpay route/transfers
 */
exports.initiateRiderPayout = functions.runWith({
    secrets: ['RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET']
}).https.onCall(async (data, context) => {
    try {
        const { riderAccountId, amount, currency } = data;

        if (!riderAccountId || !amount) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'Missing required parameters: riderAccountId, amount'
            );
        }

        console.log(`Initiating secure transfer of ₹${amount} to Razorpay account: ${riderAccountId}`);

        const keyId = process.env.RAZORPAY_KEY_ID;
        const keySecret = process.env.RAZORPAY_KEY_SECRET;
        
        if (!keyId || !keySecret) {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'Razorpay is not configured with key_id or key_secret on the backend.'
            );
        }

        const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
        const postData = JSON.stringify({
            account: riderAccountId,
            amount: Math.round(amount * 100), // convert to paise
            currency: currency || 'INR',
            notes: {
                info: 'Rider Payout Transfer via Route API'
            }
        });

        const https = require('https');
        const result = await new Promise((resolve, reject) => {
            const req = https.request({
                hostname: 'api.razorpay.com',
                port: 443,
                path: '/v1/transfers',
                method: 'POST',
                headers: {
                    'Authorization': `Basic ${auth}`,
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(postData)
                }
            }, (res) => {
                let responseBody = '';
                res.on('data', (chunk) => responseBody += chunk);
                res.on('end', () => {
                    try {
                        resolve({ statusCode: res.statusCode, body: JSON.parse(responseBody) });
                    } catch (e) {
                        resolve({ statusCode: res.statusCode, body: responseBody });
                    }
                });
            });

            req.on('error', (err) => reject(err));
            req.write(postData);
            req.end();
        });

        if (result.statusCode >= 200 && result.statusCode < 300) {
            console.log(`Rider payout transfer successful: ${result.body.id}`);
            return {
                success: true,
                transferId: result.body.id,
                message: 'Transfer processed successfully via Razorpay Route API'
            };
        } else {
            console.error('Razorpay Route Transfer Error Response:', result.body);
            const errDescription = result.body && result.body.error ? result.body.error.description : 'Failed to process payout';
            return {
                success: false,
                error: errDescription,
                message: errDescription
            };
        }
    } catch (error) {
        console.error('Error initiating rider payout:', error);
        throw new functions.https.HttpsError(
            'internal',
            'Failed to process payout: ' + error.message
        );
    }
});

/**
 * Scheduled: Hourly Inventory Alert Check
 * Checks for low stock and generates alerts based on sales velocity
 */
exports.checkInventoryAlerts = functions.pubsub.schedule('every 1 hours').onRun(async (context) => {
    const shopsSnapshot = await admin.firestore().collection('shops').get();
    
    for (const shopDoc of shopsSnapshot.docs) {
        const shopId = shopDoc.id;
        const productsSnapshot = await admin.firestore()
            .collection('shops')
            .doc(shopId)
            .collection('products')
            .where('stockQuantity', '<=', 10) // Basic threshold
            .get();

        for (const productDoc of productsSnapshot.docs) {
            const product = productDoc.data();
            
            // Logic for predictive alerts based on sales velocity would go here
            // For now, create a simple alert
            await admin.firestore().collection('inventory_alerts').add({
                shopId,
                productId: productDoc.id,
                productName: product.name,
                currentStock: product.stockQuantity,
                severity: product.stockQuantity <= 2 ? 'critical' : 'medium',
                status: 'active',
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }
    }
    return null;
});

/**
 * Scheduled: Hourly Expiry Date Tracking
 * Checks for expiring items and applies dynamic markdown pricing
 */
exports.processExpiries = functions.pubsub.schedule('every 1 hours').onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const threeDaysFromNow = new admin.firestore.Timestamp(now.seconds + (3 * 24 * 60 * 60), 0);

    const productsSnapshot = await admin.firestore()
        .collectionGroup('products')
        .where('expiryDate', '<=', threeDaysFromNow)
        .get();

    for (const productDoc of productsSnapshot.docs) {
        const product = productDoc.data();
        if (product.expiryDate <= now) {
            // Item expired: mark as unavailable or auto-discount to 90% off
            await productDoc.ref.update({
                isAvailable: false,
                status: 'expired'
            });
        } else {
            // Near expiry: Apply 20% discount automatically
            const originalPrice = product.originalPrice || product.price;
            const discountedPrice = originalPrice * 0.8;
            await productDoc.ref.update({
                price: discountedPrice,
                isDiscounted: true,
                discountPercentage: 20,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }
    }
    return null;
});

/**
 * Scheduled: Hourly Dynamic Pricing Adjuster
 * Adjusts prices based on competitor data or demand velocity
 */
exports.updateDynamicPricing = functions.pubsub.schedule('every 1 hours').onRun(async (context) => {
    // This would typically fetch from a competitor price index or analyze recent sales velocity
    console.log('Running Dynamic Pricing Adjuster...');
    // Simulated logic: Adjust high-demand items up by 2%, low-demand down by 5%
    return null;
});

/**
 * Scheduled: Daily Expiry Alert Check (FEFO & Expiry Warnings)
 * Runs every 24 hours to scan inventory batches for items expiring in less than 15 days,
 * and pushes a high-priority notification to branch staff.
 */
exports.checkExpiryAlerts = functions.pubsub.schedule('0 0 * * *').timeZone('Asia/Kolkata').onRun(async (context) => {
    const now = new Date();
    const fifteenDaysFromNow = new Date(now.getTime() + 15 * 24 * 60 * 60 * 1000);
    const fifteenDaysTimestamp = admin.firestore.Timestamp.fromDate(fifteenDaysFromNow);

    console.log(`Running checkExpiryAlerts daily scan. Expiry threshold: ${fifteenDaysFromNow.toISOString()}`);

    try {
        // Query all inventory batches expiring in less than 15 days
        const batchesSnapshot = await admin.firestore()
            .collectionGroup('inventory_batches')
            .where('expiryDate', '<=', fifteenDaysTimestamp)
            .get();

        console.log(`Found ${batchesSnapshot.size} batches expiring soon.`);

        if (batchesSnapshot.empty) {
            return null;
        }

        // Cache product names and users to avoid redundant reads
        const productCache = {};
        const branchUsersCache = {};

        for (const batchDoc of batchesSnapshot.docs) {
            const batch = batchDoc.data();
            
            // Extract shopId and branchId from path: /shops/{shopId}/branches/{branchId}/inventory_batches/{batchId}
            const pathSegments = batchDoc.ref.path.split('/');
            if (pathSegments.length < 5) continue;
            const shopId = pathSegments[1];
            const branchId = pathSegments[3];

            // Verify quantity is active and batch isn't fully depleted
            if (!batch.quantity || batch.quantity <= 0) continue;

            const expDate = batch.expiryDate ? batch.expiryDate.toDate() : null;
            if (!expDate) continue;

            // Check if already expired
            if (expDate < now) continue;

            const daysRemaining = Math.ceil((expDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

            // Fetch product name (with caching)
            const productKey = `${shopId}_${branchId}_${batch.productId}`;
            if (!productCache[productKey]) {
                const productDoc = await admin.firestore()
                    .collection('shops')
                    .doc(shopId)
                    .collection('branches')
                    .doc(branchId)
                    .collection('products')
                    .doc(batch.productId)
                    .get();
                productCache[productKey] = productDoc.exists ? productDoc.data().name : 'Unknown Product';
            }
            const productName = productCache[productKey];

            // Fetch branch staff (with caching)
            const branchKey = `${shopId}_${branchId}`;
            if (!branchUsersCache[branchKey]) {
                const usersSnapshot = await admin.firestore().collection('users')
                    .where('isActive', '==', true)
                    .get();

                const staff = [];
                usersSnapshot.forEach(userDoc => {
                    const userData = userDoc.data();
                    const isStaffRole = ['UserRole.employee', 'UserRole.shopOwner', 'UserRole.admin'].includes(userData.role) ||
                        (userData.roles && userData.roles.some(r => ['UserRole.employee', 'UserRole.shopOwner', 'UserRole.admin'].includes(r)));
                    const isAssigned = userData.branchId === branchId || userData.assignedBranchId === branchId || userData.shopId === shopId;
                    
                    if (isStaffRole && isAssigned && userData.fcmToken) {
                        staff.push(userData.fcmToken);
                    }
                });
                branchUsersCache[branchKey] = staff;
            }
            const fcmTokens = branchUsersCache[branchKey];

            if (fcmTokens.length === 0) {
                console.log(`No active branch staff with FCM tokens found for branch ${branchId}`);
                continue;
            }

            // Create low stock/expiry alert document in Firestore for visibility on dashboard
            const alertId = `expiry_alert_${batchDoc.id}`;
            await admin.firestore()
                .collection('shops')
                .doc(shopId)
                .collection('branches')
                .doc(branchId)
                .collection('inventory_alerts')
                .doc(alertId)
                .set({
                    id: alertId,
                    type: 'near_expiry',
                    productId: batch.productId,
                    productName: productName,
                    batchId: batch.batchId,
                    currentStock: batch.quantity,
                    expiryDate: batch.expiryDate,
                    severity: daysRemaining <= 5 ? 'critical' : 'high',
                    status: 'pending',
                    message: `Batch ${batch.batchId} of ${productName} is expiring in ${daysRemaining} days. Qty: ${batch.quantity}.`,
                    createdAt: admin.firestore.FieldValue.serverTimestamp()
                }, { merge: true });

            // Send FCM notifications to all branch staff
            const messages = fcmTokens.map(token => ({
                notification: {
                    title: `⚠️ Near Expiry Alert: ${productName}`,
                    body: `Batch ${batch.batchId} (${batch.quantity} units) is expiring in ${daysRemaining} days! Mark it down now.`
                },
                data: {
                    type: 'expiryWarning',
                    batchId: batch.batchId,
                    productId: batch.productId,
                    shopId: shopId,
                    branchId: branchId
                },
                token: token
            }));

            try {
                await Promise.all(messages.map(msg => admin.messaging().send(msg)));
                console.log(`Sent expiry warnings to ${fcmTokens.length} staff members for batch ${batch.batchId}`);
            } catch (err) {
                console.error(`Error sending FCM messages for batch ${batch.batchId}:`, err);
            }
        }
    } catch (error) {
        console.error('Error executing checkExpiryAlerts:', error);
    }
    return null;
});


// ═══════════════════════════════════════════════════════════════════════
// TASK 12: NOTIFICATION QUEUE → FCM PROCESSOR
// ═══════════════════════════════════════════════════════════════════════
// Processes the notification_queue collection populated by the WhatsApp
// fallback system (sendWithFallback in whatsapp_notification_service.dart)
// and sends actual FCM push notifications.

/**
 * Process FCM Notification Queue
 * Triggered when a new document is created in notification_queue.
 * Sends FCM push notification and updates the document status.
 */
exports.processNotificationQueue = functions.firestore
    .document('notification_queue/{docId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const { userId, fcmToken, title, body, orderId, type } = data;

        if (!fcmToken) {
            console.log(`[NotificationQueue] No FCM token for notification ${context.params.docId}. Skipping.`);
            await snap.ref.update({ status: 'skipped', reason: 'no_fcm_token', processedAt: admin.firestore.FieldValue.serverTimestamp() });
            return null;
        }

        try {
            const message = {
                notification: {
                    title: title || '📦 Fufaji Update',
                    body: body || 'You have a new notification.',
                },
                data: {
                    orderId: orderId || '',
                    type: type || 'general',
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                },
                token: fcmToken,
            };

            const response = await admin.messaging().send(message);

            console.log(`[NotificationQueue] FCM sent to ${userId}: ${response}`);
            await snap.ref.update({
                status: 'sent',
                fcmResponse: response,
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        } catch (error) {
            console.error(`[NotificationQueue] Error sending FCM to ${userId}:`, error);

            let errorReason = error.message;
            let shouldRemoveToken = false;

            // Handle invalid/expired FCM tokens
            if (error.code === 'messaging/invalid-registration-token' ||
                error.code === 'messaging/registration-token-not-registered') {
                shouldRemoveToken = true;
                errorReason = 'invalid_or_expired_token';

                // Remove stale FCM token from user profile
                try {
                    await admin.firestore().collection('users').doc(userId).update({
                        fcmToken: admin.firestore.FieldValue.delete(),
                        fcmTokenRemovedAt: admin.firestore.FieldValue.serverTimestamp(),
                        fcmTokenRemovalReason: errorReason,
                    });
                    console.log(`[NotificationQueue] Removed stale FCM token for user ${userId}`);
                } catch (tokenError) {
                    console.error(`[NotificationQueue] Error removing stale token:`, tokenError);
                }
            }

            await snap.ref.update({
                status: 'failed',
                error: errorReason,
                tokenRemoved: shouldRemoveToken,
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Fallback to in-app notification
            try {
                await admin.firestore().collection('users').doc(userId).collection('notifications').add({
                    title: title || 'Fufaji Update',
                    body: body || 'You have a new notification.',
                    orderId: orderId || '',
                    type: type || 'general',
                    read: false,
                    source: 'fcm_fallback',
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            } catch (fallbackError) {
                console.error(`[NotificationQueue] In-app fallback also failed:`, fallbackError);
            }
        }
        return null;
    });


// ═══════════════════════════════════════════════════════════════════════
// TASK 11 (SUPPLEMENT): ORPHAN PAYMENT RECONCILIATION SCANNER
// ═══════════════════════════════════════════════════════════════════════
// Catches orders stuck in "pending" payment status that webhooks missed.

/**
 * Scheduled: Reconcile Orphaned Payments (every 15 minutes)
 * Scans for orders stuck in "pending" payment status for >15 min
 * and checks if their payment was actually captured.
 */
exports.reconcileOrphanedPayments = functions.pubsub
    .schedule('every 15 minutes')
    .timeZone('Asia/Kolkata')
    .onRun(async (context) => {
        console.log('[ReconcileOrphan] Starting orphan payment scan...');

        try {
            const cutoffTime = new Date(Date.now() - 15 * 60 * 1000);
            const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffTime);

            // Find orders stuck in pending payment state
            const snapshot = await admin.firestore()
                .collection('orders')
                .where('paymentStatus', '==', 'pending')
                .where('createdAt', '<', cutoffTimestamp)
                .limit(50)
                .get();

            if (snapshot.empty) {
                console.log('[ReconcileOrphan] No orphaned orders found.');
                return null;
            }

            console.log(`[ReconcileOrphan] Found ${snapshot.size} orphaned orders to check.`);

            let reconciled = 0;
            let failedOrExpired = 0;

            for (const doc of snapshot.docs) {
                const orderData = doc.data();
                const paymentId = orderData.paymentId;

                if (!paymentId || paymentId === '') {
                    // No payment ID — mark as expired after 30 minutes
                    const createdAt = orderData.createdAt?.toDate();
                    const thirtyMinAgo = new Date(Date.now() - 30 * 60 * 1000);
                    if (createdAt && createdAt < thirtyMinAgo) {
                        await doc.ref.update({
                            paymentStatus: 'expired',
                            status: 'OrderStatus.cancelled',
                            cancellationReason: 'Payment not received within 30 minutes',
                            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                            reconciliationSource: 'orphan_scanner_timeout',
                        });
                        failedOrExpired++;
                    }
                    continue;
                }

                // Check if payment was actually captured in payments collection
                const paymentDoc = await admin.firestore()
                    .collection('payments')
                    .doc(paymentId)
                    .get();

                if (paymentDoc.exists && paymentDoc.data().status === 'captured') {
                    await doc.ref.update({
                        paymentStatus: 'paid',
                        status: 'OrderStatus.confirmed',
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        reconciliationSource: 'orphan_scanner',
                        reconciledAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                    reconciled++;
                    console.log(`[ReconcileOrphan] Reconciled: ${doc.id}`);
                }

                // Also check webhook_events to see if a payment.captured was received
                const webhookQuery = await admin.firestore()
                    .collection('webhook_events')
                    .where('paymentId', '==', paymentId)
                    .limit(1)
                    .get();

                if (!webhookQuery.empty && !paymentDoc.exists) {
                    // Webhook received but payment record missing — reconstruct
                    const webhookData = webhookQuery.docs[0].data();
                    await doc.ref.update({
                        paymentStatus: 'paid',
                        status: 'OrderStatus.confirmed',
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        reconciliationSource: 'orphan_scanner_webhook_match',
                        reconciledAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                    reconciled++;
                }
            }

            // Log the scan results
            await admin.firestore().collection('payment_reconciliation_log').add({
                action: 'orphan_scan_complete',
                totalScanned: snapshot.size,
                reconciled: reconciled,
                expiredOrFailed: failedOrExpired,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`[ReconcileOrphan] Scan complete. Reconciled: ${reconciled}, Expired: ${failedOrExpired}`);
            return null;
        } catch (error) {
            console.error('[ReconcileOrphan] Error:', error);
            return null;
        }
    });


// ═══════════════════════════════════════════════════════════════════════
// TASK 13: DAILY FIRESTORE BACKUP TO GCS
// ═══════════════════════════════════════════════════════════════════════
// Automated daily export of all Firestore collections to Google Cloud
// Storage for disaster recovery.

/**
 * Scheduled: Daily Firestore Backup (2:00 AM IST)
 * Exports all Firestore documents to a GCS bucket.
 * 
 * SETUP REQUIRED:
 * 1. Create a GCS bucket: gs://fufaji-online-business-backups
 * 2. Grant the default service account the 'Cloud Datastore Import Export Admin' role
 * 3. Grant the GCS bucket write access to the service account
 * 
 * Run this in Cloud Console:
 *   gcloud projects add-iam-policy-binding fufaji-online-business \
 *     --member="serviceAccount:fufaji-online-business@appspot.gserviceaccount.com" \
 *     --role="roles/datastore.importExportAdmin"
 */
exports.dailyFirestoreBackup = functions.pubsub
    .schedule('0 20 * * *') // 2:00 AM IST = 8:30 PM UTC (adjusted for 5.5h offset)
    .timeZone('Asia/Kolkata')
    .onRun(async (context) => {
        const projectId = process.env.GCLOUD_PROJECT || 'fufaji-online-business';
        const bucket = `gs://${projectId}-backups`;

        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const outputUriPrefix = `${bucket}/firestore-exports/${timestamp}`;

        console.log(`[FirestoreBackup] Starting daily backup to ${outputUriPrefix}`);

        try {
            // Use the Firestore Admin API to export documents
            const client = new admin.firestore.v1.FirestoreAdminClient();
            const databaseName = client.databasePath(projectId, '(default)');

            const [response] = await client.exportDocuments({
                name: databaseName,
                outputUriPrefix: outputUriPrefix,
                // Export all collections (empty array = all)
                collectionIds: [],
            });

            console.log(`[FirestoreBackup] Export operation started: ${response.name}`);

            // Log the backup metadata
            await admin.firestore().collection('system_backups').add({
                type: 'firestore_export',
                operationName: response.name,
                outputUri: outputUriPrefix,
                status: 'started',
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                scheduledBy: 'dailyFirestoreBackup',
            });

            return null;
        } catch (error) {
            console.error('[FirestoreBackup] Error starting export:', error);

            // Log the failure
            await admin.firestore().collection('system_backups').add({
                type: 'firestore_export',
                status: 'failed',
                error: error.message,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                scheduledBy: 'dailyFirestoreBackup',
            }).catch(() => {});

            return null;
        }
    });


// ═══════════════════════════════════════════════════════════════════════
// CLEANUP: Stale Notification Queue Purge (Weekly)
// ═══════════════════════════════════════════════════════════════════════

/**
 * Scheduled: Weekly cleanup of processed notifications (Sunday 3 AM IST)
 * Deletes notification_queue documents that were processed >7 days ago.
 */
// ═══════════════════════════════════════════════════════════════════════
// DAILY OWNER REPORT — WhatsApp Summary at 10 PM IST
// ═══════════════════════════════════════════════════════════════════════

/**
 * Sends a daily WhatsApp business summary to the shop owner at 10 PM IST.
 * Calculates: order count, revenue, pending vs delivered, top 3 products.
 * Owner phone is read from Firestore settings/shop_config → ownerPhone.
 */
exports.sendDailyOwnerReport = functions.runWith({
    secrets: ['WHATSAPP_TOKEN', 'WHATSAPP_PHONE_ID']
}).pubsub
    .schedule('0 22 * * *')
    .timeZone('Asia/Kolkata')
    .onRun(async (context) => {
        console.log('[DailyReport] Starting daily owner report...');

        try {
            const WHATSAPP_TOKEN = process.env.WHATSAPP_TOKEN || '';
            const WHATSAPP_PHONE_ID = process.env.WHATSAPP_PHONE_ID || '';

            if (!WHATSAPP_TOKEN || !WHATSAPP_PHONE_ID) {
                console.error('[DailyReport] Missing WHATSAPP_TOKEN or WHATSAPP_PHONE_ID config.');
                return null;
            }

            // Get owner phone from settings
            const settingsDoc = await admin.firestore()
                .collection('settings')
                .doc('shop_config')
                .get();

            if (!settingsDoc.exists) {
                console.error('[DailyReport] settings/shop_config not found.');
                return null;
            }

            const ownerPhone = settingsDoc.data().ownerPhone;
            if (!ownerPhone) {
                console.error('[DailyReport] ownerPhone not set in shop_config.');
                return null;
            }

            // Normalize phone
            let cleanPhone = ownerPhone.replace(/\D/g, '');
            if (cleanPhone.length === 10) cleanPhone = '91' + cleanPhone;
            else if (!cleanPhone.startsWith('91')) cleanPhone = '91' + cleanPhone;

            // Today's midnight IST → UTC offset is -5.5h, so midnight IST = 18:30 UTC previous day
            const now = new Date();
            const istOffset = 5.5 * 60 * 60 * 1000;
            const nowIST = new Date(now.getTime() + istOffset);
            const midnightIST = new Date(nowIST);
            midnightIST.setHours(0, 0, 0, 0);
            const midnightUTC = new Date(midnightIST.getTime() - istOffset);
            const midnightTimestamp = admin.firestore.Timestamp.fromDate(midnightUTC);

            // Query today's orders
            const ordersSnap = await admin.firestore()
                .collection('orders')
                .where('createdAt', '>=', midnightTimestamp)
                .get();

            const orders = ordersSnap.docs.map(d => d.data());

            const totalOrders = orders.length;
            const totalRevenue = orders.reduce((sum, o) => sum + (o.totalAmount || 0), 0);
            const deliveredOrders = orders.filter(o =>
                (o.status || '').toLowerCase().includes('delivered')
            ).length;
            const pendingOrders = orders.filter(o =>
                !(o.status || '').toLowerCase().includes('delivered') &&
                !(o.status || '').toLowerCase().includes('cancelled')
            ).length;
            const avgOrder = totalOrders > 0 ? (totalRevenue / totalOrders) : 0;

            // Top 3 products by order frequency
            const productCount = {};
            for (const order of orders) {
                const items = order.items || [];
                for (const item of items) {
                    const name = item.productName || 'Unknown';
                    productCount[name] = (productCount[name] || 0) + (item.quantity || 1);
                }
            }
            const topProducts = Object.entries(productCount)
                .sort((a, b) => b[1] - a[1])
                .slice(0, 3);

            // Format date in IST
            const dateStr = nowIST.toLocaleDateString('en-IN', {
                day: '2-digit',
                month: 'short',
                year: 'numeric',
                timeZone: 'Asia/Kolkata',
            });

            // Build message
            let topProductsText = '';
            if (topProducts.length === 0) {
                topProductsText = '• Koi bhi orders nahi aaye aaj';
            } else {
                topProductsText = topProducts
                    .map(([name, count]) => `• ${name} - ${count} orders`)
                    .join('\n');
            }

            const message =
`🏪 *Fufaji's Online - Aaj Ki Report*
📅 ${dateStr}

📦 Total Orders: ${totalOrders}
✅ Delivered: ${deliveredOrders}
⏳ Pending: ${pendingOrders}
💰 Revenue: ₹${Math.round(totalRevenue)}
📈 Average Order: ₹${Math.round(avgOrder)}

🔥 Top Products:
${topProductsText}

Kal bhi badiya din ho! 🙏
- Fufaji's Online Team`;

            // Send via Meta WhatsApp API (uses Node 18+ native fetch)
            const response = await fetch(
                `https://graph.facebook.com/v25.0/${WHATSAPP_PHONE_ID}/messages`,
                {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${WHATSAPP_TOKEN}`,
                    },
                    body: JSON.stringify({
                        messaging_product: 'whatsapp',
                        to: cleanPhone,
                        type: 'text',
                        text: { body: message },
                    }),
                }
            );

            const result = await response.json();

            if (response.ok) {
                console.log(`[DailyReport] Report sent to owner ${cleanPhone}. MsgId: ${result.messages?.[0]?.id}`);
            } else {
                console.error('[DailyReport] WhatsApp API error:', JSON.stringify(result));
            }

            // Log the report for records
            await admin.firestore().collection('daily_reports').add({
                date: dateStr,
                totalOrders,
                totalRevenue,
                deliveredOrders,
                pendingOrders,
                avgOrder,
                topProducts: topProducts.map(([name, count]) => ({ name, count })),
                sentTo: cleanPhone,
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
                status: response.ok ? 'sent' : 'failed',
            });

            return null;
        } catch (error) {
            console.error('[DailyReport] Error:', error);
            return null;
        }
    });


// ═══════════════════════════════════════════════════════════════════════
// SMART DELIVERY CLUSTERING — Group nearby orders into trips
// ═══════════════════════════════════════════════════════════════════════

/**
 * HTTP Callable: clusterDeliveryOrders
 * Input:  { orderIds: string[] }
 * Output: { clusters: string[][] }  — each sub-array is a trip of order IDs
 *
 * Algorithm: Sorts orders by latitude, then groups consecutive orders
 * within 1.5 km of each other into a single delivery trip/cluster.
 */
exports.clusterDeliveryOrders = functions.https.onCall(async (data, context) => {
    const { orderIds } = data;

    if (!Array.isArray(orderIds) || orderIds.length === 0) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'orderIds must be a non-empty array of strings.'
        );
    }

    const MAX_CLUSTER_RADIUS_KM = 1.5;

    /**
     * Haversine distance between two lat/lng points in km.
     */
    function haversineKm(lat1, lng1, lat2, lng2) {
        const R = 6371;
        const dLat = ((lat2 - lat1) * Math.PI) / 180;
        const dLng = ((lng2 - lng1) * Math.PI) / 180;
        const a =
            Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos((lat1 * Math.PI) / 180) *
                Math.cos((lat2 * Math.PI) / 180) *
                Math.sin(dLng / 2) *
                Math.sin(dLng / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    try {
        // Fetch all requested orders in parallel
        const orderDocs = await Promise.all(
            orderIds.map(id => admin.firestore().collection('orders').doc(id).get())
        );

        // Build array of { id, lat, lng } — skip orders with no location
        const located = [];
        for (const doc of orderDocs) {
            if (!doc.exists) continue;
            const d = doc.data();
            const addr = d.deliveryAddress || {};
            const lat = addr.latitude ?? addr.lat ?? null;
            const lng = addr.longitude ?? addr.lng ?? null;
            if (lat !== null && lng !== null) {
                located.push({ id: doc.id, lat: Number(lat), lng: Number(lng) });
            } else {
                // No geo-data: put each such order in its own cluster
                located.push({ id: doc.id, lat: null, lng: null });
            }
        }

        // Separate orders with and without location data
        const withLocation = located.filter(o => o.lat !== null);
        const withoutLocation = located.filter(o => o.lat === null);

        // Sort by latitude for simple consecutive grouping
        withLocation.sort((a, b) => a.lat - b.lat);

        // Greedy clustering: start a new cluster whenever distance to
        // cluster centroid exceeds MAX_CLUSTER_RADIUS_KM
        const clusters = [];
        let currentCluster = [];
        let clusterCentroidLat = null;
        let clusterCentroidLng = null;

        for (const order of withLocation) {
            if (currentCluster.length === 0) {
                currentCluster.push(order.id);
                clusterCentroidLat = order.lat;
                clusterCentroidLng = order.lng;
            } else {
                const dist = haversineKm(
                    clusterCentroidLat, clusterCentroidLng,
                    order.lat, order.lng
                );
                if (dist <= MAX_CLUSTER_RADIUS_KM) {
                    currentCluster.push(order.id);
                    // Update centroid as average
                    clusterCentroidLat = (clusterCentroidLat * (currentCluster.length - 1) + order.lat) / currentCluster.length;
                    clusterCentroidLng = (clusterCentroidLng * (currentCluster.length - 1) + order.lng) / currentCluster.length;
                } else {
                    clusters.push([...currentCluster]);
                    currentCluster = [order.id];
                    clusterCentroidLat = order.lat;
                    clusterCentroidLng = order.lng;
                }
            }
        }
        if (currentCluster.length > 0) clusters.push([...currentCluster]);

        // Each order without location becomes its own solo cluster
        for (const o of withoutLocation) {
            clusters.push([o.id]);
        }

        console.log(`[ClusterDelivery] ${orderIds.length} orders → ${clusters.length} clusters`);
        return { clusters };
    } catch (error) {
        console.error('[ClusterDelivery] Error:', error);
        throw new functions.https.HttpsError('internal', 'Clustering failed: ' + error.message);
    }
});


exports.cleanupNotificationQueue = functions.pubsub
    .schedule('0 21 * * 0') // Sunday 3 AM IST = Saturday 9:30 PM UTC
    .timeZone('Asia/Kolkata')
    .onRun(async (context) => {
        console.log('[Cleanup] Starting notification queue cleanup...');

        try {
            const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
            const cutoff = admin.firestore.Timestamp.fromDate(sevenDaysAgo);

            const snapshot = await admin.firestore()
                .collection('notification_queue')
                .where('status', 'in', ['sent', 'skipped', 'failed'])
                .where('processedAt', '<', cutoff)
                .limit(500)
                .get();

            if (snapshot.empty) {
                console.log('[Cleanup] No stale notifications to clean.');
                return null;
            }

            const batch = admin.firestore().batch();
            snapshot.docs.forEach(doc => batch.delete(doc.ref));
            await batch.commit();

            console.log(`[Cleanup] Deleted ${snapshot.size} processed notifications.`);
            return null;
        } catch (error) {
            console.error('[Cleanup] Error:', error);
            return null;
        }
    });

// ═══════════════════════════════════════════════════════════════════════
// ON-DEMAND DAILY OWNER REPORT — Triggered by app's "Send Test Report" button
// ═══════════════════════════════════════════════════════════════════════

/**
 * Firestore-triggered function: watches 'report_trigger_queue' collection.
 * When the Flutter app writes a doc with type='daily_owner_report',
 * this function runs the same report as sendDailyOwnerReport immediately.
 * This powers the "Send Test Report Now" button in Shop Settings.
 */
exports.onReportTriggerRequest = functions.runWith({
    secrets: ['WHATSAPP_TOKEN', 'WHATSAPP_PHONE_ID']
}).firestore
    .document('report_trigger_queue/{docId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();

        if (data.type !== 'daily_owner_report') return null;
        if (data.status !== 'pending') return null;

        console.log('[OnDemandReport] Test report requested by owner...');

        // Mark as processing
        await snap.ref.update({ status: 'processing', startedAt: admin.firestore.FieldValue.serverTimestamp() });

        try {
            const WHATSAPP_TOKEN = process.env.WHATSAPP_TOKEN || '';
            const WHATSAPP_PHONE_ID = process.env.WHATSAPP_PHONE_ID || '';

            if (!WHATSAPP_TOKEN || !WHATSAPP_PHONE_ID) {
                console.error('[OnDemandReport] Missing WhatsApp config.');
                await snap.ref.update({ status: 'failed', error: 'Missing WhatsApp config' });
                return null;
            }

            const settingsDoc = await admin.firestore().collection('settings').doc('shop_config').get();
            if (!settingsDoc.exists) {
                await snap.ref.update({ status: 'failed', error: 'shop_config not found' });
                return null;
            }

            const ownerPhone = settingsDoc.data().ownerPhone;
            if (!ownerPhone) {
                await snap.ref.update({ status: 'failed', error: 'ownerPhone not set' });
                return null;
            }

            let cleanPhone = ownerPhone.replace(/\D/g, '');
            if (cleanPhone.length === 10) cleanPhone = '91' + cleanPhone;
            else if (!cleanPhone.startsWith('91')) cleanPhone = '91' + cleanPhone;

            // Calculate today's stats
            const now = new Date();
            const istOffset = 5.5 * 60 * 60 * 1000;
            const nowIST = new Date(now.getTime() + istOffset);
            const midnightIST = new Date(nowIST);
            midnightIST.setHours(0, 0, 0, 0);
            const midnightUTC = new Date(midnightIST.getTime() - istOffset);
            const midnightTimestamp = admin.firestore.Timestamp.fromDate(midnightUTC);

            const ordersSnap = await admin.firestore()
                .collection('orders')
                .where('createdAt', '>=', midnightTimestamp)
                .get();

            const orders = ordersSnap.docs.map(d => d.data());
            const totalOrders = orders.length;
            const totalRevenue = orders.reduce((sum, o) => sum + (o.totalAmount || 0), 0);
            const deliveredOrders = orders.filter(o => (o.status || '').toLowerCase().includes('delivered')).length;
            const pendingOrders = orders.filter(o =>
                !(o.status || '').toLowerCase().includes('delivered') &&
                !(o.status || '').toLowerCase().includes('cancelled')
            ).length;
            const avgOrder = totalOrders > 0 ? (totalRevenue / totalOrders) : 0;

            const productCount = {};
            for (const order of orders) {
                for (const item of (order.items || [])) {
                    const name = item.productName || 'Unknown';
                    productCount[name] = (productCount[name] || 0) + (item.quantity || 1);
                }
            }
            const topProducts = Object.entries(productCount).sort((a, b) => b[1] - a[1]).slice(0, 3);

            const dateStr = nowIST.toLocaleDateString('en-IN', {
                day: '2-digit', month: 'short', year: 'numeric', timeZone: 'Asia/Kolkata',
            });

            const topProductsText = topProducts.length === 0
                ? '• Koi bhi orders nahi aaye aaj'
                : topProducts.map(([name, count]) => `• ${name} - ${count} orders`).join('\n');

            const message =
`🧪 *TEST REPORT — Fufaji's Online*
📅 ${dateStr} (on-demand)

📦 Total Orders: ${totalOrders}
✅ Delivered: ${deliveredOrders}
⏳ Pending: ${pendingOrders}
💰 Revenue: ₹${Math.round(totalRevenue)}
📈 Average Order: ₹${Math.round(avgOrder)}

🔥 Top Products:
${topProductsText}

Yeh test report tha. Real report 10 PM pe aayega! 🙏
- Fufaji's Online Team`;

            const response = await fetch(
                `https://graph.facebook.com/v25.0/${WHATSAPP_PHONE_ID}/messages`,
                {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${WHATSAPP_TOKEN}`,
                    },
                    body: JSON.stringify({
                        messaging_product: 'whatsapp',
                        to: cleanPhone,
                        type: 'text',
                        text: { body: message },
                    }),
                }
            );

            const result = await response.json();
            const success = response.ok;

            await snap.ref.update({
                status: success ? 'sent' : 'failed',
                completedAt: admin.firestore.FieldValue.serverTimestamp(),
                whatsappResponse: JSON.stringify(result).substring(0, 200),
            });

            console.log(`[OnDemandReport] ${success ? 'Sent to' : 'Failed for'} ${cleanPhone}`);
            return null;

        } catch (error) {
            console.error('[OnDemandReport] Error:', error);
            await snap.ref.update({ status: 'error', error: error.message });
            return null;
        }
    });

// ═══════════════════════════════════════════════════════════════════════
// LOW STOCK WHATSAPP ALERT — Firestore trigger on product update
// ═══════════════════════════════════════════════════════════════════════

/**
 * Firestore trigger: fires when a product document is updated.
 * If stockQuantity drops below minimumStock, sends WhatsApp to:
 *   1. Owner (from settings/shop_config.ownerPhone)
 *   2. Supplier (from product.supplierPhone, if set)
 */
exports.sendLowStockWhatsAppAlert = functions.runWith({
    secrets: ['WHATSAPP_TOKEN', 'WHATSAPP_PHONE_ID']
}).firestore
    .document('products/{productId}')
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();

        const stockBefore = before.stockQuantity ?? Infinity;
        const stockAfter = after.stockQuantity ?? 0;
        const minimumStock = after.minimumStock ?? 10;

        // Only fire if stock just crossed below minimum
        const justWentLow = stockAfter < minimumStock && stockBefore >= minimumStock;
        if (!justWentLow) return null;

        const WHATSAPP_TOKEN = process.env.WHATSAPP_TOKEN || '';
        const PHONE_ID = process.env.WHATSAPP_PHONE_ID || '';

        if (!WHATSAPP_TOKEN || !PHONE_ID) {
            console.warn('[LowStockAlert] Missing WhatsApp config. Skipping.');
            return null;
        }

        const productName = after.name || 'Unknown Product';
        const unit = after.unit || 'units';
        const productId = context.params.productId;

        const ownerMessage =
`⚠️ *Low Stock Alert — Fufaji's Online*

📦 *Product:* ${productName}
📉 *Current Stock:* ${stockAfter} ${unit}
🔴 *Minimum Level:* ${minimumStock} ${unit}

Jaldi reorder karein ya supplier ko contact karein!
- Fufaji's Online System`;

        const supplierMessage =
`📦 *Reorder Request — Fufaji's Online*

Namaste! Hamara ${productName} ka stock low ho gaya hai.

📉 Current: ${stockAfter} ${unit}
📋 Product ID: ${productId}

Kripya jald se jald supply bhejein.
- Fufaji's Online, Baran`;

        // Helper to send WhatsApp
        const sendWA = async (toPhone, body) => {
            let cleanPhone = toPhone.replace(/\D/g, '');
            if (cleanPhone.length === 10) cleanPhone = '91' + cleanPhone;
            else if (!cleanPhone.startsWith('91')) cleanPhone = '91' + cleanPhone;

            const res = await fetch(
                `https://graph.facebook.com/v18.0/${PHONE_ID}/messages`,
                {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${WHATSAPP_TOKEN}`,
                    },
                    body: JSON.stringify({
                        messaging_product: 'whatsapp',
                        to: cleanPhone,
                        type: 'text',
                        text: { body },
                    }),
                }
            );
            const json = await res.json();
            if (!res.ok) {
                console.error(`[LowStockAlert] WA send failed to ${cleanPhone}:`, JSON.stringify(json));
            } else {
                console.log(`[LowStockAlert] WA sent to ${cleanPhone}: ${json.messages?.[0]?.id}`);
            }
        };

        try {
            // 1. Send to owner
            const settingsDoc = await admin.firestore().collection('settings').doc('shop_config').get();
            if (settingsDoc.exists && settingsDoc.data().ownerPhone) {
                await sendWA(settingsDoc.data().ownerPhone, ownerMessage);
            }

            // 2. Send to supplier (if configured on the product)
            const supplierPhone = after.supplierPhone;
            if (supplierPhone) {
                await sendWA(supplierPhone, supplierMessage);
            }

            // 3. Log the alert
            await admin.firestore().collection('low_stock_alerts').add({
                productId,
                productName,
                stockAfter,
                minimumStock,
                unit,
                supplierPhone: supplierPhone || null,
                alertSentAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        } catch (err) {
            console.error('[LowStockAlert] Error:', err);
        }

        return null;
    });


// ═══════════════════════════════════════════════════════════════════════
// GENERATE AND SEND INVOICE — HTTP Callable
// ═══════════════════════════════════════════════════════════════════════

/**
 * HTTP Callable: generateAndSendInvoice
 * Input:  { orderId: string }
 * Builds an invoice from the order in Firestore and sends it
 * via WhatsApp to the customer's phone number.
 */
exports.generateAndSendInvoice = functions.runWith({
    secrets: ['WHATSAPP_TOKEN', 'WHATSAPP_PHONE_ID']
}).https.onCall(async (data, context) => {
    const { orderId } = data;

    if (!orderId) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'orderId is required.'
        );
    }

    const WHATSAPP_TOKEN = process.env.WHATSAPP_TOKEN || '';
    const PHONE_ID = process.env.WHATSAPP_PHONE_ID || '';

    if (!WHATSAPP_TOKEN || !PHONE_ID) {
        throw new functions.https.HttpsError(
            'failed-precondition',
            'WhatsApp not configured on the backend.'
        );
    }

    try {
        const orderDoc = await admin.firestore().collection('orders').doc(orderId).get();
        if (!orderDoc.exists) {
            throw new functions.https.HttpsError('not-found', `Order ${orderId} not found.`);
        }

        const order = orderDoc.data();
        const orderNumber = order.orderNumber || orderId.substring(0, 8).toUpperCase();
        const customerPhone = order.customerPhone || order.deliveryAddress?.phone;

        if (!customerPhone) {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'Customer phone not found on order.'
            );
        }

        // Build invoice text
        const items = order.items || [];
        let itemLines = '';
        for (const item of items) {
            const name = item.productName || item.name || 'Item';
            const qty = item.quantity || 1;
            const unit = item.unit || 'pcs';
            const price = item.price || item.unitPrice || 0;
            const total = (qty * price).toFixed(2);
            itemLines += `  • ${name}: ${qty} ${unit} × ₹${price} = ₹${total}\n`;
        }

        const subtotal = order.subtotal ?? order.totalAmount ?? 0;
        const deliveryFee = order.deliveryFee ?? 0;
        const discount = order.discount ?? 0;
        const total = order.totalAmount ?? subtotal;

        const createdAt = order.createdAt?.toDate
            ? order.createdAt.toDate().toLocaleDateString('en-IN', {
                day: '2-digit',
                month: 'short',
                year: 'numeric',
                timeZone: 'Asia/Kolkata',
            })
            : new Date().toLocaleDateString('en-IN', { timeZone: 'Asia/Kolkata' });

        const paymentMethod = order.paymentMethod || 'COD';
        const paymentStatus = order.paymentStatus || 'pending';

        const invoiceMessage =
`🧾 *INVOICE — Fufaji's Online*
━━━━━━━━━━━━━━━━━━━━━━
📋 Order #${orderNumber}
📅 Date: ${createdAt}
━━━━━━━━━━━━━━━━━━━━━━

*Items:*
${itemLines}
━━━━━━━━━━━━━━━━━━━━━━
🛒 Subtotal:    ₹${subtotal.toFixed ? subtotal.toFixed(2) : subtotal}
🚴 Delivery:    ₹${deliveryFee}
${discount > 0 ? `🎁 Discount:    -₹${discount}\n` : ''}💰 *TOTAL:       ₹${total.toFixed ? total.toFixed(2) : total}*
━━━━━━━━━━━━━━━━━━━━━━
💳 Payment: ${paymentMethod.toUpperCase()} (${paymentStatus})

Aapka shukriya! 🙏
Fufaji's Online — Baran, Rajasthan
`;

        // Normalize phone
        let cleanPhone = customerPhone.replace(/\D/g, '');
        if (cleanPhone.length === 10) cleanPhone = '91' + cleanPhone;
        else if (!cleanPhone.startsWith('91')) cleanPhone = '91' + cleanPhone;

        const response = await fetch(
            `https://graph.facebook.com/v18.0/${PHONE_ID}/messages`,
            {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${WHATSAPP_TOKEN}`,
                },
                body: JSON.stringify({
                    messaging_product: 'whatsapp',
                    to: cleanPhone,
                    type: 'text',
                    text: { body: invoiceMessage },
                }),
            }
        );

        const result = await response.json();

        if (!response.ok) {
            console.error(`[Invoice] WA send failed: ${JSON.stringify(result)}`);
            throw new functions.https.HttpsError('internal', 'WhatsApp send failed.');
        }

        // Mark invoice as sent on the order
        await orderDoc.ref.update({
            invoiceSentAt: admin.firestore.FieldValue.serverTimestamp(),
            invoiceMessageId: result.messages?.[0]?.id || '',
        });

        console.log(`[Invoice] Invoice sent for order ${orderNumber} to ${cleanPhone}`);

        return {
            success: true,
            messageId: result.messages?.[0]?.id,
            sentTo: cleanPhone,
            orderNumber,
        };

    } catch (err) {
        if (err instanceof functions.https.HttpsError) throw err;
        console.error('[Invoice] Error:', err);
        throw new functions.https.HttpsError('internal', 'Invoice generation failed: ' + err.message);
    }
});

// ═══════════════════════════════════════════════════════════════════════
// [DUPLICATE REMOVED] sendDailyOwnerReport already defined above (line ~1425)
// ═══════════════════════════════════════════════════════════════════════

// NOTE: The duplicate sendDailyOwnerReport that was here has been replaced
// by the new sendLowStockWhatsAppAlert and generateAndSendInvoice functions.
// See the first sendDailyOwnerReport definition (pubsub schedule '0 22 * * *').

/**
 * Create Razorpay Order
 * Initiates an order on Razorpay and returns the order ID to the client
 */
exports.createRazorpayOrder = functions.runWith({
    secrets: ['RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET']
}).https.onCall(async (data, context) => {
    try {
        const { amount, currency, receipt, notes } = data;

        if (!amount) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'Missing required parameter: amount'
            );
        }

        const keyId = process.env.RAZORPAY_KEY_ID;
        const keySecret = process.env.RAZORPAY_KEY_SECRET;

        if (!keyId || !keySecret) {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'Razorpay is not configured on the backend.'
            );
        }

        const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
        const postData = JSON.stringify({
            amount: Math.round(amount * 100), // convert to paise
            currency: currency || 'INR',
            receipt: receipt || `receipt_${Date.now()}`,
            notes: notes || {}
        });

        const https = require('https');
        const result = await new Promise((resolve, reject) => {
            const req = https.request({
                hostname: 'api.razorpay.com',
                port: 443,
                path: '/v1/orders',
                method: 'POST',
                headers: {
                    'Authorization': `Basic ${auth}`,
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(postData)
                }
            }, (res) => {
                let responseBody = '';
                res.on('data', (chunk) => responseBody += chunk);
                res.on('end', () => {
                    try {
                        resolve({ statusCode: res.statusCode, body: JSON.parse(responseBody) });
                    } catch (e) {
                        resolve({ statusCode: res.statusCode, body: responseBody });
                    }
                });
            });

            req.on('error', (err) => reject(err));
            req.write(postData);
            req.end();
        });

        if (result.statusCode >= 200 && result.statusCode < 300) {
            return {
                success: true,
                razorpayOrderId: result.body.id,
                amount: result.body.amount,
                currency: result.body.currency
            };
        } else {
            console.error('Razorpay Order Creation Error:', result.body);
            throw new functions.https.HttpsError('internal', 'Failed to create Razorpay order');
        }
    } catch (error) {
        console.error('Error creating Razorpay order:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});

/**
 * Razorpay Refund Handler
 * Initiates a refund for a payment
 */
exports.initiateRazorpayRefund = functions.runWith({
    secrets: ['RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET']
}).https.onCall(async (data, context) => {
    try {
        // 1. Authorization check
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'Login required');
        }

        const requesterRef = admin.firestore().collection('users').doc(context.auth.uid);
        const requesterDoc = await requesterRef.get();
        if (!requesterDoc.exists || (requesterDoc.data().role !== 'UserRole.admin' && requesterDoc.data().role !== 'UserRole.shopOwner')) {
            throw new functions.https.HttpsError('permission-denied', 'Unauthorized');
        }

        const { paymentId, amount, notes } = data;

        if (!paymentId) {
            throw new functions.https.HttpsError('invalid-argument', 'Missing paymentId');
        }

        const keyId = process.env.RAZORPAY_KEY_ID;
        const keySecret = process.env.RAZORPAY_KEY_SECRET;
        const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');

        const postData = JSON.stringify({
            amount: amount ? Math.round(amount * 100) : undefined, // in paise
            notes: notes || { reason: 'Refund from Owner Panel' }
        });

        const https = require('https');
        const result = await new Promise((resolve, reject) => {
            const req = https.request({
                hostname: 'api.razorpay.com', port: 443,
                path: `/v1/payments/${paymentId}/refund`,
                method: 'POST',
                headers: {
                    'Authorization': `Basic ${auth}`,
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(postData)
                }
            }, (res) => {
                let body = '';
                res.on('data', (chunk) => body += chunk);
                res.on('end', () => resolve({ statusCode: res.statusCode, body: JSON.parse(body) }));
            });
            req.on('error', reject);
            req.write(postData);
            req.end();
        });

        if (result.statusCode >= 200 && result.statusCode < 300) {
            // Record Refund Transaction in Ledger
            const ordersQuery = await admin.firestore().collection('orders')
                .where('paymentId', '==', paymentId)
                .limit(1).get();

            if (!ordersQuery.empty) {
                const order = ordersQuery.docs[0].data();
                await admin.firestore().collection('transactions').add({
                    orderId: order.id,
                    orderNumber: order.orderNumber,
                    customerId: order.customerId,
                    amount: amount || (order.totalAmount),
                    type: 'TransactionType.refund',
                    status: 'TransactionStatus.completed',
                    paymentMethod: 'razorpay',
                    gatewayTransactionId: result.body.id,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    notes: 'Refund initiated via Owner Panel'
                });
            }

            return { success: true, refundId: result.body.id };
        } else {
            console.error('Razorpay Refund Error:', result.body);
            return { success: false, error: result.body.error?.description || 'Refund failed' };
        }
    } catch (error) {
        console.error('Refund Exception:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});

/**
 * Notify Admin of a new device registration request
 */
exports.notifyNewDevice = functions.https.onCall(async (data, context) => {
    const { userId, deviceName } = data;

    if (!userId || !deviceName) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing userId or deviceName');
    }

    try {
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        const userName = userDoc.data()?.name || 'Unknown Owner';

        // Notify Admins
        const adminsSnapshot = await admin.firestore().collection('users')
            .where('role', '==', 'UserRole.admin').get();

        const notifications = adminsSnapshot.docs.map(adminDoc => {
            const token = adminDoc.data().fcmToken;
            if (token) {
                return admin.messaging().send({
                    notification: {
                        title: '🔒 New Device Security Alert',
                        body: `${userName} is trying to log in from a new device: ${deviceName}. Please approve in Admin Panel.`,
                    },
                    token: token,
                    data: { type: 'deviceApproval', userId }
                });
            }
            return null;
        }).filter(n => n !== null);

        await Promise.all(notifications);
        return { success: true };
    } catch (error) {
        console.error('Error notifying admin of new device:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});

exports._placeholder_end = functions.runWith({
    secrets: ['WHATSAPP_TOKEN', 'WHATSAPP_PHONE_ID']
}).pubsub
    .schedule('30 16 * * *') // 16:30 UTC = 22:00 IST
    .timeZone('UTC') // Using UTC to explicitly map 16:30
    .onRun(async (context) => {
        console.log('[DailyReport] Generating 10 PM owner report...');

        try {
            const WHATSAPP_TOKEN = process.env.WHATSAPP_TOKEN || '';
            const WHATSAPP_PHONE_ID = process.env.WHATSAPP_PHONE_ID || '';

            if (!WHATSAPP_TOKEN || !WHATSAPP_PHONE_ID) {
                console.error('[DailyReport] Missing WhatsApp config. Skipping.');
                return null;
            }

            const settingsDoc = await admin.firestore().collection('settings').doc('shop_config').get();
            if (!settingsDoc.exists) {
                console.error('[DailyReport] shop_config not found.');
                return null;
            }

            const ownerPhone = settingsDoc.data().ownerPhone;
            if (!ownerPhone) {
                console.error('[DailyReport] ownerPhone not set.');
                return null;
            }

            let cleanPhone = ownerPhone.replace(/\D/g, '');
            if (cleanPhone.length === 10) cleanPhone = '91' + cleanPhone;
            else if (!cleanPhone.startsWith('91')) cleanPhone = '91' + cleanPhone;

            // Calculate today's stats
            const now = new Date();
            const istOffset = 5.5 * 60 * 60 * 1000;
            const nowIST = new Date(now.getTime() + istOffset);
            const midnightIST = new Date(nowIST);
            midnightIST.setHours(0, 0, 0, 0);
            const midnightUTC = new Date(midnightIST.getTime() - istOffset);
            const midnightTimestamp = admin.firestore.Timestamp.fromDate(midnightUTC);

            const ordersSnap = await admin.firestore()
                .collection('orders')
                .where('createdAt', '>=', midnightTimestamp)
                .get();

            const orders = ordersSnap.docs.map(d => d.data());
            const totalOrders = orders.length;
            const totalRevenue = orders.reduce((sum, o) => sum + (o.totalAmount || 0), 0);
            const deliveredOrders = orders.filter(o => (o.status || '').toLowerCase().includes('delivered')).length;
            const pendingOrders = orders.filter(o =>
                !(o.status || '').toLowerCase().includes('delivered') &&
                !(o.status || '').toLowerCase().includes('cancelled')
            ).length;
            const avgOrder = totalOrders > 0 ? (totalRevenue / totalOrders) : 0;

            const productCount = {};
            for (const order of orders) {
                for (const item of (order.items || [])) {
                    const name = item.productName || 'Unknown';
                    productCount[name] = (productCount[name] || 0) + (item.quantity || 1);
                }
            }
            const topProducts = Object.entries(productCount).sort((a, b) => b[1] - a[1]).slice(0, 3);

            const dateStr = nowIST.toLocaleDateString('en-IN', {
                day: '2-digit', month: 'short', year: 'numeric', timeZone: 'Asia/Kolkata',
            });

            const topProductsText = topProducts.length === 0
                ? '• Aaj koi order nahi aaya'
                : topProducts.map(([name, count]) => `• ${name} - ${count} orders`).join('\n');

            const message =
`📊 *Daily Shop Report — Fufaji's Online*
📅 ${dateStr}

📦 *Total Orders:* ${totalOrders}
✅ *Delivered:* ${deliveredOrders}
⏳ *Pending:* ${pendingOrders}
💰 *Revenue:* ₹${Math.round(totalRevenue)}
📈 *Avg Order:* ₹${Math.round(avgOrder)}

🔥 *Top Selling Items:*
${topProductsText}

Great job today! Aaraam se so jao. 🌙
- Fufaji's Online Automation`;

            const response = await fetch(
                `https://graph.facebook.com/v25.0/${WHATSAPP_PHONE_ID}/messages`,
                {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${WHATSAPP_TOKEN}`,
                    },
                    body: JSON.stringify({
                        messaging_product: 'whatsapp',
                        to: cleanPhone,
                        type: 'text',
                        text: { body: message },
                    }),
                }
            );

            const result = await response.json();
            if (response.ok) {
                console.log(`[DailyReport] Sent successfully to ${cleanPhone}`);
            } else {
                console.error(`[DailyReport] Failed to send: ${JSON.stringify(result)}`);
            }
            
            // Log run
            await admin.firestore().collection('system_logs').add({
                action: 'daily_report_sent',
                phone: cleanPhone,
                success: response.ok,
                timestamp: admin.firestore.FieldValue.serverTimestamp()
            });

            return null;

        } catch (error) {
            console.error('[DailyReport] Fatal Error:', error);
            return null;
        }
    });

/**
 * Synchronize User Claims based on Firestore records.
 * This is a callable function that checks if the caller's email exists in owners or employees,
 * and sets their Custom User Claims accordingly in Firebase Auth.
 */
exports.syncUserClaims = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'The function must be called while authenticated.'
        );
    }

    const uid = context.auth.uid;
    const email = context.auth.token.email;

    if (!email) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Authenticated user does not have an email address associated with their account.'
        );
    }

    try {
        // 1. Check if owner
        const ownerSnapshot = await admin.firestore()
            .collection('owners')
            .where('email', '==', email)
            .limit(1)
            .get();

        if (!ownerSnapshot.empty) {
            const ownerData = ownerSnapshot.docs[0].data();
            const claims = { role: 'owner', employeeRole: null, isActive: true };
            await admin.auth().setCustomUserClaims(uid, claims);
            console.log(`[syncUserClaims] Assigned OWNER claims to ${email} (${uid})`);
            return { success: true, ...claims };
        }

        // 2. Check if employee
        const employeeSnapshot = await admin.firestore()
            .collection('employees')
            .where('email', '==', email)
            .limit(1)
            .get();

        if (!employeeSnapshot.empty) {
            const employeeData = employeeSnapshot.docs[0].data();
            const claims = { 
                role: 'employee', 
                employeeRole: employeeData.role || 'packer', 
                isActive: employeeData.isActive !== false 
            };
            
            // Also link the UID to the employee record if it isn't set yet
            if (!employeeData.uid || employeeData.uid !== uid) {
                await employeeSnapshot.docs[0].ref.update({
                    uid: uid,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
            }

            await admin.auth().setCustomUserClaims(uid, claims);
            console.log(`[syncUserClaims] Assigned EMPLOYEE claims to ${email} (${uid}), role: ${claims.employeeRole}, isActive: ${claims.isActive}`);
            return { success: true, ...claims };
        }

        // 3. Fallback: No admin/employee privileges
        const claims = { role: null, employeeRole: null, isActive: false };
        await admin.auth().setCustomUserClaims(uid, claims);
        console.log(`[syncUserClaims] Removed claims for ${email} (${uid})`);
        return { success: true, ...claims };

    } catch (error) {
        console.error('[syncUserClaims] Error setting claims:', error);
        throw new functions.https.HttpsError('internal', 'Internal error synchronizing custom claims: ' + error.message);
    }
});

/**
 * Firestore Trigger: Sync claims on Owner Write.
 * Automatically updates claims for owners when their document changes.
 */
exports.onOwnerWrite = functions.firestore
    .document('owners/{ownerId}')
    .onWrite(async (change, context) => {
        const data = change.after.exists ? change.after.data() : null;
        const oldData = change.before.exists ? change.before.data() : null;
        
        const email = data ? data.email : (oldData ? oldData.email : null);
        if (!email) return null;

        try {
            const userRecord = await admin.auth().getUserByEmail(email);
            if (!change.after.exists) {
                // Document deleted, clear claims
                await admin.auth().setCustomUserClaims(userRecord.uid, { role: null, employeeRole: null, isActive: false });
                console.log(`[onOwnerWrite] Cleared owner claims for deleted owner ${email}`);
            } else {
                // Document created/updated, set claims
                await admin.auth().setCustomUserClaims(userRecord.uid, { role: 'owner', employeeRole: null, isActive: true });
                console.log(`[onOwnerWrite] Synchronized owner claims for ${email}`);
            }
        } catch (error) {
            // User might not have logged in / signed up yet, ignore user-not-found
            if (error.code !== 'auth/user-not-found') {
                console.error(`[onOwnerWrite] Error syncing claims for owner ${email}:`, error);
            }
        }
        return null;
    });

/**
 * Firestore Trigger: Sync claims on Employee Write.
 * Automatically updates claims for employees when their document changes.
 */
exports.onEmployeeWrite = functions.firestore
    .document('employees/{employeeId}')
    .onWrite(async (change, context) => {
        const data = change.after.exists ? change.after.data() : null;
        const oldData = change.before.exists ? change.before.data() : null;
        
        const email = data ? data.email : (oldData ? oldData.email : null);
        if (!email) return null;

        try {
            const userRecord = await admin.auth().getUserByEmail(email);
            if (!change.after.exists) {
                // Document deleted, clear claims
                await admin.auth().setCustomUserClaims(userRecord.uid, { role: null, employeeRole: null, isActive: false });
                console.log(`[onEmployeeWrite] Cleared employee claims for deleted employee ${email}`);
            } else {
                // Document created/updated, sync claims
                const claims = {
                    role: 'employee',
                    employeeRole: data.role || 'packer',
                    isActive: data.isActive !== false
                };
                await admin.auth().setCustomUserClaims(userRecord.uid, claims);
                console.log(`[onEmployeeWrite] Synchronized employee claims for ${email}:`, claims);
            }
        } catch (error) {
            // Ignore user-not-found
            if (error.code !== 'auth/user-not-found') {
                console.error(`[onEmployeeWrite] Error syncing claims for employee ${email}:`, error);
            }
        }
        return null;
    });

// ═══════════════════════════════════════════════════════════════════════
// NEW CALLABLE PROXIES FOR HARDENED CLIENT SECURITY
// ═══════════════════════════════════════════════════════════════════════

/**
 * Callable function to query Gemini model securely from the client side without exposing keys.
 */
exports.geminiCall = functions.runWith({
    secrets: ['GEMINI_API_KEY']
}).https.onCall(async (data, context) => {
    const { prompt, image, mimeType } = data;

    if (!prompt) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing prompt parameter.');
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
        throw new functions.https.HttpsError('failed-precondition', 'Gemini API key is not configured.');
    }

    try {
        const { GoogleGenerativeAI } = require('@google/generative-ai');
        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

        const parts = [];
        if (image && mimeType) {
            parts.push({
                inlineData: {
                    data: image,
                    mimeType: mimeType
                }
            });
        }
        parts.push(prompt);

        const result = await model.generateContent(parts);
        const response = await result.response;
        const text = response.text();

        return { success: true, text: text };
    } catch (error) {
        console.error('[geminiCall] Exception:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});

/**
 * Callable function to send WhatsApp notifications securely from the client side without exposing tokens.
 */
exports.sendWhatsAppNotification = functions.runWith({
    secrets: ['WHATSAPP_TOKEN', 'WHATSAPP_PHONE_ID']
}).https.onCall(async (data, context) => {
    const { to, type, text, template, interactive } = data;

    if (!to || !type) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing to or type parameter.');
    }

    const token = process.env.WHATSAPP_TOKEN;
    const phoneId = process.env.WHATSAPP_PHONE_ID;

    if (!token || !phoneId) {
        throw new functions.https.HttpsError('failed-precondition', 'WhatsApp service is not configured on server.');
    }

    const payload = {
        messaging_product: 'whatsapp',
        to: to,
        type: type,
    };
    if (text) payload.text = text;
    if (template) payload.template = template;
    if (interactive) payload.interactive = interactive;

    try {
        const response = await fetch(
            `https://graph.facebook.com/v25.0/${phoneId}/messages`,
            {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`,
                },
                body: JSON.stringify(payload),
            }
        );

        const result = await response.json();
        if (response.ok) {
            return { success: true, data: result };
        } else {
            console.error('[sendWhatsAppNotification] Meta API error:', result);
            return { success: false, error: result };
        }
    } catch (error) {
        console.error('[sendWhatsAppNotification] Exception:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});

// ═══════════════════════════════════════════════════════════════════════
// EXPORTS FROM OTHER MODULES
// ═══════════════════════════════════════════════════════════════════════

Object.assign(exports, require('./aws_services'));
Object.assign(exports, require('./firestore_sync'));
Object.assign(exports, require('./pg_backup'));
Object.assign(exports, require('./automation_rules_engine'));

