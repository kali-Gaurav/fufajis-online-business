import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an MFA secret password record for a user
class MFASecret {
  final String userId;
  final String email;
  final String role; // UserRole enum as string
  final String passwordHash; // PBKDF2 hashed
  final String status; // "active" or "revoked"
  final bool isFirstLogin; // true = needs to set password
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy; // User ID of admin who issued it
  final DateTime? revokedAt;
  final String? revokedBy; // User ID of admin who revoked
  final int loginAttempts; // Failed login counter
  final DateTime? lastLoginAt;

  MFASecret({
    required this.userId,
    required this.email,
    required this.role,
    required this.passwordHash,
    required this.status,
    required this.isFirstLogin,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.revokedAt,
    this.revokedBy,
    this.loginAttempts = 0,
    this.lastLoginAt,
  });

  /// Create MFASecret from Firestore document
  factory MFASecret.fromMap(Map<String, dynamic> map) {
    return MFASecret(
      userId: map['userId'] as String,
      email: map['email'] as String,
      role: map['role'] as String,
      passwordHash: map['password_hash'] as String,
      status: map['status'] as String? ?? 'active',
      isFirstLogin: map['is_first_login'] as bool? ?? false,
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['created_by'] as String?,
      revokedAt: (map['revoked_at'] as Timestamp?)?.toDate(),
      revokedBy: map['revoked_by'] as String?,
      loginAttempts: map['login_attempts'] as int? ?? 0,
      lastLoginAt: (map['last_login_at'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore document map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'role': role,
      'password_hash': passwordHash,
      'status': status,
      'is_first_login': isFirstLogin,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'created_by': createdBy,
      'revoked_at': revokedAt != null ? Timestamp.fromDate(revokedAt!) : null,
      'revoked_by': revokedBy,
      'login_attempts': loginAttempts,
      'last_login_at': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
    };
  }

  /// Create copy with updated fields
  MFASecret copyWith({
    String? userId,
    String? email,
    String? role,
    String? passwordHash,
    String? status,
    bool? isFirstLogin,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    DateTime? revokedAt,
    String? revokedBy,
    int? loginAttempts,
    DateTime? lastLoginAt,
  }) {
    return MFASecret(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      role: role ?? this.role,
      passwordHash: passwordHash ?? this.passwordHash,
      status: status ?? this.status,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      revokedAt: revokedAt ?? this.revokedAt,
      revokedBy: revokedBy ?? this.revokedBy,
      loginAttempts: loginAttempts ?? this.loginAttempts,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  /// Check if password is active and not revoked
  bool get isActive => status == 'active';

  /// Check if this is first login (needs setup)
  bool get needsSetup => isFirstLogin;
}

/// Represents an MFA audit log entry
class MFAAuditLog {
  final String id;
  final String userId;
  final String eventType; // password_created, password_revoked, login_attempt, etc.
  final String? actorId; // Who performed the action
  final String status; // success or failed
  final String? reason; // For failures: invalid_password, password_revoked, rate_limit
  final String? ipAddress;
  final String? deviceId;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  MFAAuditLog({
    required this.id,
    required this.userId,
    required this.eventType,
    this.actorId,
    required this.status,
    this.reason,
    this.ipAddress,
    this.deviceId,
    required this.timestamp,
    this.metadata,
  });

  /// Create from Firestore document
  factory MFAAuditLog.fromMap(String id, Map<String, dynamic> map) {
    return MFAAuditLog(
      id: id,
      userId: map['user_id'] as String,
      eventType: map['event_type'] as String,
      actorId: map['actor_id'] as String?,
      status: map['status'] as String,
      reason: map['reason'] as String?,
      ipAddress: map['ip_address'] as String?,
      deviceId: map['device_id'] as String?,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to Firestore document map
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'event_type': eventType,
      'actor_id': actorId,
      'status': status,
      'reason': reason,
      'ip_address': ipAddress,
      'device_id': deviceId,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }
}

/// Represents MFA setup data during first login
class MFASetupData {
  final String password;
  final String passwordConfirm;

  MFASetupData({
    required this.password,
    required this.passwordConfirm,
  });

  /// Validate passwords match
  bool get passwordsMatch => password == passwordConfirm;

  /// Check if password meets requirements
  bool get isValidPassword {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false; // uppercase
    if (!password.contains(RegExp(r'[0-9]'))) return false; // number
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false; // special char
    return true;
  }
}

/// Represents MFA verification attempt
class MFAVerificationAttempt {
  final String userId;
  final String password;
  final String? deviceId;
  final String? ipAddress;
  final DateTime timestamp;

  MFAVerificationAttempt({
    required this.userId,
    required this.password,
    this.deviceId,
    this.ipAddress,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
