package com.fufaji.store.services;

import android.content.Context;
import android.os.Build;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import com.fufaji.store.R;
import com.google.firebase.messaging.FirebaseMessaging;

import timber.log.Timber;

public class NotificationManager {
    private static NotificationManager instance;
    private final Context context;
    private final NotificationManagerCompat notificationManager;
    private static final String CHANNEL_ORDERS = "orders";
    private static final String CHANNEL_PAYMENTS = "payments";
    private static final String CHANNEL_DELIVERY = "delivery";

    private NotificationManager(Context context) {
        this.context = context;
        this.notificationManager = NotificationManagerCompat.from(context);
        createNotificationChannels();
    }

    public static synchronized NotificationManager getInstance(Context context) {
        if (instance == null) {
            instance = new NotificationManager(context.getApplicationContext());
        }
        return instance;
    }

    private void createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Orders channel
            android.app.NotificationChannel ordersChannel = new android.app.NotificationChannel(
                    CHANNEL_ORDERS,
                    "Orders",
                    android.app.NotificationManager.IMPORTANCE_HIGH
            );
            ordersChannel.setDescription("Notifications about orders");

            // Payments channel
            android.app.NotificationChannel paymentsChannel = new android.app.NotificationChannel(
                    CHANNEL_PAYMENTS,
                    "Payments",
                    android.app.NotificationManager.IMPORTANCE_HIGH
            );
            paymentsChannel.setDescription("Notifications about payments");

            // Delivery channel
            android.app.NotificationChannel deliveryChannel = new android.app.NotificationChannel(
                    CHANNEL_DELIVERY,
                    "Delivery",
                    android.app.NotificationManager.IMPORTANCE_DEFAULT
            );
            deliveryChannel.setDescription("Notifications about deliveries");

            android.app.NotificationManager manager = context.getSystemService(android.app.NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(ordersChannel);
                manager.createNotificationChannel(paymentsChannel);
                manager.createNotificationChannel(deliveryChannel);
            }
        }
    }

    // ===== ORDER NOTIFICATIONS =====

    public void notifyOrderPlaced(String orderId, double total) {
        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ORDERS)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle("Order Placed! 🎉")
                .setContentText("Order #" + orderId + " - Total: ₹" + (long)total)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH);

        notificationManager.notify((int) System.currentTimeMillis(), builder.build());
        Timber.d("Order placed notification: %s", orderId);
    }

    public void notifyOrderConfirmed(String orderId) {
        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ORDERS)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle("Order Confirmed! ✓")
                .setContentText("Order #" + orderId + " has been confirmed")
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH);

        notificationManager.notify((int) System.currentTimeMillis(), builder.build());
    }

    public void notifyOrderPacked(String orderId) {
        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ORDERS)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle("Order Packed! 📦")
                .setContentText("Order #" + orderId + " is being packed")
                .setAutoCancel(true);

        notificationManager.notify((int) System.currentTimeMillis(), builder.build());
    }

    // ===== DELIVERY NOTIFICATIONS =====

    public void notifyOutForDelivery(String orderId, String deliveryPartnerName) {
        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_DELIVERY)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle("Out for Delivery! 🚚")
                .setContentText("Order #" + orderId + " is out for delivery with " + deliveryPartnerName)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT);

        notificationManager.notify((int) System.currentTimeMillis(), builder.build());
    }

    public void notifyDeliveryCompleted(String orderId) {
        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_DELIVERY)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle("Delivered! ✓✓")
                .setContentText("Order #" + orderId + " has been delivered successfully")
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH);

        notificationManager.notify((int) System.currentTimeMillis(), builder.build());
    }

    // ===== PAYMENT NOTIFICATIONS =====

    public void notifyPaymentSuccess(String orderId, double amount) {
        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_PAYMENTS)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle("Payment Successful! 💳")
                .setContentText("₹" + (long)amount + " received for order #" + orderId)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH);

        notificationManager.notify((int) System.currentTimeMillis(), builder.build());
    }

    public void notifyPaymentFailed(String orderId) {
        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_PAYMENTS)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle("Payment Failed ✗")
                .setContentText("Payment for order #" + orderId + " failed. Please retry.")
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH);

        notificationManager.notify((int) System.currentTimeMillis(), builder.build());
    }

    // ===== INVENTORY NOTIFICATIONS =====

    public void notifyLowStock(String productName, int stockLevel) {
        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ORDERS)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle("Low Stock Alert! 📉")
                .setContentText(productName + " has only " + stockLevel + " items left")
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT);

        notificationManager.notify((int) System.currentTimeMillis(), builder.build());
    }

    // ===== FIREBASE MESSAGING =====

    public void subscribeToOrderUpdates(String userId) {
        FirebaseMessaging.getInstance().subscribeToTopic("orders_" + userId)
                .addOnSuccessListener(aVoid -> Timber.d("Subscribed to orders topic: %s", userId))
                .addOnFailureListener(e -> Timber.e(e, "Failed to subscribe to orders topic"));
    }

    public void unsubscribeFromOrderUpdates(String userId) {
        FirebaseMessaging.getInstance().unsubscribeFromTopic("orders_" + userId)
                .addOnSuccessListener(aVoid -> Timber.d("Unsubscribed from orders topic: %s", userId))
                .addOnFailureListener(e -> Timber.e(e, "Failed to unsubscribe from orders topic"));
    }

    public void subscribeToDeliveryUpdates(String deliveryPartnerId) {
        FirebaseMessaging.getInstance().subscribeToTopic("delivery_" + deliveryPartnerId)
                .addOnSuccessListener(aVoid -> Timber.d("Subscribed to delivery topic: %s", deliveryPartnerId))
                .addOnFailureListener(e -> Timber.e(e, "Failed to subscribe to delivery topic"));
    }
}
