package com.fufaji.store.adapters;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.fufaji.store.R;
import com.fufaji.store.models.Product;
import com.fufaji.store.utils.PricingUtils;

import java.util.List;

public class InventoryAdapter extends RecyclerView.Adapter<InventoryAdapter.InventoryViewHolder> {
    private List<Product> products;
    private OnInventoryActionListener listener;

    public interface OnInventoryActionListener {
        void onStockUpdate(Product product, int newStock);
        void onProductDelete(Product product);
        void onProductEdit(Product product);
    }

    public InventoryAdapter(List<Product> products) {
        this.products = products;
    }

    public void setOnInventoryActionListener(OnInventoryActionListener listener) {
        this.listener = listener;
    }

    @NonNull
    @Override
    public InventoryViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_inventory, parent, false);
        return new InventoryViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull InventoryViewHolder holder, int position) {
        Product product = products.get(position);
        holder.bind(product, listener);
    }

    @Override
    public int getItemCount() {
        return products.size();
    }

    public static class InventoryViewHolder extends RecyclerView.ViewHolder {
        private TextView productEmojiText;
        private TextView productNameText;
        private TextView productCategoryText;
        private TextView productPriceText;
        private TextView stockStatusText;
        private EditText stockInputText;
        private ImageButton decreaseStockButton;
        private ImageButton increaseStockButton;
        private ImageButton saveStockButton;
        private ImageButton deleteButton;
        private ImageButton editButton;

        public InventoryViewHolder(@NonNull View itemView) {
            super(itemView);
            productEmojiText = itemView.findViewById(R.id.productEmojiText);
            productNameText = itemView.findViewById(R.id.productNameText);
            productCategoryText = itemView.findViewById(R.id.productCategoryText);
            productPriceText = itemView.findViewById(R.id.productPriceText);
            stockStatusText = itemView.findViewById(R.id.stockStatusText);
            stockInputText = itemView.findViewById(R.id.stockInputText);
            decreaseStockButton = itemView.findViewById(R.id.decreaseStockButton);
            increaseStockButton = itemView.findViewById(R.id.increaseStockButton);
            saveStockButton = itemView.findViewById(R.id.saveStockButton);
            deleteButton = itemView.findViewById(R.id.deleteButton);
            editButton = itemView.findViewById(R.id.editButton);
        }

        public void bind(Product product, OnInventoryActionListener listener) {
            productEmojiText.setText(product.emoji);
            productNameText.setText(product.name);
            productCategoryText.setText(product.category);
            productPriceText.setText(PricingUtils.formatINR(product.price));

            // Stock status display
            updateStockDisplay(product);

            // Stock input field
            stockInputText.setText(String.valueOf(product.stock));

            // Stock control buttons
            decreaseStockButton.setOnClickListener(v -> {
                int currentStock = Integer.parseInt(stockInputText.getText().toString());
                if (currentStock > 0) {
                    stockInputText.setText(String.valueOf(currentStock - 1));
                }
            });

            increaseStockButton.setOnClickListener(v -> {
                int currentStock = Integer.parseInt(stockInputText.getText().toString());
                stockInputText.setText(String.valueOf(currentStock + 1));
            });

            saveStockButton.setOnClickListener(v -> {
                int newStock = Integer.parseInt(stockInputText.getText().toString());
                if (listener != null) {
                    listener.onStockUpdate(product, newStock);
                }
            });

            deleteButton.setOnClickListener(v -> {
                if (listener != null) {
                    listener.onProductDelete(product);
                }
            });

            editButton.setOnClickListener(v -> {
                if (listener != null) {
                    listener.onProductEdit(product);
                }
            });
        }

        private void updateStockDisplay(Product product) {
            if (product.stock == 0) {
                stockStatusText.setText("Out of Stock");
                stockStatusText.setTextColor(itemView.getContext().getColor(R.color.out_of_stock));
            } else if (product.stock < 5) {
                stockStatusText.setText("Low Stock (" + product.stock + ")");
                stockStatusText.setTextColor(itemView.getContext().getColor(R.color.low_stock));
            } else {
                stockStatusText.setText("In Stock (" + product.stock + ")");
                stockStatusText.setTextColor(itemView.getContext().getColor(R.color.in_stock));
            }
        }
    }
}
