/// Enumeration for alert types
enum AlertType {
  lowStock,
  orderStuck,
  paymentFailed,
  deliveryFailed,
  systemAlert,
  customerChurn,
  lowSales,
  securityAlert,
  systemFailure,
}

/// Enumeration for alert severity levels
enum AlertSeverity {
  critical, // Requires immediate action, displayed in red
  warning, // Should be addressed soon, displayed in yellow/orange
  info, // Informational, displayed in blue
}

extension AlertTypeExtension on AlertType {
  String get displayName {
    switch (this) {
      case AlertType.lowStock:
        return 'Low Stock';
      case AlertType.orderStuck:
        return 'Order Stuck';
      case AlertType.paymentFailed:
        return 'Payment Failed';
      case AlertType.deliveryFailed:
        return 'Delivery Failed';
      case AlertType.systemAlert:
        return 'System Alert';
      case AlertType.customerChurn:
        return 'Customer Churn';
      case AlertType.lowSales:
        return 'Low Sales';
      case AlertType.securityAlert:
        return 'Security Alert';
      case AlertType.systemFailure:
        return 'System Failure';
    }
  }

  String get description {
    switch (this) {
      case AlertType.lowStock:
        return 'Product stock is below minimum threshold';
      case AlertType.orderStuck:
        return 'Order is stuck in processing for too long';
      case AlertType.paymentFailed:
        return 'Payment transaction failed';
      case AlertType.deliveryFailed:
        return 'Delivery could not be completed';
      case AlertType.systemAlert:
        return 'System issue detected';
      case AlertType.customerChurn:
        return 'Repeated customer not ordering';
      case AlertType.lowSales:
        return 'Sales below expected average';
      case AlertType.securityAlert:
        return 'Suspicious security event detected';
      case AlertType.systemFailure:
        return 'Critical system failure detected';
    }
  }
}

extension AlertSeverityExtension on AlertSeverity {
  String get displayName {
    switch (this) {
      case AlertSeverity.critical:
        return 'Critical';
      case AlertSeverity.warning:
        return 'Warning';
      case AlertSeverity.info:
        return 'Info';
    }
  }
}

/// Model representing a dashboard alert
class AlertModel {
  final String alertId;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String message;
  final String? action; // Action to resolve (e.g., "Restock", "Cancel Order")
  final DateTime timestamp;
  final bool resolved;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final Map<String, dynamic>? metadata; // Additional context data

  const AlertModel({
    required this.alertId,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    this.action,
    required this.timestamp,
    this.resolved = false,
    this.resolvedBy,
    this.resolvedAt,
    this.metadata,
  });

  /// Factory constructor to create AlertModel from JSON/Map
  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      alertId: json['alertId'] as String? ?? '',
      type: _parseAlertType(json['type'] as String?),
      severity: _parseAlertSeverity(json['severity'] as String?),
      title: json['title'] as String? ?? 'Alert',
      message: json['message'] as String? ?? '',
      action: json['action'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      resolved: json['resolved'] as bool? ?? false,
      resolvedBy: json['resolvedBy'] as String?,
      resolvedAt: json['resolvedAt'] != null ? DateTime.parse(json['resolvedAt'] as String) : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert AlertModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'alertId': alertId,
      'type': type.toString().split('.').last,
      'severity': severity.toString().split('.').last,
      'title': title,
      'message': message,
      'action': action,
      'timestamp': timestamp.toIso8601String(),
      'resolved': resolved,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Helper to parse AlertType from string
  static AlertType _parseAlertType(String? value) {
    switch (value) {
      case 'lowStock':
        return AlertType.lowStock;
      case 'orderStuck':
        return AlertType.orderStuck;
      case 'paymentFailed':
        return AlertType.paymentFailed;
      case 'deliveryFailed':
        return AlertType.deliveryFailed;
      case 'customerChurn':
        return AlertType.customerChurn;
      case 'lowSales':
        return AlertType.lowSales;
      case 'securityAlert':
        return AlertType.securityAlert;
      case 'systemFailure':
        return AlertType.systemFailure;
      default:
        return AlertType.systemAlert;
    }
  }

  /// Helper to parse AlertSeverity from string
  static AlertSeverity _parseAlertSeverity(String? value) {
    switch (value) {
      case 'critical':
        return AlertSeverity.critical;
      case 'warning':
        return AlertSeverity.warning;
      default:
        return AlertSeverity.info;
    }
  }

  /// Get time since alert was created
  String get timeSinceCreated {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Copy with method for creating modified instances
  AlertModel copyWith({
    String? alertId,
    AlertType? type,
    AlertSeverity? severity,
    String? title,
    String? message,
    String? action,
    DateTime? timestamp,
    bool? resolved,
    String? resolvedBy,
    DateTime? resolvedAt,
    Map<String, dynamic>? metadata,
  }) {
    return AlertModel(
      alertId: alertId ?? this.alertId,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      message: message ?? this.message,
      action: action ?? this.action,
      timestamp: timestamp ?? this.timestamp,
      resolved: resolved ?? this.resolved,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'AlertModel(id: $alertId, type: ${type.displayName}, '
        'severity: ${severity.displayName}, title: $title, resolved: $resolved)';
  }
}
