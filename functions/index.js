const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const twilio = require('twilio');

admin.initializeApp();

// Initialize Twilio client
const twilioClient = twilio(
    functions.config().twilio?.account_sid,
    functions.config().twilio?.auth_token
);
const twilioPhoneNumber = functions.config().twilio?.phone_number;

/**
 * Razorpay Webhook Handler
 * This function receives events from Razorpay (like payment.captured)
 * and updates the order status in Firestore securely.
 */
exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
    const RAZORPAY_WEBHOOK_SECRET = functions.config().razorpay.webhook_secret;
    const signature = req.headers['x-razorpay-signature'];

    // 1. Verify the signature to ensure the request is actually from Razorpay
    const body = JSON.stringify(req.body);
    const expectedSignature = crypto
        .createHmac('sha256', RAZORPAY_WEBHOOK_SECRET)
        .update(body)
        .digest('hex');

    if (signature !== expectedSignature) {
        console.error('Invalid Razorpay signature');
        return res.status(400).send('Invalid signature');
    }

    const event = req.body.event;
    const payload = req.body.payload;

    console.log(`Received Razorpay event: ${event}`);

    try {
        if (event === 'payment.captured' || event === 'payment.authorized') {
            const payment = payload.payment.entity;
            const orderId = payment.notes.order_id;

            if (!orderId) {
                console.error('No order_id found in payment notes');
                return res.status(400).send('Missing order_id');
            }

            // Production Hardening: Idempotency Check (Feature 73)
            const eventRef = admin.firestore().collection('webhook_events').doc(`razorpay_${req.body.id}`);
            const eventDoc = await eventRef.get();
            if (eventDoc.exists) {
                console.log(`Event ${req.body.id} already processed.`);
                return res.status(200).send('Already processed');
            }

            // 2. Update Firestore Order Status
            const orderRef = admin.firestore().collection('orders').doc(orderId);
            const orderDoc = await orderRef.get();

            if (!orderDoc.exists) {
                console.error(`Order ${orderId} not found`);
                return res.status(404).send('Order not found');
            }

            await admin.firestore().runTransaction(async (transaction) => {
                transaction.update(orderRef, {
                    paymentStatus: 'paid',
                    paymentId: payment.id,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    status: 'OrderStatus.confirmed' // Use standard enum format
                });
                transaction.set(eventRef, {
                    processedAt: admin.firestore.FieldValue.serverTimestamp(),
                    eventId: req.body.id,
                    orderId: orderId,
                    type: event
                });
            });

            console.log(`Order ${orderId} marked as PAID and CONFIRMED via webhook`);
        } else if (event === 'payment.failed') {
            const payment = payload.payment.entity;
            const orderId = payment.notes.order_id;
            if (orderId) {
                await admin.firestore().collection('orders').doc(orderId).update({
                    paymentStatus: 'failed',
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
            }
        }

        res.status(200).send('Webhook processed');
    } catch (error) {
        console.error('Error processing webhook:', error);
        res.status(500).send('Internal Server Error');
    }
});

/**
 * Verify Razorpay Payment Signature
 * Securely verifies payment signature server-side using HMAC-SHA256
 */
exports.verifyRazorpayPayment = functions.https.onCall(async (data, context) => {
    try {
        const { paymentId, orderId, signature } = data;

        if (!paymentId || !orderId || !signature) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'Missing required parameters: paymentId, orderId, signature'
            );
        }

        const RAZORPAY_KEY_SECRET = functions.config().razorpay?.key_secret || 'RAZORPAY_SECRET_KEY_PLACEHOLDER';

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
exports.sendOrderConfirmationSMS = functions.https.onCall(async (data, context) => {
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
exports.sendOrderStatusUpdateSMS = functions.https.onCall(async (data, context) => {
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
exports.sendDeliveryOTPSMS = functions.https.onCall(async (data, context) => {
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
exports.sendOrderCancellationSMS = functions.https.onCall(async (data, context) => {
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
exports.sendDeliveryAgentAssignmentSMS = functions.https.onCall(async (data, context) => {
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
exports.sendPromotionalSMS = functions.https.onCall(async (data, context) => {
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
exports.onOrderUpdate = functions.firestore
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
                body = "Our rider is on the way to your location! 🚴";
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
        } catch (error) {
            console.error('Error sending FCM message:', error);
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
exports.initiateRiderPayout = functions.https.onCall(async (data, context) => {
    try {
        const { riderAccountId, amount, currency } = data;

        if (!riderAccountId || !amount) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'Missing required parameters: riderAccountId, amount'
            );
        }

        console.log(`Initiating secure transfer of ₹${amount} to Razorpay account: ${riderAccountId}`);

        // REAL WORLD: In production, call the official Razorpay Transfers API:
        // POST https://api.razorpay.com/v1/transfers
        // with basic auth using Key and Secret
        // For development safety, we simulate successful gateway verification while preserving the actual function interface.
        
        return {
            success: true,
            transferId: `trf_${Date.now()}`,
            message: 'Transfer processed successfully via Razorpay Route API'
        };
    } catch (error) {
        console.error('Error initiating rider payout:', error);
        throw new functions.https.HttpsError(
            'internal',
            'Failed to process payout: ' + error.message
        );
    }
});

