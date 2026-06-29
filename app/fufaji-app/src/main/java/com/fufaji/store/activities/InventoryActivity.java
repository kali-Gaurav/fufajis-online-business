package com.fufaji.store.activities;

import android.os.Bundle;
import android.widget.ImageButton;
import android.widget.SearchView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.fufaji.store.R;
import com.fufaji.store.models.Product;
import com.fufaji.store.services.FirebaseService;

import java.util.ArrayList;
import java.util.List;

import timber.log.Timber;

public class InventoryActivity extends AppCompatActivity {
    private RecyclerView inventoryRecyclerView;
    private SearchView searchView;
    private FirebaseService firebaseService;
    private List<Product> allProducts = new ArrayList<>();
    private List<Product> filteredProducts = new ArrayList<>();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_inventory);

        // Initialize views
        inventoryRecyclerView = findViewById(R.id.inventoryRecyclerView);
        searchView = findViewById(R.id.searchView);
        ImageButton backButton = findViewById(R.id.backButton);

        firebaseService = FirebaseService.getInstance(this);

        inventoryRecyclerView.setLayoutManager(new LinearLayoutManager(this));

        // Back button
        backButton.setOnClickListener(v -> finish());

        // Search functionality
        searchView.setOnQueryTextListener(new SearchView.OnQueryTextListener() {
            @Override
            public boolean onQueryTextSubmit(String query) {
                filterProducts(query);
                return true;
            }

            @Override
            public boolean onQueryTextChange(String newText) {
                filterProducts(newText);
                return true;
            }
        });

        // Load products
        loadProducts();
    }

    private void loadProducts() {
        firebaseService.getAllProducts(
                products -> {
                    allProducts = products;
                    filteredProducts = new ArrayList<>(products);
                    // Set adapter
                    // InventoryAdapter adapter = new InventoryAdapter(filteredProducts);
                    // inventoryRecyclerView.setAdapter(adapter);
                },
                error -> {
                    Toast.makeText(this, "Error loading inventory: " + error, Toast.LENGTH_SHORT).show();
                    Timber.e("Error loading products: %s", error);
                });
    }

    private void filterProducts(String query) {
        filteredProducts.clear();
        if (query.isEmpty()) {
            filteredProducts.addAll(allProducts);
        } else {
            String lowerQuery = query.toLowerCase();
            for (Product product : allProducts) {
                if (product.name.toLowerCase().contains(lowerQuery) ||
                    product.nameEn.toLowerCase().contains(lowerQuery) ||
                    product.category.toLowerCase().contains(lowerQuery)) {
                    filteredProducts.add(product);
                }
            }
        }
        // Notify adapter of changes
    }
}
