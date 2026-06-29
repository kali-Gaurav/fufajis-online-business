package com.fufaji.store.activities;

import android.os.Bundle;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.fufaji.store.R;
import com.fufaji.store.services.FirebaseService;

import timber.log.Timber;

public class OwnerDashboardActivity extends AppCompatActivity {
    private FirebaseService firebaseService;

    private TextView totalOrdersText;
    private TextView totalRevenueText;
    private TextView pendingOrdersText;
    private TextView lowStockText;

    private Button inventoryButton;
    private Button ordersButton;
    private Button analyticsButton;
    private Button settingsButton;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_owner_dashboard);

        firebaseService = FirebaseService.getInstance(this);

        // Initialize views
        totalOrdersText = findViewById(R.id.totalOrdersText);
        totalRevenueText = findViewById(R.id.totalRevenueText);
        pendingOrdersText = findViewById(R.id.pendingOrdersText);
        lowStockText = findViewById(R.id.lowStockText);

        inventoryButton = findViewById(R.id.inventoryButton);
        ordersButton = findViewById(R.id.ordersButton);
        analyticsButton = findViewById(R.id.analyticsButton);
        settingsButton = findViewById(R.id.settingsButton);

        // Set up button listeners
        inventoryButton.setOnClickListener(v -> {
            Toast.makeText(this, "Opening Inventory", Toast.LENGTH_SHORT).show();
            // Intent intent = new Intent(this, InventoryActivity.class);
            // startActivity(intent);
        });

        ordersButton.setOnClickListener(v -> {
            Toast.makeText(this, "Opening Orders Management", Toast.LENGTH_SHORT).show();
            // Intent intent = new Intent(this, OrderManagementActivity.class);
            // startActivity(intent);
        });

        analyticsButton.setOnClickListener(v -> {
            Toast.makeText(this, "Opening Analytics", Toast.LENGTH_SHORT).show();
        });

        settingsButton.setOnClickListener(v -> {
            Toast.makeText(this, "Opening Settings", Toast.LENGTH_SHORT).show();
        });

        // Load dashboard data
        loadDashboardData();
    }

    private void loadDashboardData() {
        try {
            String userId = firebaseService.getCurrentUserId();
            if (userId == null) {
                Toast.makeText(this, "User not logged in", Toast.LENGTH_SHORT).show();
                return;
            }

            // Load orders and calculate stats
            firebaseService.getOrders(userId,
                    orders -> {
                        int totalOrders = orders.size();
                        int pendingOrders = (int) orders.stream()
                                .filter(o -> o.orderStatus.equals("pending"))
                                .count();

                        totalOrdersText.setText(String.valueOf(totalOrders));
                        pendingOrdersText.setText(String.valueOf(pendingOrders));

                        // Calculate total revenue
                        double totalRevenue = orders.stream()
                                .mapToDouble(o -> o.total)
                                .sum();
                        totalRevenueText.setText("₹" + (long) totalRevenue);
                    },
                    error -> {
                        Toast.makeText(this, "Error loading data: " + error, Toast.LENGTH_SHORT).show();
                        Timber.e("Error loading orders: %s", error);
                    });

            // Load low stock products
            firebaseService.getAllProducts(
                    products -> {
                        long lowStockCount = products.stream()
                                .filter(p -> p.stock < 5 && p.stock > 0)
                                .count();
                        lowStockText.setText(String.valueOf(lowStockCount));
                    },
                    error -> Timber.e("Error loading products: %s", error));

        } catch (Exception e) {
            Timber.e(e, "Error loading dashboard data");
        }
    }
}
