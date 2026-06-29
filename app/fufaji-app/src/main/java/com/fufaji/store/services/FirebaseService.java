package com.fufaji.store.services;

import android.content.Context;
import androidx.annotation.NonNull;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.PhoneAuthOptions;
import com.google.firebase.auth.PhoneAuthProvider;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.Query;
import com.google.firebase.firestore.QuerySnapshot;
import com.google.firebase.storage.FirebaseStorage;
import timber.log.Timber;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import com.fufaji.store.models.Product;
import com.fufaji.store.models.Order;
import com.fufaji.store.models.User;
import com.fufaji.store.models.CartItem;
import com.fufaji.store.utils.Constants;

public class FirebaseService {
    private static FirebaseService instance;
    private final FirebaseAuth auth;
    private final FirebaseFirestore db;
    private final FirebaseStorage storage;
    private Context context;

    public interface OnSuccessListener<T> {
        void onSuccess(T result);
    }

    public interface OnFailureListener {
        void onFailure(String error);
    }

    private FirebaseService(Context context) {
        this.context = context;
        this.auth = FirebaseAuth.getInstance();
        this.db = FirebaseFirestore.getInstance();
        this.storage = FirebaseStorage.getInstance();
    }

    public static synchronized FirebaseService getInstance(Context context) {
        if (instance == null) {
            instance = new FirebaseService(context);
        }
        return instance;
    }

    // ===== AUTHENTICATION =====

    public void sendOTP(String phoneNumber, OnSuccessListener<String> successListener,
                        OnFailureListener failureListener) {
        String fullPhone = "+91" + phoneNumber;

        PhoneAuthOptions options = PhoneAuthOptions.newBuilder(auth)
                .setPhoneNumber(fullPhone)
                .setTimeout(Constants.OTP_TIMEOUT, TimeUnit.MILLISECONDS)
                .setActivity(null)
                .setCallbacks(new PhoneAuthProvider.OnVerificationStateChangedCallbacks() {
                    @Override
                    public void onVerificationCompleted(com.google.firebase.auth.PhoneAuthCredential credential) {
                        signInWithCredential(credential, successListener, failureListener);
                    }

                    @Override
                    public void onVerificationFailed(com.google.firebase.FirebaseException e) {
                        Timber.e(e, "Phone verification failed");
                        failureListener.onFailure(e.getMessage());
                    }

                    @Override
                    public void onCodeSent(@NonNull String verificationId, @NonNull PhoneAuthProvider.ForceResendingToken token) {
                        super.onCodeSent(verificationId, token);
                        successListener.onSuccess(verificationId);
                    }
                })
                .build();

        PhoneAuthProvider.verifyPhoneNumber(options);
    }

    public void verifyOTP(String verificationId, String code, OnSuccessListener<String> successListener,
                          OnFailureListener failureListener) {
        try {
            com.google.firebase.auth.PhoneAuthCredential credential =
                    PhoneAuthProvider.getCredential(verificationId, code);
            signInWithCredential(credential, successListener, failureListener);
        } catch (Exception e) {
            Timber.e(e, "OTP verification failed");
            failureListener.onFailure("Invalid OTP");
        }
    }

    private void signInWithCredential(com.google.firebase.auth.PhoneAuthCredential credential,
                                     OnSuccessListener<String> successListener, OnFailureListener failureListener) {
        auth.signInWithCredential(credential)
                .addOnCompleteListener(task -> {
                    if (task.isSuccessful()) {
                        String uid = auth.getCurrentUser().getUid();
                        successListener.onSuccess(uid);
                    } else {
                        failureListener.onFailure(task.getException().getMessage());
                    }
                });
    }

    public String getCurrentUserId() {
        return auth.getUid();
    }

    public boolean isLoggedIn() {
        return auth.getCurrentUser() != null;
    }

    public void logout() {
        auth.signOut();
    }

    // ===== PRODUCTS =====

    public void getProducts(String category, OnSuccessListener<List<Product>> successListener,
                           OnFailureListener failureListener) {
        db.collection(Constants.FIREBASE_PRODUCTS_COLLECTION)
                .whereEqualTo("category", category)
                .whereEqualTo("isActive", true)
                .orderBy("name")
                .limit(Constants.PRODUCTS_PAGE_SIZE)
                .get()
                .addOnSuccessListener(querySnapshot -> {
                    List<Product> products = querySnapshot.toObjects(Product.class);
                    successListener.onSuccess(products);
                })
                .addOnFailureListener(e -> failureListener.onFailure(e.getMessage()));
    }

