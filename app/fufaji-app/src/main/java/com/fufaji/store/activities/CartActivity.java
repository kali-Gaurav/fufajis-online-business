package com.fufaji.store.activities;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import androidx.recyclerview.widget.RecyclerView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;

import com.fufaji.store.R;
import com.fufaji.store.adapters.CartAdapter;
import com.fufaji.store.managers.CartManager;
import com.fufaji.store.models.CartItem;
import com.fufaji.store.utils.PricingUtils;
import com.fufaji.store.utils.Constants;

import java.util.List;

public class CartActivity extends AppCompatActivity {
    private RecyclerView cartRecyclerView;
    private TextView subtotalText;
    private TextView gstText;
    private TextView totalText;
    private Button checkoutButton;
    private Button continueshoppingButton;
    private LinearLayout emptyCartLayout;
    private LinearLayout cartLayout;
    private CartAdapter cartAdapter;
    private CartManager cartManager;
    private SharedPreferences preferences;
    private static final String PREF_NAME = "fufaji_prefs";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_cart);

        // Initialize views
        cartRecyclerView = findViewById(R.id.cartRecyclerView);
        subtotalText = findViewById(R.id.subtotalText);
        gstText = findViewById(R.id.gstText);
        totalText = findViewById(R.id.totalText);
        checkoutButton = findViewById(R.id.proceedButton);
        continueshoppingButton = findViewById(R.id.continueShoppingButton);
        emptyCartLayout = findViewById(R.id.emptyCart);
        cartLayout = findViewById(R.id.cartRecyclerView);

        // Initialize managers
        cartManager = CartManager.getInstance(this);
        preferences = getSharedPreferences(PREF_NAME, MODE_PRIVATE);

        // Setup recyclerview
        setupCartRecyclerView();

        // Setup buttons
        checkoutButton.setOnClickListener(v -> proceedToCheckout());
        continueshoppingButton.setOnClickListener(v -> {
            startActivity(new Intent(this, MainActivity.class));
            finish();
        });

        // Load cart
        loadCart();
    }

    private void setupCartRecyclerView() {
        List<CartItem> cartItems = cartManager.getCartItems();
        cartAdapter = new CartAdapter(cartItems, new CartAdapter.CartActionListener() {
            @Override
            public void onQuantityChanged(CartItem item, int newQuantity) {
                cartManager.updateQuantity(item.productId, newQuantity);
                updateTotals();
            }

            @Override
            public void onRemoveItem(CartItem item) {
                cartManager.removeFromCart(item.productId);
                cartAdapter.notifyDataSetChanged();
                updateTotals();
            }
        });

        cartRecyclerView.setLayoutManager(new LinearLayoutManager(this));
        cartRecyclerView.setAdapter(cartAdapter);
    }

    private void loadCart() {
        List<CartItem> items = cartManager.getCartItems();

        if (items.isEmpty()) {
            emptyCartLayout.setVisibility(View.VISIBLE);
            cartLayout.setVisibility(View.GONE);
            checkoutButton.setEnabled(false);
            Toast.makeText(this, Constants.DAD_JOKE_EMPTY_CART, Toast.LENGTH_LONG).show();
        } else {
            emptyCartLayout.setVisibility(View.GONE);
            cartLayout.setVisibility(View.VISIBLE);
            checkoutButton.setEnabled(true);
            updateTotals();
        }
    }

    private void updateTotals() {
        List<CartItem> items = cartManager.getCartItems();

        double subtotal = PricingUtils.calculateCartSubtotal(items);
        double gst = PricingUtils.calculateCartGST(items);
        double total = subtotal + gst;

        subtotalText.setText("Subtotal: " + PricingUtils.formatINR(subtotal));
        gstText.setText("GST (18%): " + PricingUtils.formatINR(gst));
        totalText.setText("Total: " + PricingUtils.formatINR(total));
    }

    private void proceedToCheckout() {
        List<CartItem> items = cartManager.getCartItems();

        if (items.isEmpty()) {
            Toast.makeText(this, "Cart is empty!", Toast.LENGTH_SHORT).show();
            return;
        }

        // Save cart items to preferences for checkout
        cartManager.saveCart();

        Intent intent = new Intent(this, CheckoutActivity.class);
        startActivity(intent);
    }

    @Override
    protected void onResume() {
        super.onResume();
        cartAdapter.notifyDataSetChanged();
        updateTotals();
    }
}
