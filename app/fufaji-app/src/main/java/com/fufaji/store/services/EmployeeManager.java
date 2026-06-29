package com.fufaji.store.services;

import com.google.firebase.firestore.FirebaseFirestore;
import java.util.HashMap;
import java.util.Map;
import timber.log.Timber;

public class EmployeeManager {
    private static EmployeeManager instance;
    private final FirebaseFirestore db;

    private EmployeeManager() {
        this.db = FirebaseFirestore.getInstance();
    }

    public static synchronized EmployeeManager getInstance() {
        if (instance == null) {
            instance = new EmployeeManager();
        }
        return instance;
    }

    public void logEmployeeTask(String employeeId, String taskType, String orderId, String details) {
        Map<String, Object> data = new HashMap<>();
        data.put("employeeId", employeeId);
        data.put("taskType", taskType);
        data.put("orderId", orderId);
        data.put("details", details);
        data.put("timestamp", System.currentTimeMillis());

        db.collection("employee_tasks").add(data)
                .addOnFailureListener(e -> Timber.e(e, "Error logging employee task"));
    }

    public void updateEmployeePerformance(String employeeId, long taskTime, int qualityScore) {
        Map<String, Object> data = new HashMap<>();
        data.put("employeeId", employeeId);
        data.put("taskTime", taskTime);
        data.put("qualityScore", qualityScore);
        data.put("timestamp", System.currentTimeMillis());

        db.collection("employee_performance").add(data)
                .addOnFailureListener(e -> Timber.e(e, "Error updating employee performance"));
    }

    public void markAttendance(String employeeId, String status) {
        Map<String, Object> data = new HashMap<>();
        data.put("employeeId", employeeId);
        data.put("date", System.currentTimeMillis());
        data.put("status", status);

        db.collection("attendance").add(data)
                .addOnFailureListener(e -> Timber.e(e, "Error marking attendance"));
    }

    public void requestLeave(String employeeId, String leaveType, long startDate, long endDate, String reason) {
        Map<String, Object> data = new HashMap<>();
        data.put("employeeId", employeeId);
        data.put("leaveType", leaveType);
        data.put("startDate", startDate);
        data.put("endDate", endDate);
        data.put("reason", reason);
        data.put("status", "pending");

        db.collection("leave_requests").add(data)
                .addOnFailureListener(e -> Timber.e(e, "Error requesting leave"));
    }
}