    public void getAllProducts(OnSuccessListener<List<Product>> successListener,
                              OnFailureListener failureListener) {
        db.collection(Constants.FIREBASE_PRODUCTS_COLLECTION)
                .whereEqualTo("isActive", true)
                .get()
                .addOnSuccessListener(querySnapshot -> {
                    List<Product> products = querySnapshot.toObjects(Product.class);
                    successListener.onSuccess(products);
                })
                .addOnFailureListener(e -> failureListener.onFailure(e.getMessage()));
    }

    public void searchProducts(String query, OnSuccessListener<List<Product>> successListener,
                              OnFailureListener failureListener) {
        db.collection(Constants.FIREBASE_PRODUCTS_COLLECTION)
                .whereEqualTo("isActive", true)
                .get()
                .addOnSuccessListener(querySnapshot -> {
                    List<Product> allProducts = querySnapshot.toObjects(Product.class);
                    List<Product> filtered = allProducts.stream()
                            .filter(p -> p.name.toLowerCase().contains(query.toLowerCase()) ||
                                    p.nameEn.toLowerCase().contains(query.toLowerCase()))
                            .toList();
                    successListener.onSuccess(filtered);
                })
                .addOnFailureListener(e -> failureListener.onFailure(e.getMessage()));
    }

    // ===== ORDERS =====

    public void createOrder(Order order, OnSuccessListener<String> successListener,
                           OnFailureListener failureListener) {
        db.collection(Constants.FIREBASE_ORDERS_COLLECTION)
                .add(order)
                .addOnSuccessListener(documentReference -> {
                    String orderId = documentReference.getId();
                    successListener.onSuccess(orderId);
                })
                .addOnFailureListener(e -> failureListener.onFailure(e.getMessage()));
    }

    public void getOrders(String userId, OnSuccessListener<List<Order>> successListener,
                         OnFailureListener failureListener) {
        db.collection(Constants.FIREBASE_ORDERS_COLLECTION)
                .whereEqualTo("customerId", userId)
                .orderBy("createdAt", Query.Direction.DESCENDING)
                .get()
                .addOnSuccessListener(querySnapshot -> {
                    List<Order> orders = querySnapshot.toObjects(Order.class);
                    successListener.onSuccess(orders);
                })
                .addOnFailureListener(e -> failureListener.onFailure(e.getMessage()));
    }

    // ===== USERS =====

    public void createUser(User user, OnSuccessListener<Void> successListener,
                          OnFailureListener failureListener) {
        db.collection(Constants.FIREBASE_USERS_COLLECTION)
                .document(user.uid)
                .set(user)
                .addOnSuccessListener(aVoid -> successListener.onSuccess(null))
                .addOnFailureListener(e -> failureListener.onFailure(e.getMessage()));
    }

    public void getUserProfile(String userId, OnSuccessListener<User> successListener,
                              OnFailureListener failureListener) {
        db.collection(Constants.FIREBASE_USERS_COLLECTION)
                .document(userId)
                .get()
                .addOnSuccessListener(documentSnapshot -> {
                    User user = documentSnapshot.toObject(User.class);
                    successListener.onSuccess(user);
                })
                .addOnFailureListener(e -> failureListener.onFailure(e.getMessage()));
    }

    public void updateUserProfile(User user, OnSuccessListener<Void> successListener,
                                 OnFailureListener failureListener) {
        db.collection(Constants.FIREBASE_USERS_COLLECTION)
                .document(user.uid)
                .set(user)
                .addOnSuccessListener(aVoid -> successListener.onSuccess(null))
                .addOnFailureListener(e -> failureListener.onFailure(e.getMessage()));
    }

    // ===== CARTS =====

    public void saveCart(String userId, List<CartItem> items, OnSuccessListener<Void> successListener,
                        OnFailureListener failureListener) {
        Map<String, Object> cartData = new HashMap<>();
        cartData.put("items", items);
        cartData.put("lastUpdated", System.currentTimeMillis());

        db.collection(Constants.FIREBASE_CARTS_COLLECTION)
                .document(userId)
                .set(cartData)
                .addOnSuccessListener(aVoid -> successListener.onSuccess(null))
                .addOnFailureListener(e -> failureListener.onFailure(e.getMessage()));
    }

    // ===== ORDER UPDATE =====

    public void updateOrder(Order order, OnSuccessListener<Void> successListener,
                           OnFailureListener failureListener) {
        db.collection(Constants.FIREBASE_ORDERS_COLLECTION)
                .document(order.orderId)
                .set(order)
                .addOnSuccessListener(aVoid -> successListener.onSuccess(null))
                .addOnFailureListener(e -> failureListener.onFailure(e.getMessage()));
    }
}
