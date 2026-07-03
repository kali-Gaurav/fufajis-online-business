import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/chat_suggestions_service.dart';
import '../constants/order_status.dart';
import '../utils/app_theme.dart';

/// Enhanced chat widget with suggested questions and quick replies
/// Displays contextual suggestions based on order state
class ChatWithSuggestions extends StatefulWidget {
  final OrderModel order;
  final Function(String) onQuestionSelected;
  final Widget chatMessages;
  final TextEditingController messageController;
  final Function(String) onSendMessage;

  const ChatWithSuggestions({
    super.key,
    required this.order,
    required this.onQuestionSelected,
    required this.chatMessages,
    required this.messageController,
    required this.onSendMessage,
  });

  @override
  State<ChatWithSuggestions> createState() => _ChatWithSuggestionsState();
}

class _ChatWithSuggestionsState extends State<ChatWithSuggestions> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final ChatSuggestionsService _suggestionsService = ChatSuggestionsService();
  bool _showSuggestions = true;
  late List<SuggestedQuestion> _suggestions;

  @override
  void initState() {
    super.initState();
    _suggestions = _suggestionsService.getSuggestedQuestions(widget.order);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Chat messages area
        Expanded(
          child: Column(
            children: [
              // Order header with summary
              _buildOrderHeader(),
              // Messages
              Expanded(child: widget.chatMessages),
            ],
          ),
        ),

        // Suggested questions (shown if no message typed and suggestions available)
        if (_showSuggestions && widget.messageController.text.isEmpty) _buildSuggestionsPanel(),

        // Message input area
        _buildMessageInput(),
      ],
    );
  }

  /// Order summary header
  Widget _buildOrderHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.grey50,
        border: Border(bottom: BorderSide(color: AppTheme.grey200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order #${widget.order.orderNumber.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                _getOrderStatusBadge(widget.order.status),
                style: TextStyle(
                  fontSize: 12,
                  color: _getStatusColor(widget.order.status),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              // Navigate to order details
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'View Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Suggested questions panel
  Widget _buildSuggestionsPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: const BoxDecoration(
        color: AppTheme.grey50,
        border: Border(top: BorderSide(color: AppTheme.grey200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '💡 Suggested Questions',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey700,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _showSuggestions = false);
                  },
                  child: const Icon(Icons.close, size: 16, color: AppTheme.grey500),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final suggestion in _suggestions.take(4)) ...[
                  _buildSuggestionChip(suggestion),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Individual suggestion chip
  Widget _buildSuggestionChip(SuggestedQuestion suggestion) {
    return GestureDetector(
      onTap: () {
        _onSuggestionSelected(suggestion);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(suggestion.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                suggestion.question,
                style: const TextStyle(fontSize: 12, color: AppTheme.grey900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Message input area with send button
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.grey200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Attachment button
            IconButton(
              icon: const Icon(Icons.attach_file, color: AppTheme.primary),
              onPressed: () {
                // TODO: Implement file attachment
              },
            ),

            // Text field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.grey300),
                ),
                child: TextField(
                  controller: widget.messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type your message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintStyle: TextStyle(color: AppTheme.grey500),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (value) {
                    setState(() {}); // Rebuild to hide/show suggestions
                  },
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            GestureDetector(
              onTap: widget.messageController.text.trim().isEmpty
                  ? null
                  : () {
                      widget.onSendMessage(widget.messageController.text.trim());
                      widget.messageController.clear();
                      setState(() {}); // Rebuild to show suggestions again
                    },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.messageController.text.trim().isEmpty
                      ? AppTheme.grey300
                      : AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle suggestion selection
  void _onSuggestionSelected(SuggestedQuestion suggestion) {
    // If question has auto-response, show it first
    if (suggestion.autoResponse != null) {
      _showResponseDialog(suggestion);
    } else {
      // Otherwise, send the question to chat
      widget.messageController.text = suggestion.question;
      widget.onSendMessage(suggestion.question);
      widget.messageController.clear();
    }

    // Hide suggestions after selection
    setState(() => _showSuggestions = false);

    // Call the callback
    widget.onQuestionSelected(suggestion.question);
  }

  /// Show auto-response in dialog
  void _showResponseDialog(SuggestedQuestion suggestion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(suggestion.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text(suggestion.question)),
          ],
        ),
        content: Text(suggestion.autoResponse ?? ''),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.messageController.text = suggestion.question;
              widget.onSendMessage(suggestion.question);
              widget.messageController.clear();
            },
            child: const Text('Ask more'),
          ),
        ],
      ),
    );
  }

  /// Get status badge text
  String _getOrderStatusBadge(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return '⏳ Pending';
      case OrderStatus.confirmed:
        return '✅ Confirmed';
      case OrderStatus.processing:
        return '📦 Processing';
      case OrderStatus.packed:
        return '📦 Packed';
      case OrderStatus.shipped:
        return '🚗 Shipped';
      case OrderStatus.outForDelivery:
        return '🚗 Out for Delivery';
      case OrderStatus.delivered:
        return '✅ Delivered';
      case OrderStatus.completed:
        return '✅ Completed';
      case OrderStatus.cancelled:
        return '❌ Cancelled';
      case OrderStatus.returned:
        return '↩️ Returned';
      case OrderStatus.refunded:
        return '💰 Refunded';
    }
  }

  /// Get status color
  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return AppTheme.success;
      case OrderStatus.cancelled:
      case OrderStatus.returned:
        return AppTheme.error;
      case OrderStatus.outForDelivery:
        return AppTheme.primary;
      default:
        return AppTheme.grey600;
    }
  }
}

/// Expanded invoice display widget for chat
class ChatInvoiceMessage extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback? onDownload;

  const ChatInvoiceMessage({super.key, required this.invoice, this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.grey50,
        border: const Border(left: BorderSide(color: AppTheme.primary, width: 4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📄 Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          _buildInvoiceRow('Subtotal', invoice['amount']),
          _buildInvoiceRow('Tax', invoice['tax']),
          _buildInvoiceRow('Delivery', invoice['delivery'], optional: true),
          _buildInvoiceRow('Discount', invoice['discount'], optional: true),
          const Divider(height: 16),
          _buildInvoiceRow('Total', invoice['total'], bold: true),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Download Invoice'),
              onPressed: onDownload,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(
    String label,
    dynamic amount, {
    bool bold = false,
    bool optional = false,
  }) {
    final amountValue = amount is num ? amount : double.tryParse(amount.toString()) ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: optional ? AppTheme.grey600 : AppTheme.grey900,
            ),
          ),
          Text(
            '₹${amountValue.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: optional ? AppTheme.grey600 : AppTheme.grey900,
            ),
          ),
        ],
      ),
    );
  }
}
