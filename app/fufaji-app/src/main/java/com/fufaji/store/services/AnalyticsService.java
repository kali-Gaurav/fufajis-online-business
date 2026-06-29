package com.fufaji.store.services;

import com.google.firebase.firestore.FieldValue;
import com.google.firebase.firestore.FirebaseFirestore;
import java.util.HashMap;
import java.util.Map;
import timber.log.Timber;

public class AnalyticsService {
    private static AnalyticsService instance;
    private final FirebaseFirestore db;

    private AnalyticsService() {
        this.db = FirebaseFirestore.getInstance();
    }

    public static synchronized AnalyticsService getInstance() {
        if (instance == null) {
            instance = new AnalyticsService();
        }
        return instance;
    }

    // ===== ORDER ANALYTICS =====

    public void trackOrderEvent(String orderId, double amount, String status) {
        Map<String, Object> data = new HashMap<>();
        data.put("timestamp", System.currentTimeMillis());
        data.put("orderId", orderId);
        data.put("amount", amount);
        data.put("status", status);

        db.collection("analytics").document("daily_orders").set(
                data,
                com.google.firebase.firestore.SetOptions.merge()
        ).addOnSuccessListener(aVoid ->
                Timber.d("Order event tracked: %s", orderId)
        ).addOnFailureListener(e ->
                Timber.e(e, "Error tracking order event")
        );

        updateDailyOrderMetrics(amount);
    }

    private void updateDailyOrderMetrics(double amount) {
        String dateKey = getCurrentDateKey();
        db.collection("analytics").document("daily_metrics").update(
                "date", dateKey,
                "totalOrders", FieldValue.increment(1),
                "totalRevenue", FieldValue.increment(amount),
                "lastUpdate", System.currentTimeMillis()
        ).addOnFailureListener(e -> {
            Map<String, Object> data = new HashMap<>();
            data.put("date", dateKey);
            data.put("totalOrders", 1L);
            data.put("totalRevenue", amount);
            data.put("lastUpdate", System.currentTimeMillis());
            db.collection("analytics").document("daily_metrics").set(data);
        });
    }

    public void trackProductView(String productId) {
        db.collection("products").document(productId).update(
                "views", FieldValue.increment(1)
        ).addOnFailureListener(e -> Timber.e(e, "Error tracking product view"));
    }

    public void trackProductPurchase(String productId, int quantity) {
        db.collection("products").document(productId).update(
                "purchases", FieldValue.increment(1),
                "unitsSold", FieldValue.increment(quantity)
        ).addOnFailureListener(e -> Timber.e(e, "Error tracking product purchase"));
    }

    public void getProductAnalytics(String productId, AnalyticsCallback callback) {
        db.collection("products").document(productId).get()
                .addOnSuccessListener(documentSnapshot -> {
                    if (documentSnapshot.exists()) {
                        Long views = documentSnapshot.getLong("views");
                        Long purchases = documentSnapshot.getLong("purchases");
                        Long unitsSold = documentSnapshot.getLong("unitsSold");

                        callback.onAnalyticsReceived(
                                views != null ? views : 0,
                                purchases != null ? purchases : 0,
                                unitsSold != null ? unitsSold : 0
                        );
                    }
                })
                .addOnFailureListener(e -> {
                    Timber.e(e, "Error getting product analytics");
                    callback.onError(e.getMessage());
                });
    }

    public void trackCustomerActivity(String userId, String activityType, String details) {
        Map<String, Object> data = new HashMap<>();
        data.put("userId", userId);
        data.put("activityType", activityType);
        data.put("details", details);
        data.put("timestamp", System.currentTimeMillis());

        db.collection("customer_analytics").add(data)
                .addOnFailureListener(e -> Timber.e(e, "Error tracking customer activity"));
    }

    public void trackSearchQuery(String userId, String query) {
        trackCustomerActivity(userId, "search", query);
        updateSearchTrends(query);
    }

