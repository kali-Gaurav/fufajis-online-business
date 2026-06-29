package com.fufaji.store.models;

import java.util.List;
import java.util.Map;

public class Order {
    public String orderId;
    public String customerId;
    public String customerName;
    public String customerPhone;
    public String customerEmail;
    public String deliveryAddress;
    public List<CartItem> items;
    public double subtotal;
    public double totalGST;
    public double total;
    public String paymentMethod;
    public String paymentStatus;
    public String paymentId;
    public String orderStatus;
    public String assignedEmployee;
    public String assignedDeliveryPartner;
    public long createdAt;
    public long deliveredAt;
    public String notes;
    public Map<String, Object> receipt;
    public int estimatedDeliveryMinutes;

    public Order() {}

    public Order(String customerId, String customerName, String customerPhone,
                 String deliveryAddress, List<CartItem> items) {
        this.customerId = customerId;
        this.customerName = customerName;
        this.customerPhone = customerPhone;
        this.deliveryAddress = deliveryAddress;
        this.items = items;
        this.orderStatus = "pending";
        this.paymentStatus = "pending";
        this.createdAt = System.currentTimeMillis();
        this.estimatedDeliveryMinutes = 30;
        calculateTotals();
    }

    private void calculateTotals() {
        this.subtotal = 0;
        this.totalGST = 0;
        for (CartItem item : items) {
            this.subtotal += item.getItemPrice();
            this.totalGST += item.getItemGST();
        }
        this.total = this.subtotal + this.totalGST;
    }

    public String getStatusDisplay() {
        switch (orderStatus) {
            case "pending":
                return "⏳ Pending";
            case "confirmed":
                return "✅ Confirmed";
            case "packed":
                return "📦 Packed";
            case "out_for_delivery":
                return "🚚 Out for Delivery";
            case "delivered":
                return "✅ Delivered";
            case "cancelled":
                return "❌ Cancelled";
            default:
                return "⏳ Unknown";
        }
    }

    public boolean canBeCancelled() {
        return orderStatus.equals("pending") || orderStatus.equals("confirmed");
    }
}
