package com.fufaji.store.models;

import java.util.ArrayList;
import java.util.List;

public class User {
    public String uid;
    public String phone;
    public String name;
    public String email;
    public String role;  // customer, employee, delivery_partner, owner, admin
    public boolean isActive;
    public long createdAt;
    public String profileImage;
    public List<String> addresses;
    public String defaultAddressId;
    public double walletBalance;
    public int totalOrders;
    public double totalSpent;
    public String preferredLanguage;  // hi, en

    public User() {
        this.addresses = new ArrayList<>();
        this.preferredLanguage = "en";
        this.isActive = true;
        this.walletBalance = 0.0;
        this.totalOrders = 0;
        this.totalSpent = 0.0;
    }

    public User(String uid, String phone, String name, String role) {
        this();
        this.uid = uid;
        this.phone = phone;
        this.name = name;
        this.role = role;
        this.createdAt = System.currentTimeMillis();
    }

    public boolean isCustomer() {
        return "customer".equals(role);
    }

    public boolean isEmployee() {
        return "employee".equals(role);
    }

    public boolean isOwner() {
        return "owner".equals(role) || "admin".equals(role);
    }

    public boolean isDeliveryPartner() {
        return "delivery_partner".equals(role);
    }

    public void addAddress(String address) {
        if (addresses == null) {
            addresses = new ArrayList<>();
        }
        addresses.add(address);
    }

    public String getDisplayName() {
        return name + " (" + phone + ")";
    }
}
