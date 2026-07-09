import 'package:cloud_firestore/cloud_firestore.dart';

/// Secondary Authentication Secret - Password record for non-customer users
class SecondaryAuthSecret {
  final String userId;
  final String email;
  final String role; // UserRole enum as string
  final String passwordHash;
  final String status; // 'active', 'revoked', 'expired'
  final bool isFirstLogin;
  final bool requiresPasswordChange;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;
  final DateTime? lastPasswordChangeAt;
  final DateTime? expiresAt;
  final int loginAttempts;
  final int failedAttempts; // For rate limiting
  final DateTime? lockedUntil;
  final bool requiresAdminApproval;
  final String? createdBy;
  final String? revokedBy;
  final DateTime? revokedAt;
  final List<String> passwordHistory; // Last 3 passwords hashes
  final int? maxPasswordAge; // Days until expiration

  SecondaryAuthSecret({
    required this.userId,
    required this.email,
    required this.role,
    required this.passwordHash,
    required this.status,
    required this.isFirstLogin,
    this.requiresPasswordChange = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    this.lastPasswordChangeAt,
    this.expiresAt,
    this.loginAttempts = 0,
    this.failedAttempts = 0,
    this.lockedUntil,
    this.requiresAdminApproval = false,
    this.createdBy,
    this.revokedBy,
    this.revokedAt,
    this.passwordHistory = const [],
    this.maxPasswordAge = 90, // 90 days default
  });

  bool get isActive => status == 'active' && revokedAt == null;
  bool get isLocked => lockedUntil != null && DateTime.now().isBefore(lockedUntil!);
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get passwordExpired =>
    maxPasswordAge != null &&
    lastPasswordChangeAt != null &&
    DateTime.now().difference(lastPasswordChangeAt!).inDays > maxPasswordAge!;

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'email': email,
      'role': role,
      'password_hash': passwordHash,
      'status': status,
      'is_first_login': isFirstLogin,
      'requires_password_change': requiresPasswordChange,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_login_at': lastLoginAt,
      'last_password_change_at': lastPasswordChangeAt,
      'expires_at': expiresAt,
      'login_attempts': loginAttempts,
      'failed_attempts': failedAttempts,
      'locked_until': lockedUntil,
      'requires_admin_approval': requiresAdminApproval,
      'created_by': createdBy,
      'revoked_by': revokedBy,
      'revoked_at': revokedAt,
      'password_history': passwordHistory,
      'max_password_age': maxPasswordAge,
    };
  }

  factory SecondaryAuthSecret.fromMap(Map<String, dynamic> map) {
    return SecondaryAuthSecret(
      userId: map['user_id'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      passwordHash: map['password_hash'] ?? '',
      status: map['status'] ?? 'active',
      isFirstLogin: map['is_first_login'] ?? false,
      requiresPasswordChange: map['requires_password_change'] ?? false,
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (map['last_login_at'] as Timestamp?)?.toDate(),
      lastPasswordChangeAt: (map['last_password_change_at'] as Timestamp?)?.toDate(),
      expiresAt: (map['expires_at'] as Timestamp?)?.toDate(),
      loginAttempts: map['login_attempts'] ?? 0,
      failedAttempts: map['failed_attempts'] ?? 0,
      lockedUntil: (map['locked_until'] as Timestamp?)?.toDate(),
      requiresAdminApproval: map['requires_admin_approval'] ?? false,
      createdBy: map['created_by'],
      revokedBy: map['revoked_by'],
      revokedAt: (map['revoked_at'] as Timestamp?)?.toDate(),
      passwordHistory: List<String>.from(map['password_history'] ?? []),
      maxPasswordAge: map['max_password_age'] ?? 90,
    );
  }
}

/// Secondary Auth Session - Active user session tracking
class SecondaryAuthSession {
  final String sessionId;
  final String userId;
  final String email;
  final String role;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? lastActivityAt;
  final String? deviceId;
  final String? deviceName;
  final String ipAddress;
  final String userAgent;
  final bool isRememberedDevice;
  final bool isActive;

  SecondaryAuthSession({
    required this.sessionId,
    required this.userId,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.expiresAt,
    this.lastActivityAt,
    this.deviceId,
    this.deviceName,
    required this.ipAddress,
    required this.userAgent,
    this.isRememberedDevice = false,
    this.isActive = true,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => isActive && !isExpired;

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'user_id': userId,
      'email': email,
      'role': role,
      'created_at': createdAt,
      'expires_at': expiresAt,
      'last_activity_at': lastActivityAt,
      'device_id': deviceId,
      'device_name': deviceName,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'is_remembered_device': isRememberedDevice,
      'is_active': isActive,
    };
  }