    private void updateSearchTrends(String query) {
        db.collection("analytics").document("search_trends").update(
                "searches." + query, FieldValue.increment(1)
        ).addOnFailureListener(e -> {
            Map<String, Object> data = new HashMap<>();
            data.put("searches", new HashMap<String, Long>());
            db.collection("analytics").document("search_trends").set(data);
        });
    }

    public void getCustomerMetrics(String userId, CustomerMetricsCallback callback) {
        db.collection("users").document(userId).get()
                .addOnSuccessListener(documentSnapshot -> {
                    if (documentSnapshot.exists()) {
                        Long totalOrders = documentSnapshot.getLong("totalOrders");
                        Double totalSpent = documentSnapshot.getDouble("totalSpent");
                        String preferredLanguage = documentSnapshot.getString("preferredLanguage");

                        callback.onMetricsReceived(
                                totalOrders != null ? totalOrders : 0,
                                totalSpent != null ? totalSpent : 0.0,
                                preferredLanguage
                        );
                    }
                })
                .addOnFailureListener(e -> {
                    Timber.e(e, "Error getting customer metrics");
                    callback.onError(e.getMessage());
                });
    }

    public void trackDeliveryMetrics(String deliveryPartnerId, long deliveryTime, double distance) {
        Map<String, Object> data = new HashMap<>();
        data.put("partnerId", deliveryPartnerId);
        data.put("deliveryTime", deliveryTime);
        data.put("distance", distance);
        data.put("timestamp", System.currentTimeMillis());

        db.collection("delivery_analytics").add(data)
                .addOnSuccessListener(aVoid ->
                        updateDeliveryPartnerStats(deliveryPartnerId, deliveryTime)
                ).addOnFailureListener(e ->
                        Timber.e(e, "Error tracking delivery metrics")
                );
    }

    private void updateDeliveryPartnerStats(String partnerId, long deliveryTime) {
        db.collection("delivery_partners").document(partnerId).update(
                "totalDeliveryTime", FieldValue.increment(deliveryTime),
                "averageDeliveryTime", calculateAverageTime(deliveryTime)
        ).addOnFailureListener(e -> Timber.e(e, "Error updating delivery stats"));
    }

    private long calculateAverageTime(long newTime) {
        return (long) (newTime / 2.0);
    }

    public void getDailySummary(ReportCallback callback) {
        db.collection("analytics").document("daily_metrics").get()
                .addOnSuccessListener(documentSnapshot -> {
                    if (documentSnapshot.exists()) {
                        Long totalOrders = documentSnapshot.getLong("totalOrders");
                        Double totalRevenue = documentSnapshot.getDouble("totalRevenue");

                        callback.onReportReceived(
                                totalOrders != null ? totalOrders : 0,
                                totalRevenue != null ? totalRevenue : 0.0
                        );
                    }
                })
                .addOnFailureListener(e -> {
                    Timber.e(e, "Error getting daily summary");
                    callback.onError(e.getMessage());
                });
    }

    public void getPeakHours(PeakHoursCallback callback) {
        db.collection("analytics").document("hourly_orders")
                .addSnapshotListener((value, error) -> {
                    if (error != null) {
                        Timber.e(error, "Error getting peak hours");
                        callback.onError(error.getMessage());
                        return;
                    }

                    if (value != null && value.exists()) {
                        callback.onPeakHoursReceived(value.getData());
                    }
                });
    }

    private String getCurrentDateKey() {
        java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault());
        return sdf.format(new java.util.Date());
    }

    public interface AnalyticsCallback {
        void onAnalyticsReceived(long views, long purchases, long unitsSold);
        void onError(String error);
    }

    public interface CustomerMetricsCallback {
        void onMetricsReceived(long totalOrders, double totalSpent, String preferredLanguage);
        void onError(String error);
    }

    public interface ReportCallback {
        void onReportReceived(long totalOrders, double totalRevenue);
        void onError(String error);
    }

    public interface PeakHoursCallback {
        void onPeakHoursReceived(java.util.Map<String, Object> hourlyData);
        void onError(String error);
    }
}
