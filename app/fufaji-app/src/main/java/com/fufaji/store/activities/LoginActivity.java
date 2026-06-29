package com.fufaji.store.activities;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.fufaji.store.R;
import com.fufaji.store.services.FirebaseService;
import com.fufaji.store.utils.Constants;
import com.fufaji.store.utils.ValidationUtils;
import timber.log.Timber;

public class LoginActivity extends AppCompatActivity {
    private EditText phoneInput;
    private EditText otpInput;
    private Button sendOtpButton;
    private Button verifyOtpButton;
    private ProgressBar progressBar;
    private TextView otpSentText;
    private FirebaseService firebaseService;
    private SharedPreferences preferences;
    private String verificationId;
    private static final String PREF_NAME = "fufaji_prefs";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_login);

        // Initialize views
        phoneInput = findViewById(R.id.phoneInput);
        otpInput = findViewById(R.id.otpInput);
        sendOtpButton = findViewById(R.id.sendOtpButton);
        verifyOtpButton = findViewById(R.id.verifyOtpButton);
        progressBar = findViewById(R.id.loadingProgress);

        // Initialize services
        firebaseService = FirebaseService.getInstance(this);
        preferences = getSharedPreferences(PREF_NAME, MODE_PRIVATE);

        // Check if already logged in
        if (firebaseService.isLoggedIn()) {
            startActivity(new Intent(this, MainActivity.class));
            finish();
        }

        // Setup listeners
        sendOtpButton.setOnClickListener(v -> sendOTP());
        verifyOtpButton.setOnClickListener(v -> verifyOTP());
    }

    private void sendOTP() {
        String phone = phoneInput.getText().toString().trim();

        if (!ValidationUtils.isValidPhone(phone)) {
            phoneInput.setError("Please enter a valid 10-digit phone number");
            return;
        }

        progressBar.setVisibility(View.VISIBLE);
        sendOtpButton.setEnabled(false);

        firebaseService.sendOTP(phone,
                verificationId -> {
                    this.verificationId = verificationId;
                    progressBar.setVisibility(View.GONE);
                    sendOtpButton.setEnabled(true);

                    // Show OTP input
                    otpInput.setVisibility(View.VISIBLE);
                    verifyOtpButton.setVisibility(View.VISIBLE);
                    otpSentText.setVisibility(View.VISIBLE);
                    otpSentText.setText("OTP sent to " + phone);

                    Toast.makeText(this, "OTP sent successfully", Toast.LENGTH_SHORT).show();
                },
                error -> {
                    progressBar.setVisibility(View.GONE);
                    sendOtpButton.setEnabled(true);
                    Toast.makeText(this, "Error: " + error, Toast.LENGTH_SHORT).show();
                    Timber.e("OTP send error: %s", error);
                });
    }

    private void verifyOTP() {
        String otp = otpInput.getText().toString().trim();

        if (!ValidationUtils.isValidOTP(otp)) {
            otpInput.setError("Please enter a valid 6-digit OTP");
            return;
        }

        if (verificationId == null) {
            Toast.makeText(this, "Please send OTP first", Toast.LENGTH_SHORT).show();
            return;
        }

        progressBar.setVisibility(View.VISIBLE);
        verifyOtpButton.setEnabled(false);

        firebaseService.verifyOTP(verificationId, otp,
                userId -> {
                    progressBar.setVisibility(View.GONE);
                    verifyOtpButton.setEnabled(true);

                    // Save user ID
                    preferences.edit()
                            .putString(Constants.PREF_USER_ID, userId)
                            .putString(Constants.PREF_USER_PHONE, phoneInput.getText().toString().trim())
                            .apply();

                    Toast.makeText(this, "Login successful!", Toast.LENGTH_SHORT).show();

                    // Check if new user or existing
                    startActivity(new Intent(this, MainActivity.class));
                    finish();
                },
                error -> {
                    progressBar.setVisibility(View.GONE);
                    verifyOtpButton.setEnabled(true);
                    otpInput.setError("Invalid OTP");
                    Toast.makeText(this, "Verification failed: " + error, Toast.LENGTH_SHORT).show();
                    Timber.e("OTP verify error: %s", error);
                });
    }
}
