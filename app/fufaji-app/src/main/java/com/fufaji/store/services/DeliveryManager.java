package com.fufaji.store.services;

import com.google.firebase.firestore.FirebaseFirestore;

import timber.log.Timber;

public class DeliveryManager {
    private static DeliveryManager instance;
    private final FirebaseFirestore db;

    public interface DeliveryListener {
        void onDeliveryAssigned(String orderId, String deliveryPartnerId);
        void onDeliveryStarted(String orderId);
        void onDeliveryCompleted(String orderId);
        void onError(String error);
    }

    private DeliveryListener listener;

    private DeliveryManager() {
        this.db = FirebaseFirestore.getInstance();
    }

    public static synchronized DeliveryManager getInstance() {
        if (instance == null) {
            instance = new DeliveryManager();
        }
        return instance;
    }

    public void setListener(DeliveryListener listener) {
        this.listener = listener;
    }

    // ===== DELIVERY PARTNER MANAGEMENT =====

    /**
     * Find available delivery partner for order
     * Considers: location, current load, ratings, availability
     */
    public void findAvailableDeliveryPartner(String orderId, double latitude, double longitude) {
        Timber.d("Finding delivery partner for order: %s at %.4f, %.4f", orderId, latitude, longitude);

        // Query Firestore for nearby, available delivery partners
        db.collection("delivery_partners")
                .whereEqualTo("isAvailable", true)
                .orderBy("rating", com.google.firebase.firestore.Query.Direction.DESCENDING)
                .limit(5)
                .get()
                .addOnSuccessListener(querySnapshot -> {
                    if (!querySnapshot.isEmpty()) {
                        // Select first available partner
                        String partnerId = querySnapshot.getDocuments().get(0).getId();
                        assignDeliveryPartner(orderId, partnerId);
                    } else {
                        if (listener != null) {
                            listener.onError("No available delivery partners");
                        }
                        Timber.w("No available delivery partners");
                    }
                })
                .addOnFailureListener(e -> {
                    if (listener != null) {
                        listener.onError(e.getMessage());
                    }
                    Timber.e(e, "Error finding delivery partner");
                });
    }

    /**
     * Assign delivery partner to order
     */
    public void assignDeliveryPartner(String orderId, String deliveryPartnerId) {
        db.collection("orders").document(orderId)
                .update("assignedDeliveryPartner", deliveryPartnerId)
                .addOnSuccessListener(aVoid -> {
                    if (listener != null) {
                        listener.onDeliveryAssigned(orderId, deliveryPartnerId);
                    }
                    Timber.d("Delivery partner assigned: %s to order %s", deliveryPartnerId, orderId);

                    // Update delivery partner's load
                    incrementDeliveryPartnerLoad(deliveryPartnerId);
                })
                .addOnFailureListener(e -> {
                    if (listener != null) {
                        listener.onError(e.getMessage());
                    }
                    Timber.e(e, "Error assigning delivery partner");
                });
    }

    /**
     * Start delivery for order
     */
    public void startDelivery(String orderId, String deliveryPartnerId) {
        db.collection("orders").document(orderId)
                .update(
                        "orderStatus", "out_for_delivery",
                        "deliveryStartTime", System.currentTimeMillis()
                )
                .addOnSuccessListener(aVoid -> {
                    if (listener != null) {
                        listener.onDeliveryStarted(orderId);
                    }
                    Timber.d("Delivery started for order: %s by partner: %s", orderId, deliveryPartnerId);
                })
                .addOnFailureListener(e -> {
                    if (listener != null) {
                        listener.onError(e.getMessage());
                    }
                    Timber.e(e, "Error starting delivery");
                });
    }

