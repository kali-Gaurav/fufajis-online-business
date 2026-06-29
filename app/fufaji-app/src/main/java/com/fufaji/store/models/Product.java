package com.fufaji.store.models;

import androidx.annotation.NonNull;
import com.google.firebase.firestore.IgnoreExtraProperties;

@IgnoreExtraProperties
public class Product {
    public String id;
    public String name;
    public String nameEn;
    public String category;
    public double price;
    public int stock;
    public String emoji;
    public String image;
    public String description;
    public int gst;
    public boolean isActive;
    public String dadJoke;
    public double rating;
    public int reviewCount;
    public String subcategory;
    public boolean isDeals;
    public int discount;

    public Product() {
        // Default constructor for Firestore
    }

    public Product(String id, String name, String nameEn, String category,
                   double price, int stock, String emoji, String image,
                   String description, int gst, boolean isActive, String dadJoke) {
        this.id = id;
        this.name = name;
        this.nameEn = nameEn;
        this.category = category;
        this.price = price;
        this.stock = stock;
        this.emoji = emoji;
        this.image = image;
        this.description = description;
        this.gst = gst;
        this.isActive = isActive;
        this.dadJoke = dadJoke;
        this.rating = 0.0;
        this.reviewCount = 0;
        this.discount = 0;
    }

    public double getPriceWithGST() {
        return price + (price * gst / 100.0);
    }

    public boolean isInStock() {
        return stock > 0;
    }

    public boolean isLowStock() {
        return stock > 0 && stock < 20;
    }

    @NonNull
    @Override
    public String toString() {
        return "Product{" +
                "id='" + id + '\'' +
                ", name='" + name + '\'' +
                ", price=" + price +
                ", category='" + category + '\'' +
                '}';
    }
}
