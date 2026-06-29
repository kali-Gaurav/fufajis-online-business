package com.fufaji.store.activities;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.widget.Button;
import android.widget.ImageButton;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.fufaji.store.R;
import com.fufaji.store.services.FirebaseService;
import com.fufaji.store.utils.Constants;

import timber.log.Timber;

public class AccountActivity extends AppCompatActivity {
    private TextView userNameText;
    private TextView userPhoneText;
    private TextView userEmailText;
    private TextView totalOrdersText;
    private TextView totalSpentText;

    private Button editProfileButton;
    private Button addressesButton;
    private Button preferencesButton;
    private Button logoutButton;

    private FirebaseService firebaseService;
    private SharedPreferences preferences;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_account);

        // Initialize views
        userNameText = findViewById(R.id.userNameText);
        userPhoneText = findViewById(R.id.userPhoneText);
        userEmailText = findViewById(R.id.userEmailText);
        totalOrdersText = findViewById(R.id.totalOrdersText);
        totalSpentText = findViewById(R.id.totalSpentText);

        editProfileButton = findViewById(R.id.editProfileButton);
        addressesButton = findViewById(R.id.addressesButton);
        preferencesButton = findViewById(R.id.preferencesButton);
        logoutButton = findViewById(R.id.logoutButton);

        ImageButton backButton = findViewById(R.id.backButton);

        firebaseService = FirebaseService.getInstance(this);
        preferences = getSharedPreferences(Constants.PREFERENCES_NAME, MODE_PRIVATE);

        // Back button
        backButton.setOnClickListener(v -> finish());

        // Button listeners
        editProfileButton.setOnClickListener(v ->
            Toast.makeText(this, "Edit profile coming soon", Toast.LENGTH_SHORT).show());

        addressesButton.setOnClickListener(v ->
            Toast.makeText(this, "Manage addresses coming soon", Toast.LENGTH_SHORT).show());

        preferencesButton.setOnClickListener(v ->
            Toast.makeText(this, "Preferences coming soon", Toast.LENGTH_SHORT).show());

        logoutButton.setOnClickListener(v -> logoutUser());

        // Load user profile
        loadUserProfile();
    }

    private void loadUserProfile() {
        String userId = firebaseService.getCurrentUserId();
        if (userId == null) {
            Toast.makeText(this, "User not logged in", Toast.LENGTH_SHORT).show();
            return;
        }

        firebaseService.getUserProfile(userId,
                user -> {
                    if (user != null) {
                        userNameText.setText(user.name != null ? user.name : "User");
                        userPhoneText.setText(user.phone);
                        userEmailText.setText(user.email != null ? user.email : "No email");
                        totalOrdersText.setText(String.valueOf(user.totalOrders));
                        totalSpentText.setText("₹" + (long) user.totalSpent);
                    }
                },
                error -> {
                    Toast.makeText(this, "Error loading profile: " + error, Toast.LENGTH_SHORT).show();
                    Timber.e("Error loading user profile: %s", error);
                });
    }

    private void logoutUser() {
        // Clear preferences
        SharedPreferences.Editor editor = preferences.edit();
        editor.clear();
        editor.apply();

        // Sign out from Firebase
        firebaseService.logout();

        // Navigate to login
        Intent intent = new Intent(this, LoginActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }
}