    /**
     * Complete delivery with proof (photo/signature)
     */
    public void completeDelivery(String orderId, String deliveryPartnerId, String proofUrl) {
        db.collection("orders").document(orderId)
                .update(
                        "orderStatus", "delivered",
                        "deliveredAt", System.currentTimeMillis(),
                        "deliveryProof", proofUrl
                )
                .addOnSuccessListener(aVoid -> {
                    if (listener != null) {
                        listener.onDeliveryCompleted(orderId);
                    }
                    Timber.d("Delivery completed for order: %s", orderId);

                    // Update delivery partner's load
                    decrementDeliveryPartnerLoad(deliveryPartnerId);
                    updateDeliveryPartnerStats(deliveryPartnerId);
                })
                .addOnFailureListener(e -> {
                    if (listener != null) {
                        listener.onError(e.getMessage());
                    }
                    Timber.e(e, "Error completing delivery");
                });
    }

    // ===== DELIVERY PARTNER METRICS =====

    private void incrementDeliveryPartnerLoad(String deliveryPartnerId) {
        db.collection("delivery_partners").document(deliveryPartnerId)
                .update("currentLoad", com.google.firebase.firestore.FieldValue.increment(1))
                .addOnFailureListener(e -> Timber.e(e, "Error incrementing load"));
    }

    private void decrementDeliveryPartnerLoad(String deliveryPartnerId) {
        db.collection("delivery_partners").document(deliveryPartnerId)
                .update("currentLoad", com.google.firebase.firestore.FieldValue.increment(-1))
                .addOnFailureListener(e -> Timber.e(e, "Error decrementing load"));
    }

    private void updateDeliveryPartnerStats(String deliveryPartnerId) {
        db.collection("delivery_partners").document(deliveryPartnerId)
                .update(
                        "totalDeliveries", com.google.firebase.firestore.FieldValue.increment(1),
                        "lastDeliveryTime", System.currentTimeMillis()
                )
                .addOnFailureListener(e -> Timber.e(e, "Error updating stats"));
    }

    /**
     * Get delivery partner's current location (real-time tracking)
     */
    public void trackDeliveryLocation(String deliveryPartnerId, LocationCallback callback) {
        db.collection("delivery_partners").document(deliveryPartnerId)
                .addSnapshotListener((value, error) -> {
                    if (error != null) {
                        Timber.e(error, "Error tracking location");
                        return;
                    }

                    if (value != null && value.exists()) {
                        Double latitude = value.getDouble("latitude");
                        Double longitude = value.getDouble("longitude");

                        if (latitude != null && longitude != null) {
                            callback.onLocationUpdate(latitude, longitude);
                        }
                    }
                });
    }

    public interface LocationCallback {
        void onLocationUpdate(double latitude, double longitude);
    }

    /**
     * Rate delivery experience
     */
    public void rateDeliveryPartner(String deliveryPartnerId, float rating, String comment) {
        db.collection("delivery_partners").document(deliveryPartnerId)
                .update(
                        "totalRatings", com.google.firebase.firestore.FieldValue.increment(1),
                        "sumRatings", com.google.firebase.firestore.FieldValue.increment(rating)
                )
                .addOnSuccessListener(aVoid -> {
                    // Calculate new average rating
                    calculateAverageRating(deliveryPartnerId);
                    Timber.d("Delivery partner rated: %s with %f stars", deliveryPartnerId, rating);
                })
                .addOnFailureListener(e -> Timber.e(e, "Error rating delivery partner"));
    }

    private void calculateAverageRating(String deliveryPartnerId) {
        db.collection("delivery_partners").document(deliveryPartnerId)
                .get()
                .addOnSuccessListener(documentSnapshot -> {
                    if (documentSnapshot.exists()) {
                        Long totalRatings = documentSnapshot.getLong("totalRatings");
                        Double sumRatings = documentSnapshot.getDouble("sumRatings");

                        if (totalRatings != null && sumRatings != null && totalRatings > 0) {
                            double averageRating = sumRatings / totalRatings;
                            documentSnapshot.getReference()
                                    .update("rating", averageRating);
                        }
                    }
                })
                .addOnFailureListener(e -> Timber.e(e, "Error calculating average rating"));
    }
}
