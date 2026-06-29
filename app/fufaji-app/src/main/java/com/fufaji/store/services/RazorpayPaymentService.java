package com.fufaji.store.services;

import android.app.Activity;
import android.content.Context;
import com.razorpay.Checkout;
import org.json.JSONObject;
import timber.log.Timber;

public class RazorpayPaymentService {
    private static RazorpayPaymentService instance;
    private final Context context;
    private final String razorpayKeyId;

    public interface OnPaymentListener {
        void onPaymentSuccess(String paymentId);
        void onPaymentError(String error);
    }

    private OnPaymentListener paymentListener;

    private RazorpayPaymentService(Context context, String razorpayKeyId) {
        this.context = context;
        this.razorpayKeyId = razorpayKeyId;
    }

    public static synchronized RazorpayPaymentService getInstance(Context context, String razorpayKeyId) {
        if (instance == null) {
            instance = new RazorpayPaymentService(context, razorpayKeyId);
        }
        return instance;
    }

    /**
     * Initiate payment with Razorpay
     * @param activity Current activity
     * @param amount Amount in paise (₹ * 100)
     * @param orderId Order ID for reference
     * @param customerEmail Customer email
     * @param customerPhone Customer phone
     * @param listener Payment callback listener
     */
    public void initiatePayment(Activity activity, double amount, String orderId,
                               String customerEmail, String customerPhone,
                               OnPaymentListener listener) {
        this.paymentListener = listener;

        try {
            Checkout checkout = new Checkout();
            checkout.setKeyID(razorpayKeyId);

            JSONObject options = new JSONObject();
            options.put("name", "Fufaji Store");
            options.put("description", "Online Grocery Shopping");
            options.put("image", "https://fufaji.store/logo.png");
            options.put("order_id", orderId);
            options.put("amount", (long) amount); // Amount in paise
            options.put("currency", "INR");
            options.put("prefill.email", customerEmail);
            options.put("prefill.contact", customerPhone);
            options.put("theme.color", "#1A5276");

            // UPI as primary
            options.put("method", "upi");

            checkout.open(activity, options);

        } catch (Exception e) {
            Timber.e(e, "Payment initiation failed");
            paymentListener.onPaymentError("Payment initiation failed: " + e.getMessage());
        }
    }

    /**
     * Handle payment success
     */
    public void onPaymentSuccess(String paymentId) {
        if (paymentListener != null) {
            paymentListener.onPaymentSuccess(paymentId);
        }
    }

    /**
     * Handle payment error
     */
    public void onPaymentError(int code, String response) {
        String errorMessage;
        switch (code) {
            case com.razorpay.Checkout.NETWORK_ERROR:
                errorMessage = "Network error. Please check your connection.";
                break;
            case com.razorpay.Checkout.INVALID_OPTIONS:
                errorMessage = "Invalid payment options.";
                break;
            case 0: // USER_CANCELLED
                errorMessage = "Payment cancelled by user.";
                break;
            default:
                errorMessage = "Payment failed: " + response;
        }

        if (paymentListener != null) {
            paymentListener.onPaymentError(errorMessage);
        }
    }

    /**
     * Format amount to paise
     * ₹100 = 10000 paise
     */
    public static long formatAmountToPaise(double amountInRupees) {
        return Math.round(amountInRupees * 100);
    }

    /**
     * Format paise to rupees
     */
    public static double formatPaiseToRupees(long paise) {
        return paise / 100.0;
    }
}
