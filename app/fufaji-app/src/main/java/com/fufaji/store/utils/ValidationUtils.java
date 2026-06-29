package com.fufaji.store.utils;

import android.util.Patterns;
import java.util.regex.Pattern;

public class ValidationUtils {
    private static final Pattern PHONE_PATTERN = Pattern.compile("^[0-9]{10}$");
    private static final Pattern PINCODE_PATTERN = Pattern.compile("^[0-9]{6}$");
    private static final Pattern NAME_PATTERN = Pattern.compile("^[a-zA-Z\\s]{2,50}$");

    /**
     * Validate Indian phone number (10 digits)
     */
    public static boolean isValidPhone(String phone) {
        if (phone == null || phone.isEmpty()) {
            return false;
        }
        // Remove any non-digit characters
        String cleaned = phone.replaceAll("[^0-9]", "");
        return PHONE_PATTERN.matcher(cleaned).matches();
    }

    /**
     * Validate Indian pincode (6 digits)
     */
    public static boolean isValidPincode(String pincode) {
        if (pincode == null || pincode.isEmpty()) {
            return false;
        }
        String cleaned = pincode.replaceAll("[^0-9]", "");
        return PINCODE_PATTERN.matcher(cleaned).matches();
    }

    /**
     * Validate name (only letters and spaces, 2-50 chars)
     */
    public static boolean isValidName(String name) {
        if (name == null || name.isEmpty()) {
            return false;
        }
        return NAME_PATTERN.matcher(name.trim()).matches();
    }

    /**
     * Validate email address
     */
    public static boolean isValidEmail(String email) {
        if (email == null || email.isEmpty()) {
            return false;
        }
        return Patterns.EMAIL_ADDRESS.matcher(email).matches();
    }

    /**
     * Validate OTP (6 digits)
     */
    public static boolean isValidOTP(String otp) {
        if (otp == null || otp.isEmpty()) {
            return false;
        }
        String cleaned = otp.replaceAll("[^0-9]", "");
        return cleaned.length() == 6;
    }

    /**
     * Validate address (minimum length)
     */
    public static boolean isValidAddress(String address) {
        return address != null && address.trim().length() >= 10;
    }

    /**
     * Sanitize input to prevent XSS
     */
    public static String sanitizeInput(String input) {
        if (input == null) {
            return "";
        }
        return input
                .replaceAll("<", "&lt;")
                .replaceAll(">", "&gt;")
                .replaceAll("\"", "&quot;")
                .replaceAll("'", "&#x27;")
                .replaceAll("/", "&#x2F;");
    }

    /**
     * Validate complete checkout form
     */
    public static boolean isValidCheckoutForm(String name, String phone, String address, String pincode) {
        return isValidName(name) &&
                isValidPhone(phone) &&
                isValidAddress(address) &&
                isValidPincode(pincode);
    }

    /**
     * Get formatted phone number for display
     */
    public static String formatPhoneNumber(String phone) {
        if (phone == null || phone.isEmpty()) {
            return "";
        }
        String cleaned = phone.replaceAll("[^0-9]", "");
        if (cleaned.length() == 10) {
            return "+91-" + cleaned.substring(0, 5) + "-" + cleaned.substring(5);
        }
        return phone;
    }
}
