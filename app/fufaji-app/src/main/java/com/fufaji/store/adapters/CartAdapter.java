package com.fufaji.store.adapters;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.fufaji.store.R;
import com.fufaji.store.models.CartItem;
import com.fufaji.store.utils.PricingUtils;
import com.squareup.picasso.Picasso;

import java.util.List;

public class CartAdapter extends RecyclerView.Adapter<CartAdapter.CartViewHolder> {
    private final List<CartItem> items;
    private final CartActionListener listener;

    public interface CartActionListener {
        void onQuantityChanged(CartItem item, int newQuantity);
        void onRemoveItem(CartItem item);
    }

    public CartAdapter(List<CartItem> items, CartActionListener listener) {
        this.items = items;
        this.listener = listener;
    }

    @NonNull
    @Override
    public CartViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_cart, parent, false);
        return new CartViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull CartViewHolder holder, int position) {
        CartItem item = items.get(position);
        holder.bind(item, listener);
    }

    @Override
    public int getItemCount() {
        return items.size();
    }

    public static class CartViewHolder extends RecyclerView.ViewHolder {
        private final ImageView productImage;
        private final TextView cartItemEmoji;
        private final TextView cartItemName;
        private final TextView cartItemPrice;
        private final TextView quantityText;
        private final ImageButton decreaseButton;
        private final ImageButton increaseButton;
        private final TextView cartItemTotal;
        private final ImageButton removeButton;

        public CartViewHolder(@NonNull View itemView) {
            super(itemView);
            productImage = itemView.findViewById(R.id.productImage);
            cartItemEmoji = itemView.findViewById(R.id.cartItemEmoji);
            cartItemName = itemView.findViewById(R.id.cartItemName);
            cartItemPrice = itemView.findViewById(R.id.cartItemPrice);
            quantityText = itemView.findViewById(R.id.quantityText);
            decreaseButton = itemView.findViewById(R.id.decreaseButton);
            increaseButton = itemView.findViewById(R.id.increaseButton);
            cartItemTotal = itemView.findViewById(R.id.cartItemTotal);
            removeButton = itemView.findViewById(R.id.removeButton);
        }

        public void bind(CartItem item, CartActionListener listener) {
            if (item.image != null && !item.image.isEmpty()) {
                cartItemEmoji.setVisibility(View.GONE);
                productImage.setVisibility(View.VISIBLE);
                Picasso.get()
                        .load(item.image)
                        .placeholder(android.R.drawable.ic_menu_gallery)
                        .into(productImage);
            } else {
                productImage.setVisibility(View.GONE);
                cartItemEmoji.setVisibility(View.VISIBLE);
                cartItemEmoji.setText(item.emoji);
            }

            cartItemName.setText(item.productName);
            cartItemPrice.setText(PricingUtils.formatINR(item.price));
            quantityText.setText(String.valueOf(item.quantity));
            cartItemTotal.setText("Total: " + PricingUtils.formatINR(item.price * item.quantity));

            decreaseButton.setOnClickListener(v -> {
                if (item.quantity > 1) {
                    listener.onQuantityChanged(item, item.quantity - 1);
                }
            });

            increaseButton.setOnClickListener(v -> {
                listener.onQuantityChanged(item, item.quantity + 1);
            });

            removeButton.setOnClickListener(v -> listener.onRemoveItem(item));
        }
    }
}
