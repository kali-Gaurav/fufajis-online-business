package com.fufaji.store.adapters;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.fufaji.store.R;
import com.fufaji.store.models.Category;

import java.util.List;

public class CategoryAdapter extends RecyclerView.Adapter<CategoryAdapter.CategoryViewHolder> {
    private final List<Category> categories;
    private final OnCategoryClickListener listener;
    private int selectedPosition = -1;

    public interface OnCategoryClickListener {
        void onCategoryClick(Category category);
    }

    public CategoryAdapter(List<Category> categories, OnCategoryClickListener listener) {
        this.categories = categories;
        this.listener = listener;
    }

    @NonNull
    @Override
    public CategoryViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_category, parent, false);
        return new CategoryViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull CategoryViewHolder holder, int position) {
        Category category = categories.get(position);
        boolean isSelected = position == selectedPosition;
        holder.bind(category, isSelected, () -> {
            int oldPosition = selectedPosition;
            selectedPosition = position;
            if (oldPosition != -1) {
                notifyItemChanged(oldPosition);
            }
            notifyItemChanged(position);
            listener.onCategoryClick(category);
        });
    }

    @Override
    public int getItemCount() {
        return categories.size();
    }

    public static class CategoryViewHolder extends RecyclerView.ViewHolder {
        private final TextView categoryText;
        private final View categoryContainer;

        public CategoryViewHolder(@NonNull View itemView) {
            super(itemView);
            categoryText = itemView.findViewById(R.id.categoryName);
            categoryContainer = itemView.findViewById(R.id.categoryBackground);
        }

        public void bind(Category category, boolean isSelected, Runnable onClickListener) {
            // Display emoji + name
            String displayText = category.emoji + "\n" + category.name;
            categoryText.setText(displayText);

            // Highlight selected category
            if (isSelected) {
                categoryContainer.setBackgroundColor(0xFF1A5276); // Primary blue
                categoryText.setTextColor(0xFFFFFFFF); // White text
            } else {
                categoryContainer.setBackgroundColor(0xFFFFFFFF); // White
                categoryText.setTextColor(0xFF1C2833); // Dark text
            }

            // Click listener
            itemView.setOnClickListener(v -> onClickListener.run());
        }
    }
}
