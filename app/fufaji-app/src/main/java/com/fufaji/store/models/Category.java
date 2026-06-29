package com.fufaji.store.models;

import java.util.List;

public class Category {
    public String id;
    public String name;
    public String nameEn;
    public String emoji;
    public String icon;
    public List<String> subCategories;
    public int productCount;
    public boolean isActive;

    public Category() {}

    public Category(String id, String name, String nameEn, String emoji, String icon) {
        this.id = id;
        this.name = name;
        this.nameEn = nameEn;
        this.emoji = emoji;
        this.icon = icon;
        this.isActive = true;
        this.productCount = 0;
    }

    public String getDisplayName() {
        return emoji + " " + name;
    }

    public String getDisplayNameEn() {
        return emoji + " " + nameEn;
    }
}
