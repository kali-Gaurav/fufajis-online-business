package com.fufaji.store.adapters;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Button;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.fufaji.store.R;
import com.fufaji.store.models.Product;
import com.fufaji.store.utils.PricingUtils;
import com.squareup.picasso.Picasso;

import java.util.List;

public class ProductAdapter extends RecyclerView.Adapter<ProductAdapter.ProductViewHolder> {
    private final List<Product> products;
    private final OnProductClickListener listener;

    public interface OnProductClickListener {
        void onProductClick(Product product);
    }

    public ProductAdapter(List<Product> products, OnProductClickListener listener) {
        this.products = products;
        this.listener = listener;
    }

    @NonNull
    @Override
    public ProductViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_product, parent, false);
        return new ProductViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull ProductViewHolder holder, int position) {
        Product product = products.get(position);
        holder.bind(product, listener);
    }

    @Override
    public int getItemCount() {
        return products.size();
    }

    public static class ProductViewHolder extends RecyclerView.ViewHolder {
        private final ImageView productImage;
        private final TextView productEmoji;
        private final TextView productName;
        private final TextView productPrice;
        private final TextView productRating;
        private final TextView stockStatus;
        private final Button addToCartButton;

        public ProductViewHolder(@NonNull View itemView) {
            super(itemView);
            productImage = itemView.findViewById(R.id.productImage);
            productEmoji = itemView.findViewById(R.id.productEmoji);
            productName = itemView.findViewById(R.id.productName);
            productPrice = itemView.findViewById(R.id.productPrice);
            productRating = itemView.findViewById(R.id.ratingValue);
            stockStatus = itemView.findViewById(R.id.stockStatus);
            addToCartButton = itemView.findViewById(R.id.addToCartButton);
        }

        public void bind(Product product, OnProductClickListener listener) {
            // Logic for Image vs Emoji
            if (product.image != null && !product.image.isEmpty()) {
                productEmoji.setVisibility(View.GONE);
                productImage.setVisibility(View.VISIBLE);
                Picasso.get()
                        .load(product.image)
                        .placeholder(android.R.drawable.ic_menu_gallery)
                        .into(productImage);
            } else {
                productImage.setVisibility(View.GONE);
                productEmoji.setVisibility(View.VISIBLE);
                productEmoji.setText(product.emoji);
            }

            productName.setText(product.name);
            productPrice.setText(PricingUtils.formatINR(product.price));

            if (product.rating > 0) {
                productRating.setText(String.format("★ %.1f", product.rating));
            }

            if (product.isInStock()) {
                stockStatus.setText("In Stock");
                stockStatus.setBackgroundColor(0xFF27AE60);
                addToCartButton.setEnabled(true);
            } else {
                stockStatus.setText("Out of Stock");
                stockStatus.setBackgroundColor(0xFFE74C3C);
                addToCartButton.setEnabled(false);
            }

            addToCartButton.setOnClickListener(v -> listener.onProductClick(product));
            itemView.setOnClickListener(v -> listener.onProductClick(product));
        }
    }
}
