import 'package:google_maps_flutter/google_maps_flutter.dart';

enum VerificationMethod { otp, signature, checkbox }

extension VerificationMethodExtension on VerificationMethod {
  String get value {
    switch (this) {
      case VerificationMethod.otp:
        return 'otp';
      case VerificationMethod.signature:
        return 'signature';
      case VerificationMethod.checkbox:
        return 'checkbox';
    }
  }

  static VerificationMethod fromString(String value) {
    switch (value) {
      case 'otp':
        return VerificationMethod.otp;
      case 'signature':
        return VerificationMethod.signature;
      case 'checkbox':
        return VerificationMethod.checkbox;
      default:
        return VerificationMethod.otp;
    }
  }
}

class ProofOfDeliveryModel {
  final String proofId;
  final String deliveryId;
  final String orderId;
  final String? otpHash; // Hashed OTP for security
  final DateTime? otpGeneratedAt;
  final DateTime? otpVerifiedAt;
  final int otpAttempts; // Track failed attempts
  final String? photoBeforeUrl;
  final String? photoAfterUrl;
  final String? signatureUrl;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final VerificationMethod verificationMethod;
  final DateTime timestamp;
  final bool isVerified;
  final String? agentSignature; // Agent's sign-off

  ProofOfDeliveryModel({
    required this.proofId,
    required this.deliveryId,
    required this.orderId,
    this.otpHash,
    this.otpGeneratedAt,
    this.otpVerifiedAt,
    this.otpAttempts = 0,
    this.photoBeforeUrl,
    this.photoAfterUrl,
    this.signatureUrl,
    this.deliveryLatitude,
    this.deliveryLongitude,
    required this.verificationMethod,
    required this.timestamp,
    this.isVerified = false,
    this.agentSignature,
  });

  LatLng? get deliveryLatLng {
    if (deliveryLatitude != null && deliveryLongitude != null) {
      return LatLng(deliveryLatitude!, deliveryLongitude!);
    }
    return null;
  }

  bool get isOtpVerified => otpVerifiedAt != null;
  bool get hasPhotos => photoBeforeUrl != null || photoAfterUrl != null;
  bool get hasSignature => signatureUrl != null;

  Map<String, dynamic> toJson() {
    return {
      'proofId': proofId,
      'deliveryId': deliveryId,
      'orderId': orderId,
      'otpHash': otpHash,
      'otpGeneratedAt': otpGeneratedAt?.toIso8601String(),
      'otpVerifiedAt': otpVerifiedAt?.toIso8601String(),
      'otpAttempts': otpAttempts,
      'photoBeforeUrl': photoBeforeUrl,
      'photoAfterUrl': photoAfterUrl,
      'signatureUrl': signatureUrl,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'verificationMethod': verificationMethod.value,
      'timestamp': timestamp.toIso8601String(),
      'isVerified': isVerified,
      'agentSignature': agentSignature,
    };
  }

  factory ProofOfDeliveryModel.fromJson(Map<String, dynamic> json) {
    return ProofOfDeliveryModel(
      proofId: json['proofId'] as String,
      deliveryId: json['deliveryId'] as String,
      orderId: json['orderId'] as String,
      otpHash: json['otpHash'] as String?,
      otpGeneratedAt: json['otpGeneratedAt'] != null
          ? DateTime.parse(json['otpGeneratedAt'] as String)
          : null,
      otpVerifiedAt: json['otpVerifiedAt'] != null
          ? DateTime.parse(json['otpVerifiedAt'] as String)
          : null,
      otpAttempts: json['otpAttempts'] as int? ?? 0,
      photoBeforeUrl: json['photoBeforeUrl'] as String?,
      photoAfterUrl: json['photoAfterUrl'] as String?,
      signatureUrl: json['signatureUrl'] as String?,
      deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: (json['deliveryLongitude'] as num?)?.toDouble(),
      verificationMethod: VerificationMethodExtension.fromString(
        json['verificationMethod'] as String,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isVerified: json['isVerified'] as bool? ?? false,
      agentSignature: json['agentSignature'] as String?,
    );
  }

  factory ProofOfDeliveryModel.fromMap(Map<String, dynamic> map) {
    return ProofOfDeliveryModel.fromJson(map);
  }

  ProofOfDeliveryModel copyWith({
    String? proofId,
    String? deliveryId,
    String? orderId,
    String? otpHash,
    DateTime? otpGeneratedAt,
    DateTime? otpVerifiedAt,
    int? otpAttempts,
    String? photoBeforeUrl,
    String? photoAfterUrl,
    String? signatureUrl,
    double? deliveryLatitude,
    double? deliveryLongitude,
    VerificationMethod? verificationMethod,
    DateTime? timestamp,
    bool? isVerified,
    String? agentSignature,
  }) {
    return ProofOfDeliveryModel(
      proofId: proofId ?? this.proofId,
      deliveryId: deliveryId ?? this.deliveryId,
      orderId: orderId ?? this.orderId,
      otpHash: otpHash ?? this.otpHash,
      otpGeneratedAt: otpGeneratedAt ?? this.otpGeneratedAt,
      otpVerifiedAt: otpVerifiedAt ?? this.otpVerifiedAt,
      otpAttempts: otpAttempts ?? this.otpAttempts,
      photoBeforeUrl: photoBeforeUrl ?? this.photoBeforeUrl,
      photoAfterUrl: photoAfterUrl ?? this.photoAfterUrl,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      verificationMethod: verificationMethod ?? this.verificationMethod,
      timestamp: timestamp ?? this.timestamp,
      isVerified: isVerified ?? this.isVerified,
      agentSignature: agentSignature ?? this.agentSignature,
    );
  }

  @override
  String toString() =>
      'ProofOfDeliveryModel(proofId: $proofId, deliveryId: $deliveryId, isVerified: $isVerified)';
}
