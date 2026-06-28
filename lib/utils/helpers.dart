import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'monetary_value.dart';

/// Formats a double amount as Indian Rupees.
/// e.g. 1234.5 → '₹1,235'  or  49.9 → '₹50'
String formatCurrency(dynamic amount) {
  double value;
  if (amount is MonetaryValue) {
    value = amount.toDouble();
  } else if (amount is num) {
    value = amount.toDouble();
  } else {
    value = 0.0;
  }
  final formatter = NumberFormat('#,##,##0', 'en_IN');
  return '₹${formatter.format(value.roundToDouble())}';
}

/// Formats a DateTime as a human-readable date string.
/// e.g. DateTime(2026, 6, 2) → 'Jun 2, 2026'
String formatDate(DateTime dt) {
  return DateFormat('MMM d, yyyy').format(dt);
}

/// Formats a DateTime as date and time string.
/// e.g. DateTime(2026, 6, 2, 15, 45) → 'Jun 2, 2026 at 3:45 PM'
String formatDateTime(DateTime dt) {
  return DateFormat("MMM d, yyyy 'at' h:mm a").format(dt);
}

/// Returns a human-readable relative time string.
/// e.g. '2 hours ago', 'Just now', '3 days ago'
String timeAgo(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h ${h == 1 ? 'hour' : 'hours'} ago';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return '$d ${d == 1 ? 'day' : 'days'} ago';
  }
  if (diff.inDays < 30) {
    final w = (diff.inDays / 7).floor();
    return '$w ${w == 1 ? 'week' : 'weeks'} ago';
  }
  if (diff.inDays < 365) {
    final mo = (diff.inDays / 30).floor();
    return '$mo ${mo == 1 ? 'month' : 'months'} ago';
  }
  final y = (diff.inDays / 365).floor();
  return '$y ${y == 1 ? 'year' : 'years'} ago';
}

/// Returns a Color for a given order status string.
Color getOrderStatusColor(String status) {
  switch (status) {
    case 'OrderStatus.pending':
      return AppTheme.warning;
    case 'OrderStatus.confirmed':
      return AppTheme.info;
    case 'OrderStatus.processing':
      return const Color(0xFF9C27B0); // purple
    case 'OrderStatus.packed':
      return const Color(0xFF00BCD4); // cyan
    case 'OrderStatus.outForDelivery':
      return AppTheme.info;
    case 'OrderStatus.delivered':
      return AppTheme.success;
    case 'OrderStatus.cancelled':
      return AppTheme.error;
    case 'OrderStatus.returned':
      return AppTheme.grey600;
    case 'OrderStatus.refunded':
      return AppTheme.grey500;
    default:
      return AppTheme.grey400;
  }
}

/// Returns an IconData for a given order status string.
IconData getOrderStatusIcon(String status) {
  switch (status) {
    case 'OrderStatus.pending':
      return Icons.hourglass_empty;
    case 'OrderStatus.confirmed':
      return Icons.check_circle_outline;
    case 'OrderStatus.processing':
      return Icons.inventory_2_outlined;
    case 'OrderStatus.packed':
      return Icons.inventory_outlined;
    case 'OrderStatus.outForDelivery':
      return Icons.delivery_dining;
    case 'OrderStatus.delivered':
      return Icons.check_circle;
    case 'OrderStatus.cancelled':
      return Icons.cancel_outlined;
    case 'OrderStatus.returned':
      return Icons.assignment_return_outlined;
    case 'OrderStatus.refunded':
      return Icons.currency_rupee;
    default:
      return Icons.help_outline;
  }
}

/// Calculates distance between two lat/lng coordinates using the Haversine formula.
/// Returns distance in kilometres.
double distanceInKm(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const double earthRadiusKm = 6371.0;

  final double dLat = _degreesToRadians(lat2 - lat1);
  final double dLng = _degreesToRadians(lng2 - lng1);

  final double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) *
          cos(_degreesToRadians(lat2)) *
          sin(dLng / 2) *
          sin(dLng / 2);

  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degreesToRadians(double degrees) => degrees * pi / 180.0;

/// Returns true if the user's location is within the shop's delivery radius.
bool isWithinDeliveryRadius(
  double userLat,
  double userLng,
  double shopLat,
  double shopLng,
  double radiusKm,
) {
  return distanceInKm(userLat, userLng, shopLat, shopLng) <= radiusKm;
}

/// Generates a unique order ID with format FUJA + 8 timestamp chars.
/// e.g. 'FUJA13475861'
String generateOrderId() {
  final ts = DateTime.now().millisecondsSinceEpoch.toString();
  final suffix = ts.substring(ts.length - 8);
  return 'FUJA$suffix';
}

/// Validates an Indian mobile number (10 digits, starting 6-9).
bool validatePhoneNumber(String phone) {
  // Strip country code if present
  final cleaned = phone.replaceAll(RegExp(r'^\+?91'), '').trim();
  return RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned);
}
