package com.fufaji.store.managers;

import android.content.Context;
import android.content.SharedPreferences;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import com.fufaji.store.models.CartItem;
import com.fufaji.store.models.Product;

import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;

public class CartManager {
    private static CartManager instance;
    private final SharedPreferences preferences;
    private final Gson gson;
    private List<CartItem> cartItems;
    private static final String CART_PREFS = "cart_items";
    private static final String PREF_NAME = "fufaji_cart";

    private CartManager(Context context) {
        this.preferences = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
        this.gson = new Gson();
        this.cartItems = loadCartFromPreferences();
    }

    public static synchronized CartManager getInstance(Context context) {
        if (instance == null) {
            instance = new CartManager(context);
        }
        return instance;
    }

    /**
     * Add product to cart or update quantity
     */
    public void addToCart(Product product, int quantity) {
        if (quantity <= 0) return;

        for (CartItem item : cartItems) {
            if (item.productId.equals(product.id)) {
                item.updateQuantity(item.quantity + quantity);
                saveCart();
                return;
            }
        }

        // New item
        CartItem newItem = new CartItem(product, quantity);
        cartItems.add(newItem);
        saveCart();
    }

    /**
     * Update quantity of item
     */
    public void updateQuantity(String productId, int newQuantity) {
        if (newQuantity <= 0) {
            removeFromCart(productId);
            return;
        }

        for (CartItem item : cartItems) {
            if (item.productId.equals(productId)) {
                item.updateQuantity(newQuantity);
                saveCart();
                return;
            }
        }
    }

    /**
     * Remove item from cart
     */
    public void removeFromCart(String productId) {
        cartItems.removeIf(item -> item.productId.equals(productId));
        saveCart();
    }

    /**
     * Get all cart items
     */
    public List<CartItem> getCartItems() {
        return new ArrayList<>(cartItems);
    }

    /**
     * Get item count
     */
    public int getCartItemCount() {
        int count = 0;
        for (CartItem item : cartItems) {
            count += item.quantity;
        }
        return count;
    }

    /**
     * Clear cart
     */
    public void clearCart() {
        cartItems.clear();
        saveCart();
    }

    /**
     * Save cart to preferences
     */
    public void saveCart() {
        String json = gson.toJson(cartItems);
        preferences.edit().putString(CART_PREFS, json).apply();
    }

    /**
     * Load cart from preferences
     */
    private List<CartItem> loadCartFromPreferences() {
        String json = preferences.getString(CART_PREFS, "[]");
        Type type = new TypeToken<List<CartItem>>(){}.getType();
        List<CartItem> items = gson.fromJson(json, type);
        return items != null ? items : new ArrayList<>();
    }

    /**
     * Check if product is in cart
     */
    public boolean isInCart(String productId) {
        for (CartItem item : cartItems) {
            if (item.productId.equals(productId)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Get quantity of product in cart
     */
    public int getQuantityInCart(String productId) {
        for (CartItem item : cartItems) {
            if (item.productId.equals(productId)) {
                return item.quantity;
            }
        }
        return 0;
    }
}
