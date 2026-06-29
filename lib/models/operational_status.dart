import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

enum OperationalStatus {
  healthy,
  warning,
  critical,
  blocked
}

extension OperationalStatusExtension on OperationalStatus {
  Color get color {
    switch (this) {
      case OperationalStatus.healthy:
        return AppTheme.success;
      case OperationalStatus.warning:
        return AppTheme.warning;
      case OperationalStatus.critical:
        return AppTheme.error;
      case OperationalStatus.blocked:
        return Colors.grey.shade800;
    }
  }

  String get label {
    switch (this) {
      case OperationalStatus.healthy:
        return 'Healthy';
      case OperationalStatus.warning:
        return 'Warning';
      case OperationalStatus.critical:
        return 'Critical';
      case OperationalStatus.blocked:
        return 'Blocked';
    }
  }

  IconData get icon {
    switch (this) {
      case OperationalStatus.healthy:
        return Icons.check_circle;
      case OperationalStatus.warning:
        return Icons.warning_amber_rounded;
      case OperationalStatus.critical:
        return Icons.error;
      case OperationalStatus.blocked:
        return Icons.block;
    }
  }
}
