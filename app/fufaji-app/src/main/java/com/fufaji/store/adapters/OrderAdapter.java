package com.fufaji.store.adapters;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.fufaji.store.R;
import com.fufaji.store.models.Order;
import com.fufaji.store.utils.PricingUtils;

import java.text.SimpleDateFormat;
import java.util.List;
import java.util.Locale;

public class OrderAdapter extends RecyclerView.Adapter<OrderAdapter.OrderViewHolder> {
    private List<Order> orders;
    private OnOrderClickListener listener;

    public interface OnOrderClickListener {
        void onOrderClicked(Order order);
        void onOrderStatusUpdate(Order order, String newStatus);
    }

    public OrderAdapter(List<Order> orders) {
        this.orders = orders;
    }

    public void setOnOrderClickListener(OnOrderClickListener listener) {
        this.listener = listener;
    }

    @NonNull
    @Override
    public OrderViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_order, parent, false);
        return new OrderViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull OrderViewHolder holder, int position) {
        Order order = orders.get(position);
        holder.bind(order, listener);
    }

    @Override
    public int getItemCount() {
        return orders.size();
    }

    public static class OrderViewHolder extends RecyclerView.ViewHolder {
        private TextView orderIdText;
        private TextView orderDateText;
        private TextView orderStatusText;
        private TextView customerNameText;
        private TextView itemCountText;
        private TextView totalAmountText;
        private Button viewDetailsButton;
        private Button updateStatusButton;

        public OrderViewHolder(@NonNull View itemView) {
            super(itemView);
            orderIdText = itemView.findViewById(R.id.orderIdText);
            orderDateText = itemView.findViewById(R.id.orderDateText);
            orderStatusText = itemView.findViewById(R.id.orderStatusText);
            customerNameText = itemView.findViewById(R.id.customerNameText);
            itemCountText = itemView.findViewById(R.id.itemCountText);
            totalAmountText = itemView.findViewById(R.id.totalAmountText);
            viewDetailsButton = itemView.findViewById(R.id.viewDetailsButton);
            updateStatusButton = itemView.findViewById(R.id.updateStatusButton);
        }

        public void bind(Order order, OnOrderClickListener listener) {
            orderIdText.setText("Order #" + order.orderId);
            customerNameText.setText(order.customerName);
            itemCountText.setText(order.items.size() + " items");
            totalAmountText.setText(PricingUtils.formatINR(order.total));

            // Format and display date
            SimpleDateFormat sdf = new SimpleDateFormat("MMM dd, yyyy HH:mm", Locale.getDefault());
            orderDateText.setText(sdf.format(order.createdAt));

            // Status display with color coding
            orderStatusText.setText(getStatusDisplay(order.orderStatus));
            orderStatusText.setTextColor(getStatusColor(order.orderStatus));

            viewDetailsButton.setOnClickListener(v -> {
                if (listener != null) {
                    listener.onOrderClicked(order);
                }
            });

            updateStatusButton.setOnClickListener(v -> {
                String nextStatus = getNextStatus(order.orderStatus);
                if (listener != null && nextStatus != null) {
                    listener.onOrderStatusUpdate(order, nextStatus);
                }
            });
        }

        private String getStatusDisplay(String status) {
            return switch (status) {
                case "pending" -> "⏳ Pending";
                case "confirmed" -> "✓ Confirmed";
                case "packed" -> "📦 Packed";
                case "out_for_delivery" -> "🚚 Out for Delivery";
                case "delivered" -> "✓✓ Delivered";
                case "cancelled" -> "✗ Cancelled";
                default -> status;
            };
        }

        private int getStatusColor(String status) {
            return switch (status) {
                case "pending" -> itemView.getContext().getColor(R.color.warning_color);
                case "confirmed" -> itemView.getContext().getColor(R.color.info_color);
                case "packed" -> itemView.getContext().getColor(R.color.primary_color);
                case "out_for_delivery" -> itemView.getContext().getColor(R.color.accent_color);
                case "delivered" -> itemView.getContext().getColor(R.color.success_color);
                case "cancelled" -> itemView.getContext().getColor(R.color.error_color);
                default -> itemView.getContext().getColor(R.color.text_secondary);
            };
        }

        private String getNextStatus(String currentStatus) {
            return switch (currentStatus) {
                case "pending" -> "confirmed";
                case "confirmed" -> "packed";
                case "packed" -> "out_for_delivery";
                case "out_for_delivery" -> "delivered";
                default -> null;
            };
        }
    }
}
