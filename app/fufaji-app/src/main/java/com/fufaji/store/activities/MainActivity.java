package com.fufaji.store.activities;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.View;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.fufaji.store.R;
import com.fufaji.store.adapters.ProductAdapter;
import com.fufaji.store.adapters.CategoryAdapter;
import com.fufaji.store.managers.UpdateManager;
import com.fufaji.store.models.Product;
import com.fufaji.store.models.Category;
import com.fufaji.store.services.FirebaseService;
import com.fufaji.store.utils.Constants;
import timber.log.Timber;

import java.util.ArrayList;
import java.util.List;

public class MainActivity extends AppCompatActivity {
    private RecyclerView categoryRecyclerView;
    private RecyclerView productRecyclerView;
    private EditText searchInput;
    private ImageView cartIcon;
    private TextView cartBadge;
    private ProgressBar progressBar;
    private FirebaseService firebaseService;
    private SharedPreferences preferences;
    private ProductAdapter productAdapter;
    private CategoryAdapter categoryAdapter;
    private List<Product> allProducts;
    private List<Product> filteredProducts;
    private List<Category> categories;
    private String selectedCategory;
    private static final String PREF_NAME = "fufaji_prefs";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // Initialize views
        categoryRecyclerView = findViewById(R.id.categoryRecyclerView);
        productRecyclerView = findViewById(R.id.productRecyclerView);
        searchInput = findViewById(R.id.searchInput);
        cartIcon = findViewById(R.id.cartIcon);
        cartBadge = findViewById(R.id.cartBadge);
        progressBar = findViewById(R.id.loadingProgress);

        // Initialize services
        firebaseService = FirebaseService.getInstance(this);
        preferences = getSharedPreferences(PREF_NAME, MODE_PRIVATE);

        // Initialize data
        allProducts = new ArrayList<>();
        filteredProducts = new ArrayList<>();
        categories = initializeCategories();

        // Setup category carousel
        setupCategoryCarousel();

        // Setup product grid
        setupProductGrid();

        // Setup search
        setupSearch();

        // Setup cart button
        cartIcon.setOnClickListener(v -> startActivity(new Intent(this, CartActivity.class)));

        // Load products
        loadProducts();

        // Check for updates
        new UpdateManager(this).checkForUpdates();
    }

    private List<Category> initializeCategories() {
        List<Category> cats = new ArrayList<>();
        cats.add(new Category("CAT001", "सब्जियाँ", "Vegetables", Constants.CATEGORY_VEGETABLES, "vegetable"));
        cats.add(new Category("CAT002", "दूध और डेयरी", "Dairy & Milk", Constants.CATEGORY_DAIRY, "milk"));
        cats.add(new Category("CAT003", "गेहूँ और अनाज", "Grains & Flour", Constants.CATEGORY_GRAINS, "grains"));
        cats.add(new Category("CAT004", "मसाले", "Spices", Constants.CATEGORY_SPICES, "spices"));
        cats.add(new Category("CAT005", "तेल और घी", "Oils & Ghee", Constants.CATEGORY_OILS, "oils"));
        cats.add(new Category("CAT006", "फल", "Fruits", Constants.CATEGORY_FRUITS, "fruits"));
        cats.add(new Category("CAT007", "नाश्ता और स्नैक्स", "Snacks", Constants.CATEGORY_SNACKS, "snacks"));
        cats.add(new Category("CAT008", "पेय पदार्थ", "Beverages", Constants.CATEGORY_BEVERAGES, "beverages"));
        cats.add(new Category("CAT009", "घरेलू सामान", "Household", Constants.CATEGORY_HOUSEHOLD, "household"));
        cats.add(new Category("CAT010", "स्वास्थ्य और सौंदर्य", "Health & Beauty", Constants.CATEGORY_HEALTH, "health"));
        return cats;
    }

    private void setupCategoryCarousel() {
        categoryAdapter = new CategoryAdapter(categories, category -> {
            selectedCategory = category.name;
            filterByCategory(category.name);
        });

        categoryRecyclerView.setLayoutManager(
                new LinearLayoutManager(this, LinearLayoutManager.HORIZONTAL, false)
        );
        categoryRecyclerView.setAdapter(categoryAdapter);
    }

    private void setupProductGrid() {
        productAdapter = new ProductAdapter(filteredProducts, product -> {
            Intent intent = new Intent(this, ProductDetailActivity.class);
            intent.putExtra("product_id", product.id);
            startActivity(intent);
        });

        productRecyclerView.setLayoutManager(new GridLayoutManager(this, 2));
        productRecyclerView.setAdapter(productAdapter);
    }

    private void setupSearch() {
        searchInput.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                filterProducts(s.toString());
            }

            @Override
            public void afterTextChanged(Editable s) {}
        });
    }

    private void loadProducts() {
        progressBar.setVisibility(View.VISIBLE);
        firebaseService.getAllProducts(
                products -> {
                    allProducts = products;
                    filteredProducts.clear();
                    filteredProducts.addAll(products);
                    productAdapter.notifyDataSetChanged();
                    progressBar.setVisibility(View.GONE);
                    Toast.makeText(this, "Loaded " + products.size() + " products", Toast.LENGTH_SHORT).show();
                },
                error -> {
                    progressBar.setVisibility(View.GONE);
                    Toast.makeText(this, "Error loading products: " + error, Toast.LENGTH_SHORT).show();
                    Timber.e("Load products error: %s", error);
                }
        );
    }

    private void filterByCategory(String category) {
        filteredProducts.clear();
        for (Product p : allProducts) {
            if (p.category.equals(category)) {
                filteredProducts.add(p);
            }
        }
        productAdapter.notifyDataSetChanged();
    }

    private void filterProducts(String query) {
        filteredProducts.clear();
        for (Product p : allProducts) {
            if (p.name.toLowerCase().contains(query.toLowerCase()) ||
                    p.nameEn.toLowerCase().contains(query.toLowerCase())) {
                filteredProducts.add(p);
            }
        }
        productAdapter.notifyDataSetChanged();
    }

    @Override
    protected void onResume() {
        super.onResume();
        updateCartBadge();
    }

    private void updateCartBadge() {
        // Get cart count from local storage or Firebase
        int cartCount = 0; // TODO: Get from CartManager
        if (cartCount > 0) {
            cartBadge.setVisibility(View.VISIBLE);
            cartBadge.setText(String.valueOf(cartCount));
        } else {
            cartBadge.setVisibility(View.GONE);
        }
    }
}
