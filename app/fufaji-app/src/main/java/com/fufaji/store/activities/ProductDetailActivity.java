package com.fufaji.store.activities;

import android.content.Intent;
import android.os.Bundle;
import android.widget.Button;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.fufaji.store.R;
import com.fufaji.store.managers.CartManager;
import com.fufaji.store.models.Product;
import com.fufaji.store.utils.PricingUtils;
import com.google.gson.Gson;

public class ProductDetailActivity extends AppCompatActivity {
    private Product product;
    private CartManager cartManager;

    private TextView productName;
    private TextView productNameEn;
    private TextView productPrice;
    private TextView productDescription;
    private TextView categoryName;
    private TextView stockInfo;
    private TextView productEmoji;
    private TextView quantityText;
    private Button addToCartButton;
    private ImageButton backButton;
    private ImageButton decreaseButton;
    private ImageButton increaseButton;

    private int quantity = 1;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_product_detail);

        cartManager = CartManager.getInstance(this);

        // Initialize views
        productName = findViewById(R.id.productName);
        productNameEn = findViewById(R.id.productNameEn);
        productPrice = findViewById(R.id.productPrice);
        productDescription = findViewById(R.id.productDescription);
        categoryName = findViewById(R.id.categoryName);
        stockInfo = findViewById(R.id.stockInfo);
        productEmoji = findViewById(R.id.productEmoji);
        quantityText = findViewById(R.id.quantityText);
        addToCartButton = findViewById(R.id.addToCartButton);
        backButton = findViewById(R.id.backButton);
        decreaseButton = findViewById(R.id.decreaseButton);
        increaseButton = findViewById(R.id.increaseButton);

        // Get product from intent
        String productJson = getIntent().getStringExtra("product");
        if (productJson != null) {
            product = new Gson().fromJson(productJson, Product.class);
            displayProductDetails();
        }

        // Set up button listeners
        backButton.setOnClickListener(v -> finish());

        decreaseButton.setOnClickListener(v -> {
            if (quantity > 1) {
                quantity--;
                updateQuantityDisplay();
            }
        });

        increaseButton.setOnClickListener(v -> {
            if (quantity < (product != null ? product.stock : 10)) {
                quantity++;
                updateQuantityDisplay();
            }
        });

        addToCartButton.setOnClickListener(v -> {
            if (product != null) {
                cartManager.addToCart(product, quantity);
                Toast.makeText(this, "Added " + quantity + " item(s) to cart", Toast.LENGTH_SHORT).show();
                finish();
            }
        });
    }

    private void displayProductDetails() {
        if (product != null) {
            productEmoji.setText(product.emoji);
            productName.setText(product.name);
            productNameEn.setText(product.nameEn);
            productPrice.setText(PricingUtils.formatINR(product.price));
            productDescription.setText(product.description);
            categoryName.setText(product.category);

            // Stock info
            if (product.isInStock()) {
                stockInfo.setText("In Stock (" + product.stock + " available)");
                stockInfo.setTextColor(getResources().getColor(R.color.in_stock));
            } else {
                stockInfo.setText("Out of Stock");
                stockInfo.setTextColor(getResources().getColor(R.color.out_of_stock));
                addToCartButton.setEnabled(false);
            }
        }
    }

    private void updateQuantityDisplay() {
        quantityText.setText(String.valueOf(quantity));
    }
}
