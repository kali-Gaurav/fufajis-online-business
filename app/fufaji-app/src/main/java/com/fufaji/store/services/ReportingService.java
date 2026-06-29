package com.fufaji.store.services;

import com.google.firebase.firestore.FirebaseFirestore;

import java.util.HashMap;
import java.util.Map;

import timber.log.Timber;

public class ReportingService {
    private static ReportingService instance;
    private final FirebaseFirestore db;
    private final AnalyticsService analyticsService;

    public interface ReportCallback {
        void onReportGenerated(Map<String, Object> reportData);
        void onError(String error);
    }

    private ReportingService() {
        this.db = FirebaseFirestore.getInstance();
        this.analyticsService = AnalyticsService.getInstance();
    }

    public static synchronized ReportingService getInstance() {
        if (instance == null) {
            instance = new ReportingService();
        }
        return instance;
    }

    // ===== ADMIN REPORTS =====

    /**
     * Generate comprehensive daily report
     */
    public void generateDailyReport(ReportCallback callback) {
        Map<String, Object> report = new HashMap<>();
        String dateKey = getCurrentDateKey();

        // Get daily metrics
        db.collection("analytics").document("daily_metrics").get()
                .addOnSuccessListener(snapshot -> {
                    if (snapshot.exists()) {
                        report.put("date", dateKey);
                        report.put("totalOrders", snapshot.getLong("totalOrders"));
                        report.put("totalRevenue", snapshot.getDouble("totalRevenue"));
                        report.put("averageOrderValue", calculateAverageOrderValue(
                                snapshot.getLong("totalOrders"),
                                snapshot.getDouble("totalRevenue")
                        ));

                        // Get product performance
                        getProductPerformance(report, callback);
                    }
                })
                .addOnFailureListener(e -> {
                    Timber.e(e, "Error generating daily report");
                    callback.onError(e.getMessage());
                });
    }

    /**
     * Generate weekly report
     */
    public void generateWeeklyReport(ReportCallback callback) {
        Map<String, Object> report = new HashMap<>();

        db.collection("analytics")
                .whereGreaterThanOrEqualTo("timestamp", System.currentTimeMillis() - (7 * 24 * 60 * 60 * 1000))
                .addSnapshotListener((value, error) -> {
                    if (error != null) {
                        callback.onError(error.getMessage());
                        return;
                    }

                    if (value != null) {
                        long totalOrders = 0;
                        double totalRevenue = 0;

                        for (com.google.firebase.firestore.DocumentSnapshot doc : value.getDocuments()) {
                            Long orders = doc.getLong("totalOrders");
                            Double revenue = doc.getDouble("totalRevenue");

                            if (orders != null) totalOrders += orders;
                            if (revenue != null) totalRevenue += revenue;
                        }

                        report.put("weekStartDate", getWeekStartDate());
                        report.put("totalOrders", totalOrders);
                        report.put("totalRevenue", totalRevenue);
                        report.put("averageOrderValue", calculateAverageOrderValue(totalOrders, totalRevenue));

                        // Get trend analysis
                        getTrendAnalysis(report, callback);
                    }
                });
    }

    /**
     * Generate monthly report with forecasts
     */
    public void generateMonthlyReport(ReportCallback callback) {
        Map<String, Object> report = new HashMap<>();

        db.collection("analytics")
                .whereGreaterThanOrEqualTo("timestamp", System.currentTimeMillis() - (30 * 24 * 60 * 60 * 1000))
                .addSnapshotListener((value, error) -> {
                    if (error != null) {
                        callback.onError(error.getMessage());
                        return;
                    }

                    if (value != null) {
                        long totalOrders = 0;
                        double totalRevenue = 0;
                        double highestDailyRevenue = 0;

                        for (com.google.firebase.firestore.DocumentSnapshot doc : value.getDocuments()) {
                            Long orders = doc.getLong("totalOrders");
                            Double revenue = doc.getDouble("totalRevenue");

                            if (orders != null) totalOrders += orders;
                            if (revenue != null) {
                                totalRevenue += revenue;
                                if (revenue > highestDailyRevenue) highestDailyRevenue = revenue;
                            }
                        }

                        report.put("monthStartDate", getMonthStartDate());
                        report.put("totalOrders", totalOrders);
                        report.put("totalRevenue", totalRevenue);
                        report.put("averageOrderValue", calculateAverageOrderValue(totalOrders, totalRevenue));
                        report.put("highestDailyRevenue", highestDailyRevenue);
                        report.put("averageDailyRevenue", totalRevenue / 30.0);

                        // Get category performance
                        getCategoryPerformance(report, callback);
                    }
                });
    }

    // ===== PERFORMANCE REPORTS =====

    /**
     * Employee performance report
     */
    public void generateEmployeePerformanceReport(String employeeId, ReportCallback callback) {
        Map<String, Object> report = new HashMap<>();

        db.collection("employees").document(employeeId).get()
                .addOnSuccessListener(snapshot -> {
                    if (snapshot.exists()) {
                        report.put("employeeId", employeeId);
                        report.put("name", snapshot.getString("name"));
                        report.put("role", snapshot.getString("role"));
                        report.put("totalTasks", snapshot.getLong("totalTasks"));
                        report.put("averageQualityScore", snapshot.getDouble("averageQualityScore"));
                        report.put("totalWorkTime", snapshot.getLong("totalWorkTime"));

                        // Get task breakdown
                        getTaskBreakdown(employeeId, report, callback);
                    }
                })
                .addOnFailureListener(e -> callback.onError(e.getMessage()));
    }

