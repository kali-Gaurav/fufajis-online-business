package com.fufaji.store.activities;

import android.content.Intent;
import android.os.Bundle;
import android.widget.Button;
import android.widget.TextView;

import androidx.appcompat.app.AppCompatActivity;

import com.fufaji.store.R;
import com.fufaji.store.utils.PricingUtils;

public class OrderSuccessActivity extends AppCompatActivity {
    private TextView orderIdText;
    private TextView totalText;
    private Button continueShoppingButton;
    private Button viewOrderButton;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_order_success);

        orderIdText = findViewById(R.id.orderIdText);
        totalText = findViewById(R.id.totalText);
        continueShoppingButton = findViewById(R.id.continueShoppingButton);
        viewOrderButton = findViewById(R.id.viewOrderButton);

        String orderId = getIntent().getStringExtra("order_id");
        double total = getIntent().getDoubleExtra("total", 0);

        orderIdText.setText("Order ID: " + orderId);
        totalText.setText("Total: " + PricingUtils.formatINR(total));

        continueShoppingButton.setOnClickListener(v -> {
            startActivity(new Intent(this, MainActivity.class));
            finish();
        });

        viewOrderButton.setOnClickListener(v -> {
            Intent intent = new Intent(this, OrderHistoryActivity.class);
            intent.putExtra("order_id", orderId);
            startActivity(intent);
            finish();
        });
    }
}
