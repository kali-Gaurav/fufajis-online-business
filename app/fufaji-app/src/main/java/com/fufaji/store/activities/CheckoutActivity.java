package com.fufaji.store.activities;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ProgressBar;
import android.widget.RadioButton;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.fufaji.store.R;
import com.fufaji.store.managers.CartManager;
import com.fufaji.store.models.CartItem;
import com.fufaji.store.models.Order;
import com.fufaji.store.services.FirebaseService;
import com.fufaji.store.services.RazorpayPaymentService;
import com.fufaji.store.utils.Constants;
import com.fufaji.store.utils.PricingUtils;
import com.fufaji.store.utils.ValidationUtils;
import timber.log.Timber;

import java.util.List;

public class CheckoutActivity extends AppCompatActivity {
    private EditText nameInput;
    private EditText phoneInput;
    private EditText addressInput;
    private EditText pincodeInput;
    private TextView summaryTotal;
    private RadioButton upiOption;
    private RadioButton cardOption;
    private Button payNowButton;
    private Button continueToPaymentButton;
    private ProgressBar progressBar;
    private View addressSection;
    private View summarySection;

    private CartManager cartManager;
    private FirebaseService firebaseService;
    private RazorpayPaymentService paymentService;
    private SharedPreferences preferences;
    private static final String PREF_NAME = "fufaji_prefs";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_checkout);

        // Initialize views
        nameInput = findViewById(R.id.nameInput);
        phoneInput = findViewById(R.id.phoneInput);
        addressInput = findViewById(R.id.addressInput);
        pincodeInput = findViewById(R.id.pincodeInput);
        summaryTotal = findViewById(R.id.summaryTotal);
        upiOption = findViewById(R.id.upiRadio);
        cardOption = findViewById(R.id.cardRadio);
        payNowButton = findViewById(R.id.payNowButton);
        continueToPaymentButton = findViewById(R.id.continueToPaymentButton);
        progressBar = findViewById(R.id.loadingProgress);
        addressSection = findViewById(R.id.addressSection);
        summarySection = findViewById(R.id.summarySection);

        // Initialize services
        cartManager = CartManager.getInstance(this);
        firebaseService = FirebaseService.getInstance(this);
        paymentService = RazorpayPaymentService.getInstance(this, Constants.RAZORPAY_KEY_ID);
        preferences = getSharedPreferences(PREF_NAME, MODE_PRIVATE);

        // Pre-fill user data
        String userPhone = preferences.getString(Constants.PREF_USER_PHONE, "");
        String userName = preferences.getString(Constants.PREF_USER_NAME, "");
        phoneInput.setText(userPhone);
        nameInput.setText(userName);

        // Step navigation
        continueToPaymentButton.setOnClickListener(v -> {
            if (validateForm()) {
                addressSection.setVisibility(View.GONE);
                summarySection.setVisibility(View.VISIBLE);
                showOrderSummary();
            }
        });

        // Setup pay button
        payNowButton.setOnClickListener(v -> initiatePayment());
        
        findViewById(R.id.backButton).setOnClickListener(v -> onBackPressed());
    }

    private boolean validateForm() {
        String name = nameInput.getText().toString().trim();
        String phone = phoneInput.getText().toString().trim();
        String address = addressInput.getText().toString().trim();
        String pincode = pincodeInput.getText().toString().trim();

        if (!ValidationUtils.isValidCheckoutForm(name, phone, address, pincode)) {
            Toast.makeText(this, "Please fill all fields correctly", Toast.LENGTH_SHORT).show();
            return false;
        }
        return true;
    }

    private void showOrderSummary() {
        List<CartItem> items = cartManager.getCartItems();
        double total = PricingUtils.calculateCartSubtotal(items) + PricingUtils.calculateCartGST(items);
        summaryTotal.setText(PricingUtils.formatINR(total));
    }

    private void initiatePayment() {
        progressBar.setVisibility(View.VISIBLE);

        List<CartItem> items = cartManager.getCartItems();
        Order order = new Order(
                preferences.getString(Constants.PREF_USER_ID, ""),
                nameInput.getText().toString(),
                phoneInput.getText().toString(),
                addressInput.getText().toString(),
                items
        );

        firebaseService.createOrder(order,
                orderId -> {
                    order.orderId = orderId;
                    order.paymentMethod = upiOption.isChecked() ? Constants.PAYMENT_METHOD_UPI : Constants.PAYMENT_METHOD_CARD;

                    long amountInPaise = RazorpayPaymentService.formatAmountToPaise(order.total);
                    paymentService.initiatePayment(CheckoutActivity.this,
                            amountInPaise,
                            orderId,
                            "",
                            phoneInput.getText().toString(),
                            new RazorpayPaymentService.OnPaymentListener() {
                                @Override
                                public void onPaymentSuccess(String paymentId) {
                                    progressBar.setVisibility(View.GONE);
                                    order.paymentStatus = Constants.PAYMENT_STATUS_SUCCESS;
                                    order.paymentId = paymentId;

                                    firebaseService.updateOrder(order, (aVoid) -> {
                                        Toast.makeText(CheckoutActivity.this, Constants.DAD_JOKE_ORDER_PLACED, Toast.LENGTH_LONG).show();
                                        cartManager.clearCart();
                                        Intent intent = new Intent(CheckoutActivity.this, OrderSuccessActivity.class);
                                        intent.putExtra("order_id", orderId);
                                        startActivity(intent);
                                        finish();
                                    }, error -> {
                                        Toast.makeText(CheckoutActivity.this, "Error: " + error, Toast.LENGTH_SHORT).show();
                                    });
                                }

                                @Override
                                public void onPaymentError(String error) {
                                    progressBar.setVisibility(View.GONE);
                                    Toast.makeText(CheckoutActivity.this, "Payment failed: " + error, Toast.LENGTH_SHORT).show();
                                }
                            });
                },
                error -> {
                    progressBar.setVisibility(View.GONE);
                    Toast.makeText(this, "Error: " + error, Toast.LENGTH_SHORT).show();
                });
    }
}
