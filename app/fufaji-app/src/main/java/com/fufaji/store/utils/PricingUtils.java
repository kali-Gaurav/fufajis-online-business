package com.fufaji.store.utils;

import java.text.NumberFormat;
import java.util.Currency;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import com.fufaji.store.models.CartItem;

public class PricingUtils {
    private static final double GST_RATE = 0.18; // 18% GST for all items
    private static final NumberFormat CURRENCY_FORMAT = NumberFormat.getCurrencyInstance();

    static {
        CURRENCY_FORMAT.setCurrency(Currency.getInstance("INR"));
    }

    /**
     * Calculate GST amount for a given price
     */
    public static double calculateGST(double price) {
        return price * GST_RATE;
    }

    /**
     * Get total price including GST
     */
    public static double getTotal(double subtotal) {
        return subtotal + calculateGST(subtotal);
    }

    /**
     * Format amount as Indian currency (₹)
     */
    public static String formatINR(double amount) {
        return "₹" + String.format("%.2f", amount);
    }

    /**
     * Get price breakdown for display
     */
    public static Map<String, Double> getBreakdown(double subtotal) {
        Map<String, Double> breakdown = new HashMap<>();
        breakdown.put("subtotal", subtotal);
        breakdown.put("gst", calculateGST(subtotal));
        breakdown.put("total", getTotal(subtotal));
        return breakdown;
    }

    /**
     * Calculate cart total from list of items
     */
    public static double calculateCartTotal(List<CartItem> items) {
        double subtotal = 0;
        for (CartItem item : items) {
            subtotal += item.getItemPrice();
        }
        return getTotal(subtotal);
    }

    /**
     * Calculate cart subtotal (without GST)
     */
    public static double calculateCartSubtotal(List<CartItem> items) {
        double subtotal = 0;
        for (CartItem item : items) {
            subtotal += item.getItemPrice();
        }
        return subtotal;
    }

    /**
     * Calculate total GST for cart
     */
    public static double calculateCartGST(List<CartItem> items) {
        double subtotal = calculateCartSubtotal(items);
        return calculateGST(subtotal);
    }

    /**
     * Apply discount percentage
     */
    public static double applyDiscount(double price, int discountPercent) {
        return price - (price * discountPercent / 100.0);
    }

    /**
     * Get formatted price breakdown string
     */
    public static String getPriceBreakdownString(double subtotal) {
        double gst = calculateGST(subtotal);
        double total = subtotal + gst;
        return String.format("Subtotal: %s | GST: %s | Total: %s",
                formatINR(subtotal), formatINR(gst), formatINR(total));
    }

    /**
     * Round to 2 decimal places
     */
    public static double roundTo2Decimals(double value) {
        return Math.round(value * 100.0) / 100.0;
    }
}