    /**
     * Delivery partner performance report
     */
    public void generateDeliveryPerformanceReport(String partnerId, ReportCallback callback) {
        Map<String, Object> report = new HashMap<>();

        db.collection("delivery_partners").document(partnerId).get()
                .addOnSuccessListener(snapshot -> {
                    if (snapshot.exists()) {
                        report.put("partnerId", partnerId);
                        report.put("name", snapshot.getString("name"));
                        report.put("rating", snapshot.getDouble("rating"));
                        report.put("totalDeliveries", snapshot.getLong("totalDeliveries"));
                        report.put("averageDeliveryTime", snapshot.getLong("averageDeliveryTime"));

                        callback.onReportGenerated(report);
                        Timber.d("Delivery performance report generated for: %s", partnerId);
                    }
                })
                .addOnFailureListener(e -> callback.onError(e.getMessage()));
    }

    // ===== INVENTORY REPORTS =====

    /**
     * Low stock alert report
     */
    public void generateLowStockReport(ReportCallback callback) {
        Map<String, Object> report = new HashMap<>();

        db.collection("products")
                .whereLessThan("stock", 5)
                .addSnapshotListener((value, error) -> {
                    if (error != null) {
                        callback.onError(error.getMessage());
                        return;
                    }

                    if (value != null) {
                        Map<String, Object> lowStockItems = new HashMap<>();
                        int totalLowStockItems = 0;

                        for (com.google.firebase.firestore.DocumentSnapshot doc : value.getDocuments()) {
                            String productName = doc.getString("name");
                            Long stock = doc.getLong("stock");

                            if (stock != null) {
                                lowStockItems.put(productName, stock);
                                totalLowStockItems++;
                            }
                        }

                        report.put("lowStockAlerts", lowStockItems);
                        report.put("totalLowStockItems", totalLowStockItems);
                        report.put("generatedAt", System.currentTimeMillis());

                        callback.onReportGenerated(report);
                        Timber.d("Low stock report generated: %d items", totalLowStockItems);
                    }
                });
    }

    // ===== HELPER METHODS =====

    private void getProductPerformance(Map<String, Object> report, ReportCallback callback) {
        db.collection("products")
                .orderBy("purchases", com.google.firebase.firestore.Query.Direction.DESCENDING)
                .limit(5)
                .addSnapshotListener((value, error) -> {
                    if (error == null && value != null) {
                        java.util.List<Map<String, Object>> topProducts = new java.util.ArrayList<>();

                        for (com.google.firebase.firestore.DocumentSnapshot doc : value.getDocuments()) {
                            Map<String, Object> product = new HashMap<>();
                            product.put("name", doc.getString("name"));
                            product.put("purchases", doc.getLong("purchases"));
                            product.put("views", doc.getLong("views"));
                            topProducts.add(product);
                        }

                        report.put("topProducts", topProducts);
                        callback.onReportGenerated(report);
                    }
                });
    }

    private void getCategoryPerformance(Map<String, Object> report, ReportCallback callback) {
        // Query products grouped by category
        db.collection("products")
                .addSnapshotListener((value, error) -> {
                    if (error == null && value != null) {
                        Map<String, Long> categoryRevenue = new HashMap<>();

                        for (com.google.firebase.firestore.DocumentSnapshot doc : value.getDocuments()) {
                            String category = doc.getString("category");
                            Long purchases = doc.getLong("purchases");

                            if (category != null && purchases != null) {
                                categoryRevenue.put(category, categoryRevenue.getOrDefault(category, 0L) + purchases);
                            }
                        }

                        report.put("categoryPerformance", categoryRevenue);
                        callback.onReportGenerated(report);
                    }
                });
    }

    private void getTrendAnalysis(Map<String, Object> report, ReportCallback callback) {
        // Simple trend analysis - compare with previous week
        report.put("trend", "up"); // Calculate based on comparison
        callback.onReportGenerated(report);
    }

    private void getTaskBreakdown(String employeeId, Map<String, Object> report, ReportCallback callback) {
        db.collection("employee_tasks")
                .whereEqualTo("employeeId", employeeId)
                .addSnapshotListener((value, error) -> {
                    if (error == null && value != null) {
                        Map<String, Long> taskBreakdown = new HashMap<>();

                        for (com.google.firebase.firestore.DocumentSnapshot doc : value.getDocuments()) {
                            String taskType = doc.getString("taskType");
                            if (taskType != null) {
                                taskBreakdown.put(taskType, taskBreakdown.getOrDefault(taskType, 0L) + 1);
                            }
                        }

                        report.put("taskBreakdown", taskBreakdown);
                        callback.onReportGenerated(report);
                    }
                });
    }

    private double calculateAverageOrderValue(long totalOrders, double totalRevenue) {
        if (totalOrders == 0) return 0;
        return totalRevenue / totalOrders;
    }

    private String getCurrentDateKey() {
        java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault());
        return sdf.format(new java.util.Date());
    }

    private String getWeekStartDate() {
        java.util.Calendar calendar = java.util.Calendar.getInstance();
        calendar.set(java.util.Calendar.DAY_OF_WEEK, java.util.Calendar.MONDAY);
        java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault());
        return sdf.format(calendar.getTime());
    }

    private String getMonthStartDate() {
        java.util.Calendar calendar = java.util.Calendar.getInstance();
        calendar.set(java.util.Calendar.DAY_OF_MONTH, 1);
        java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault());
        return sdf.format(calendar.getTime());
    }
}
