package com.fufaji.store.services;

import com.fufaji.store.models.Order;
import com.fufaji.store.utils.Constants;

import timber.log.Timber;

public class OrderProcessor {
    private static OrderProcessor instance;
    private final FirebaseService firebaseService;
    private final NotificationManager notificationManager;

    public interface OrderProcessListener {
        void onProcessingStart(String orderId);
        void onStatusUpdate(String orderId, String newStatus);
        void onError(String orderId, String error);
        void onProcessingComplete(String orderId);
    }

    private OrderProcessListener listener;

    private OrderProcessor(FirebaseService firebaseService, NotificationManager notificationManager) {
        this.firebaseService = firebaseService;
        this.notificationManager = notificationManager;
    }

    public static synchronized OrderProcessor getInstance(FirebaseService firebaseService, NotificationManager notificationManager) {
        if (instance == null) {
            instance = new OrderProcessor(firebaseService, notificationManager);
        }
        return instance;
    }

    public void setListener(OrderProcessListener listener) {
        this.listener = listener;
    }

    // ===== AUTOMATED ORDER WORKFLOW =====

    /**
     * Automatically process order through workflow
     * pending → confirmed → packed → out_for_delivery → delivered
     */
    public void processOrder(Order order) {
        if (listener != null) {
            listener.onProcessingStart(order.orderId);
        }

        Timber.d("Starting order processing: %s", order.orderId);

        // Step 1: Confirm order
        confirmOrder(order);
    }

    private void confirmOrder(Order order) {
        order.orderStatus = Constants.ORDER_STATUS_CONFIRMED;
        updateOrderInFirebase(order);

        if (listener != null) {
            listener.onStatusUpdate(order.orderId, Constants.ORDER_STATUS_CONFIRMED);
        }

        notificationManager.notifyOrderConfirmed(order.orderId);

        // Automatically pack after 2 minutes
        scheduleNextStep(order, Constants.ORDER_STATUS_CONFIRMED, 2000);
    }

    private void packOrder(Order order) {
        order.orderStatus = Constants.ORDER_STATUS_PACKED;
        updateOrderInFirebase(order);

        if (listener != null) {
            listener.onStatusUpdate(order.orderId, Constants.ORDER_STATUS_PACKED);
        }

        notificationManager.notifyOrderPacked(order.orderId);

        // Automatically assign for delivery
        scheduleNextStep(order, Constants.ORDER_STATUS_PACKED, 3000);
    }

    private void assignForDelivery(Order order) {
        order.orderStatus = Constants.ORDER_STATUS_OUT_FOR_DELIVERY;
        order.assignedDeliveryPartner = assignDeliveryPartner(order);
        updateOrderInFirebase(order);

        if (listener != null) {
            listener.onStatusUpdate(order.orderId, Constants.ORDER_STATUS_OUT_FOR_DELIVERY);
        }

        if (order.assignedDeliveryPartner != null) {
            notificationManager.notifyOutForDelivery(order.orderId, order.assignedDeliveryPartner);
        }

        // Mark as delivered after 5 minutes
        scheduleNextStep(order, Constants.ORDER_STATUS_OUT_FOR_DELIVERY, 5000);
    }

    private void completeDelivery(Order order) {
        order.orderStatus = Constants.ORDER_STATUS_DELIVERED;
        order.deliveredAt = System.currentTimeMillis();
        updateOrderInFirebase(order);

        if (listener != null) {
            listener.onStatusUpdate(order.orderId, Constants.ORDER_STATUS_DELIVERED);
            listener.onProcessingComplete(order.orderId);
        }

        notificationManager.notifyDeliveryCompleted(order.orderId);
        Timber.d("Order delivered: %s", order.orderId);
    }

    // ===== HELPER METHODS =====

    private void updateOrderInFirebase(Order order) {
        firebaseService.updateOrder(order,
                aVoid -> Timber.d("Order updated: %s", order.orderId),
                error -> {
                    Timber.e("Error updating order: %s", error);
                    if (listener != null) {
                        listener.onError(order.orderId, error);
                    }
                });
    }

    private void scheduleNextStep(Order order, String currentStatus, long delayMs) {
        new Thread(() -> {
            try {
                Thread.sleep(delayMs);
                Order updatedOrder = order;
                switch (currentStatus) {
                    case Constants.ORDER_STATUS_CONFIRMED:
                        packOrder(updatedOrder);
                        break;
                    case Constants.ORDER_STATUS_PACKED:
                        assignForDelivery(updatedOrder);
                        break;
                    case Constants.ORDER_STATUS_OUT_FOR_DELIVERY:
                        completeDelivery(updatedOrder);
                        break;
                }
            } catch (InterruptedException e) {
                Timber.e(e, "Error scheduling next step");
            }
        }).start();
    }

    private String assignDeliveryPartner(Order order) {
        // Simple assignment logic - in production, use more sophisticated routing
        // This would integrate with TaskRouter for intelligent assignment
        return "DP_" + System.currentTimeMillis();
    }

    // ===== MANUAL STATUS UPDATES =====

    public void updateOrderStatus(Order order, String newStatus) {
        order.orderStatus = newStatus;
        updateOrderInFirebase(order);

        if (listener != null) {
            listener.onStatusUpdate(order.orderId, newStatus);
        }

        // Send appropriate notifications
        switch (newStatus) {
            case Constants.ORDER_STATUS_CONFIRMED:
                notificationManager.notifyOrderConfirmed(order.orderId);
                break;
            case Constants.ORDER_STATUS_PACKED:
                notificationManager.notifyOrderPacked(order.orderId);
                break;
            case Constants.ORDER_STATUS_OUT_FOR_DELIVERY:
                notificationManager.notifyOutForDelivery(order.orderId, order.assignedDeliveryPartner);
                break;
            case Constants.ORDER_STATUS_DELIVERED:
                notificationManager.notifyDeliveryCompleted(order.orderId);
                break;
        }

        Timber.d("Order status updated: %s -> %s", order.orderId, newStatus);
    }

    public void cancelOrder(Order order, String reason) {
        order.orderStatus = Constants.ORDER_STATUS_CANCELLED;
        updateOrderInFirebase(order);

        if (listener != null) {
            listener.onStatusUpdate(order.orderId, Constants.ORDER_STATUS_CANCELLED);
        }

        Timber.d("Order cancelled: %s - Reason: %s", order.orderId, reason);
    }
}
