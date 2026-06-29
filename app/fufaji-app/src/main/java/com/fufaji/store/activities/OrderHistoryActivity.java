package com.fufaji.store.activities;

import android.os.Bundle;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.fufaji.store.R;
import com.fufaji.store.models.Order;
import com.fufaji.store.services.FirebaseService;
import com.google.android.material.chip.Chip;

import java.util.ArrayList;
import java.util.List;

import timber.log.Timber;

public class OrderHistoryActivity extends AppCompatActivity {
    private RecyclerView ordersRecyclerView;
    private LinearLayout emptyState;
    private FirebaseService firebaseService;
    private String currentUserId;
    private String currentFilter = "all";

    private Chip filterAll;
    private Chip filterPending;
    private Chip filterDelivered;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_order_history);

        // Initialize views
        ordersRecyclerView = findViewById(R.id.ordersRecyclerView);
        emptyState = findViewById(R.id.emptyState);
        ImageButton backButton = findViewById(R.id.backButton);

        filterAll = findViewById(R.id.filterAll);
        filterPending = findViewById(R.id.filterPending);
        filterDelivered = findViewById(R.id.filterDelivered);

        firebaseService = FirebaseService.getInstance(this);
        currentUserId = firebaseService.getCurrentUserId();

        ordersRecyclerView.setLayoutManager(new LinearLayoutManager(this));

        // Back button
        backButton.setOnClickListener(v -> finish());

        // Filter chips
        filterAll.setOnClickListener(v -> {
            currentFilter = "all";
            loadOrders();
            updateFilterSelection();
        });

        filterPending.setOnClickListener(v -> {
            currentFilter = "pending";
            loadOrders();
            updateFilterSelection();
        });

        filterDelivered.setOnClickListener(v -> {
            currentFilter = "delivered";
            loadOrders();
            updateFilterSelection();
        });

        // Load orders
        loadOrders();
    }

    private void loadOrders() {
        if (currentUserId == null) {
            Toast.makeText(this, "User not logged in", Toast.LENGTH_SHORT).show();
            return;
        }

        firebaseService.getOrders(currentUserId,
                orders -> {
                    List<Order> filteredOrders = filterOrders(orders);
                    if (filteredOrders.isEmpty()) {
                        emptyState.setVisibility(android.view.View.VISIBLE);
                        ordersRecyclerView.setVisibility(android.view.View.GONE);
                    } else {
                        emptyState.setVisibility(android.view.View.GONE);
                        ordersRecyclerView.setVisibility(android.view.View.VISIBLE);
                        // Set adapter with filtered orders
                        // OrderAdapter adapter = new OrderAdapter(filteredOrders);
                        // ordersRecyclerView.setAdapter(adapter);
                    }
                },
                error -> {
                    Toast.makeText(this, "Error loading orders: " + error, Toast.LENGTH_SHORT).show();
                    Timber.e("Error loading orders: %s", error);
                });
    }

    private List<Order> filterOrders(List<Order> orders) {
        List<Order> filtered = new ArrayList<>();
        for (Order order : orders) {
            if (currentFilter.equals("all")) {
                filtered.add(order);
            } else if (currentFilter.equals("pending") && order.orderStatus.equals("pending")) {
                filtered.add(order);
            } else if (currentFilter.equals("delivered") && order.orderStatus.equals("delivered")) {
                filtered.add(order);
            }
        }
        return filtered;
    }

    private void updateFilterSelection() {
        filterAll.setChecked(currentFilter.equals("all"));
        filterPending.setChecked(currentFilter.equals("pending"));
        filterDelivered.setChecked(currentFilter.equals("delivered"));
    }
}