  factory SecondaryAuthSession.fromMap(Map<String, dynamic> map) {
    return SecondaryAuthSession(
      sessionId: map['session_id'] ?? '',
      userId: map['user_id'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expires_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActivityAt: (map['last_activity_at'] as Timestamp?)?.toDate(),
      deviceId: map['device_id'],
      deviceName: map['device_name'],
      ipAddress: map['ip_address'] ?? '',
      userAgent: map['user_agent'] ?? '',
      isRememberedDevice: map['is_remembered_device'] ?? false,
      isActive: map['is_active'] ?? true,
    );
  }
}

/// Secondary Auth Device - Trusted device tracking
class SecondaryAuthDevice {
  final String deviceId;
  final String userId;
  final String deviceName;
  final String deviceModel;
  final String osVersion;
  final DateTime registeredAt;
  final DateTime? lastUsedAt;
  final bool isTrusted;
  final bool isRevoked;
  final String ipAddress;

  SecondaryAuthDevice({
    required this.deviceId,
    required this.userId,
    required this.deviceName,
    required this.deviceModel,
    required this.osVersion,
    required this.registeredAt,
    this.lastUsedAt,
    this.isTrusted = false,
    this.isRevoked = false,
    required this.ipAddress,
  });

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'user_id': userId,
      'device_name': deviceName,
      'device_model': deviceModel,
      'os_version': osVersion,
      'registered_at': registeredAt,
      'last_used_at': lastUsedAt,
      'is_trusted': isTrusted,
      'is_revoked': isRevoked,
      'ip_address': ipAddress,
    };
  }

  factory SecondaryAuthDevice.fromMap(Map<String, dynamic> map) {
    return SecondaryAuthDevice(
      deviceId: map['device_id'] ?? '',
      userId: map['user_id'] ?? '',
      deviceName: map['device_name'] ?? '',
      deviceModel: map['device_model'] ?? '',
      osVersion: map['os_version'] ?? '',
      registeredAt: (map['registered_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUsedAt: (map['last_used_at'] as Timestamp?)?.toDate(),
      isTrusted: map['is_trusted'] ?? false,
      isRevoked: map['is_revoked'] ?? false,
      ipAddress: map['ip_address'] ?? '',
    );
  }
}

/// Secondary Auth Audit Log - Comprehensive event logging
class SecondaryAuthAuditLog {
  final String logId;
  final String userId;
  final String email;
  final String eventType; // PASSWORD_CREATED, PASSWORD_CHANGED, LOGIN_SUCCESS, etc.
  final String status; // 'success', 'failed'
  final String? reason;
  final DateTime timestamp;
  final String? actorId; // Who performed this action (for admin actions)
  final String? ipAddress;
  final String? deviceId;
  final Map<String, dynamic>? metadata;

  SecondaryAuthAuditLog({
    required this.logId,
    required this.userId,
    required this.email,
    required this.eventType,
    required this.status,
    this.reason,
    required this.timestamp,
    this.actorId,
    this.ipAddress,
    this.deviceId,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'log_id': logId,
      'user_id': userId,
      'email': email,
      'event_type': eventType,
      'status': status,
      'reason': reason,
      'timestamp': timestamp,
      'actor_id': actorId,
      'ip_address': ipAddress,
      'device_id': deviceId,
      'metadata': metadata,
    };
  }

  factory SecondaryAuthAuditLog.fromMap(Map<String, dynamic> map) {
    return SecondaryAuthAuditLog(
      logId: map['log_id'] ?? '',
      userId: map['user_id'] ?? '',
      email: map['email'] ?? '',
      eventType: map['event_type'] ?? '',
      status: map['status'] ?? '',
      reason: map['reason'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      actorId: map['actor_id'],
      ipAddress: map['ip_address'],
      deviceId: map['device_id'],
      metadata: map['metadata'],
    );
  }
}

/// Rate Limit Status - Progressive rate limiting state
class RateLimitStatus {
  final int failedAttempts;
  final DateTime? lockedUntil;
  final int delaySeconds;
  final bool requiresAdminApproval;
  final String status; // 'allowed', 'delayed', 'locked', 'admin_approval_required'

  RateLimitStatus({
    required this.failedAttempts,
    this.lockedUntil,
    required this.delaySeconds,
    required this.requiresAdminApproval,
    required this.status,
  });

  bool get isLocked => lockedUntil != null && DateTime.now().isBefore(lockedUntil!);
  int get remainingLockSeconds =>
    isLocked ? lockedUntil!.difference(DateTime.now()).inSeconds : 0;
}

/// Password Change Request - For password updates
class PasswordChangeRequest {
  final String userId;
  final String currentPassword;
  final String newPassword;
  final String newPasswordConfirm;
  final DateTime requestedAt;
  final String? requestedBy; // For admin-initiated changes

  PasswordChangeRequest({
    required this.userId,
    required this.currentPassword,
    required this.newPassword,
    required this.newPasswordConfirm,
    required this.requestedAt,
    this.requestedBy,
  });
}

/// Admin Password Override - For admin-issued passwords
class AdminPasswordOverride {
  final String userId;
  final String newPassword;
  final String issuedBy;
  final DateTime issuedAt;
  final bool requiresChangeOnLogin;
  final DateTime? expiresAt;

  AdminPasswordOverride({
    required this.userId,
    required this.newPassword,
    required this.issuedBy,
    required this.issuedAt,
    this.requiresChangeOnLogin = true,
    this.expiresAt,
  });
}
