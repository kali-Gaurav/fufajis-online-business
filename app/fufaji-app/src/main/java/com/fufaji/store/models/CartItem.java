package com.fufaji.store.models;

public class CartItem {
    public String productId;
    public String productName;
    public String productNameEn;
    public String emoji;
    public double price;
    public int quantity;
    public int gst;
    public String category;
    public String image;

    public CartItem() {}

    public CartItem(Product product, int quantity) {
        this.productId = product.id;
        this.productName = product.name;
        this.productNameEn = product.nameEn;
        this.emoji = product.emoji;
        this.price = product.price;
        this.quantity = quantity;
        this.gst = product.gst;
        this.category = product.category;
        this.image = product.image;
    }

    public double getItemPrice() {
        return price * quantity;
    }

    public double getItemGST() {
        return getItemPrice() * (gst / 100.0);
    }

    public double getItemTotal() {
        return getItemPrice() + getItemGST();
    }

    public void updateQuantity(int newQuantity) {
        if (newQuantity > 0) {
            this.quantity = newQuantity;
        }
    }
}
