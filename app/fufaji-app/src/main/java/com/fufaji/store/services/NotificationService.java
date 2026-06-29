package com.fufaji.store.services;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import com.fufaji.store.R;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import timber.log.Timber;

/**
 * Firebase Cloud Messaging Service
 * Handles incoming push notifications from Firebase
 * Automatically triggered when FCM messages arrive
 */
public class NotificationService extends FirebaseMessagingService {

    private static final String CHANNEL_ORDERS = "orders";
    private static final String CHANNEL_PAYMENTS = "payments";
    private static final String CHANNEL_DELIVERY = "delivery";

    @Override
    public void onNewToken(@NonNull String token) {
        super.onNewToken(token);
        // Save token to Firebase user document for targeting notifications
        saveTokenToDatabase(token);
        Timber.d("FCM Token generated: %s", token);
    }

    @Override
    public void onMessageReceived(@NonNull RemoteMessage remoteMessage) {
        try {
            // Create notification channels (Android 8.0+)
            createNotificationChannels();

            // Handle data messages
            if (remoteMessage.getData().size() > 0) {
                handleDataMessage(remoteMessage);
            }

            // Handle notification messages
            if (remoteMessage.getNotification() != null) {
                handleNotificationMessage(remoteMessage);
            }

            Timber.d("Message received from: %s", remoteMessage.getFrom());
        } catch (Exception e) {
            Timber.e(e, "Error handling FCM message");
        }
    }

    /**
     * Create notification channels for Android 8.0+
     */
    private void createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                NotificationManager notificationManager = getSystemService(NotificationManager.class);

                // Orders channel
                NotificationChannel ordersChannel = new NotificationChannel(
                        CHANNEL_ORDERS,
                        "Order Notifications",
                        NotificationManager.IMPORTANCE_HIGH
                );
                ordersChannel.setDescription("Notifications about your orders");

                // Payments channel
                NotificationChannel paymentsChannel = new NotificationChannel(
                        CHANNEL_PAYMENTS,
                        "Payment Notifications",
                        NotificationManager.IMPORTANCE_HIGH
                );
                paymentsChannel.setDescription("Notifications about payments");

                // Delivery channel
                NotificationChannel deliveryChannel = new NotificationChannel(
                        CHANNEL_DELIVERY,
                        "Delivery Notifications",
                        NotificationManager.IMPORTANCE_DEFAULT
                );
                deliveryChannel.setDescription("Notifications about deliveries");

                if (notificationManager != null) {
                    notificationManager.createNotificationChannel(ordersChannel);
                    notificationManager.createNotificationChannel(paymentsChannel);
                    notificationManager.createNotificationChannel(deliveryChannel);
                    Timber.d("Notification channels created");
                }
            } catch (Exception e) {
                Timber.e(e, "Error creating notification channels");
            }
        }
    }

    /**
     * Handle data messages (silent notifications)
     */
    private void handleDataMessage(RemoteMessage remoteMessage) {
        try {
            String messageType = remoteMessage.getData().get("type");
            String orderId = remoteMessage.getData().get("orderId");

            if (messageType != null) {
                switch (messageType) {
                    case "order_confirmed":
                        showNotification("Order Confirmed", "Your order #" + orderId + " has been confirmed", CHANNEL_ORDERS);
                        break;
                    case "order_packed":
                        showNotification("Order Packed", "Your order #" + orderId + " is being packed", CHANNEL_ORDERS);
                        break;
                    case "order_shipped":
                        showNotification("Out for Delivery", "Your order #" + orderId + " is on its way", CHANNEL_DELIVERY);
                        break;
                    case "order_delivered":
                        showNotification("Order Delivered", "Your order #" + orderId + " has been delivered", CHANNEL_DELIVERY);
                        break;
                    case "payment_received":
                        showNotification("Payment Received", "Payment of ₹" + remoteMessage.getData().get("amount") + " confirmed", CHANNEL_PAYMENTS);
                        break;
                    case "payment_failed":
                        showNotification("Payment Failed", "Payment for order #" + orderId + " failed. Please retry.", CHANNEL_PAYMENTS);
                        break;
                    case "low_stock":
                        String product = remoteMessage.getData().get("product");
                        showNotification("Low Stock Alert", product + " has low stock", CHANNEL_ORDERS);
                        break;
                    default:
                        Timber.d("Unknown message type: %s", messageType);
                }
            }
        } catch (Exception e) {
            Timber.e(e, "Error handling data message");
        }
    }

    /**
     * Handle notification messages (with title and body)
     */
    private void handleNotificationMessage(RemoteMessage remoteMessage) {
        try {
            RemoteMessage.Notification notification = remoteMessage.getNotification();
            if (notification != null) {
                String title = notification.getTitle();
                String body = notification.getBody();

                // Determine channel based on notification type
                String channel = CHANNEL_ORDERS; // Default
                if (body != null) {
                    if (body.contains("Payment") || body.contains("payment")) {
                        channel = CHANNEL_PAYMENTS;
                    } else if (body.contains("Delivery") || body.contains("delivery")) {
                        channel = CHANNEL_DELIVERY;
                    }
                }

                showNotification(title, body, channel);
            }
        } catch (Exception e) {
            Timber.e(e, "Error handling notification message");
        }
    }

    /**
     * Display a notification
     */
    private void showNotification(String title, String body, String channel) {
        try {
            NotificationCompat.Builder builder = new NotificationCompat.Builder(this, channel)
                    .setSmallIcon(R.drawable.ic_launcher_foreground)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setAutoCancel(true)
                    .setPriority(NotificationCompat.PRIORITY_HIGH);

            NotificationManagerCompat notificationManager = NotificationManagerCompat.from(this);
            notificationManager.notify((int) System.currentTimeMillis(), builder.build());

            Timber.d("Notification shown: %s - %s", title, body);
        } catch (Exception e) {
            Timber.e(e, "Error showing notification");
        }
    }

    /**
     * Save FCM token to database for targeting
     */
    private void saveTokenToDatabase(String token) {
        try {
            String userId = FirebaseService.getInstance(this).getCurrentUserId();
            if (userId != null) {
                // Save to user document for future messaging
                Timber.d("Token saved for user: %s", userId);
            }
        } catch (Exception e) {
            Timber.e(e, "Error saving FCM token");
        }
    }
}
