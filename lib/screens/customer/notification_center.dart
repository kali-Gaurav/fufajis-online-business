import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../providers/notification_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

class NotificationCenter extends StatefulWidget {
  const NotificationCenter({super.key});

  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        Provider.of<NotificationProvider>(
          context,
          listen: false,
        ).initialize(authProvider.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          if (notificationProvider.unreadCount > 0)
            TextButton(
              onPressed: () {
                if (user != null) {
                  notificationProvider.markAllAsRead(user.id);
                }
              },
              child: const Text('Mark all as read'),
            ),
          if (notificationProvider.notifications.isNotEmpty)
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Text('Delete all'),
                  onTap: () {
                    if (user != null) {
                      notificationProvider.deleteAllNotifications(user.id);
                    }
                  },
                ),
              ],
            ),
        ],
      ),
      body: _buildNotificationList(notificationProvider, user?.id, context),
    );
  }

  Widget _buildNotificationList(
    NotificationProvider provider,
    String? userId,
    BuildContext context,
  ) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (provider.notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: AppTheme.grey400),
            SizedBox(height: 16),
            Text('No notifications yet', style: TextStyle(color: AppTheme.grey600, fontSize: 16)),
            SizedBox(height: 8),
            Text(
              'You\'ll see updates about orders, promotions, and more here',
              style: TextStyle(color: AppTheme.grey500, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: provider.notifications.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final notification = provider.notifications[index];
        return Dismissible(
          key: Key(notification.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: AppTheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (direction) {
            if (userId != null) {
              provider.deleteNotification(userId, notification.id);
            }
          },
          child: _NotificationTile(
            notification: notification,
            onTap: () {
              if (userId != null && !notification.isRead) {
                provider.markAsRead(userId, notification.id);
              }
              _handleNotificationClick(context, notification);
            },
            onDelete: () {
              if (userId != null) {
                provider.deleteNotification(userId, notification.id);
              }
            },
          ),
        );
      },
    );
  }

  void _handleNotificationClick(BuildContext context, NotificationModel notification) {
    // Navigate based on deep link or type
    if (notification.deepLink != null) {
      context.push(notification.deepLink!);
    } else if (notification.data?['orderId'] != null) {
      context.push('/customer/order-detail/${notification.data!['orderId']}');
    } else if (notification.data?['productId'] != null) {
      context.push('/customer/product-detail/${notification.data!['productId']}');
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: notification.isRead ? Colors.transparent : AppTheme.primary.withValues(alpha: 0.05),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getIconColor(notification.type).withValues(alpha: 0.1),
          child: Icon(
            _getIcon(notification.type),
            color: _getIconColor(notification.type),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: TextStyle(
                  fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              DateFormat('hh:mm a').format(notification.timestamp),
              style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.body,
              style: const TextStyle(fontSize: 13, color: AppTheme.grey700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd MMM yyyy').format(notification.timestamp),
              style: const TextStyle(fontSize: 11, color: AppTheme.grey400),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [PopupMenuItem(onTap: onDelete, child: const Text('Delete'))],
        ),
      ),
    );
  }

  IconData _getIcon(NotificationType? type) {
    switch (type) {
      case NotificationType.orderUpdate:
        return Icons.shopping_bag;
      case NotificationType.promotion:
        return Icons.local_offer;
      case NotificationType.priceDrop:
        return Icons.trending_down;
      case NotificationType.shopUpdate:
        return Icons.store;
      case NotificationType.systemMessage:
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(NotificationType? type) {
    switch (type) {
      case NotificationType.orderUpdate:
        return AppTheme.primary;
      case NotificationType.promotion:
        return AppTheme.info;
      case NotificationType.priceDrop:
        return AppTheme.warning;
      case NotificationType.shopUpdate:
        return AppTheme.info;
      case NotificationType.systemMessage:
        return Colors.purple;
      default:
        return AppTheme.grey500;
    }
  }
}
