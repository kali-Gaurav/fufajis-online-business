package com.fufaji.store.activities;

import android.os.Bundle;
import android.widget.ImageButton;
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

public class OrderManagementActivity extends AppCompatActivity {
    private RecyclerView ordersRecyclerView;
    private FirebaseService firebaseService;
    private String currentFilter = "all";

    private Chip filterAll;
    private Chip filterPending;
    private Chip filterConfirmed;
    private Chip filterDelivered;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_order_management);

        // Initialize views
        ordersRecyclerView = findViewById(R.id.ordersRecyclerView);
        ImageButton backButton = findViewById(R.id.backButton);

        filterAll = findViewById(R.id.filterAll);
        filterPending = findViewById(R.id.filterPending);
        filterConfirmed = findViewById(R.id.filterConfirmed);
        filterDelivered = findViewById(R.id.filterDelivered);

        firebaseService = FirebaseService.getInstance(this);

        ordersRecyclerView.setLayoutManager(new LinearLayoutManager(this));

        // Back button
        backButton.setOnClickListener(v -> finish());

        // Filter chips
        filterAll.setOnClickListener(v -> {
            currentFilter = "all";
            loadAllOrders();
            updateFilterSelection();
        });

        filterPending.setOnClickListener(v -> {
            currentFilter = "pending";
            loadAllOrders();
            updateFilterSelection();
        });

        filterConfirmed.setOnClickListener(v -> {
            currentFilter = "confirmed";
            loadAllOrders();
            updateFilterSelection();
        });

        filterDelivered.setOnClickListener(v -> {
            currentFilter = "delivered";
            loadAllOrders();
            updateFilterSelection();
        });

        // Load orders
        loadAllOrders();
    }

    private void loadAllOrders() {
        // Since we don't have a method to get all orders (only by user),
        // we would need to modify FirebaseService to add getAllOrders()
        // For now, show a message
        Toast.makeText(this, "Loading all orders...", Toast.LENGTH_SHORT).show();
        Timber.d("Loading orders with filter: %s", currentFilter);

        // TODO: Implement getAllOrders in FirebaseService
        // Then call: firebaseService.getAllOrders(...)
    }

    private List<Order> filterOrders(List<Order> orders) {
        List<Order> filtered = new ArrayList<>();
        for (Order order : orders) {
            if (currentFilter.equals("all")) {
                filtered.add(order);
            } else if (order.orderStatus.equals(currentFilter)) {
                filtered.add(order);
            }
        }
        return filtered;
    }

    private void updateFilterSelection() {
        filterAll.setChecked(currentFilter.equals("all"));
        filterPending.setChecked(currentFilter.equals("pending"));
        filterConfirmed.setChecked(currentFilter.equals("confirmed"));
        filterDelivered.setChecked(currentFilter.equals("delivered"));
    }
}
