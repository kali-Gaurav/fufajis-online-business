import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class VendorService {
  static final VendorService _instance = VendorService._internal();

  factory VendorService() {
    return _instance;
  }

  VendorService._internal();

  final _supabase = Supabase.instance;

  // ============================================================================
  // VENDOR CRUD OPERATIONS
  // ============================================================================

  Future<String> createVendor({
    required String name,
    required String email,
    required String businessName,
    required String businessType,
    String? phone,
    String? description,
    Map<String, dynamic>? address,
    Map<String, dynamic>? bankDetails,
  }) async {
    try {
      final response = await _supabase.client
          .from('vendors')
          .insert({
            'name': name,
            'email': email,
            'phone': phone,
            'description': description,
            'business_name': businessName,
            'business_type': businessType,
            'address': address,
            'bank_account_holder_name': bankDetails?['accountHolderName'],
            'bank_account_number': bankDetails?['accountNumber'],
            'bank_ifsc_code': bankDetails?['ifscCode'],
            'upi_id': bankDetails?['upiId'],
            'status': 'pending',
          })
          .select('id')
          .single();

      debugPrint('Vendor created: ${response['id']}');
      return response['id'];
    } catch (e) {
      debugPrint('Error creating vendor: $e');
      rethrow;
    }
  }

  Future<Vendor?> getVendor(String vendorId) async {
    try {
      final response = await _supabase.client
          .from('vendors')
          .select()
          .eq('id', vendorId)
          .single();

      return Vendor.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching vendor: $e');
      return null;
    }
  }

  Future<Vendor?> getMyVendorProfile() async {
    try {
      final userId = _supabase.client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase.client
          .from('vendors')
          .select()
          .eq('id', userId)
          .single();

      return Vendor.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching my vendor profile: $e');
      return null;
    }
  }

  Future<void> updateVendor(
    String vendorId, {
    String? name,
    String? email,
    String? description,
    String? logoUrl,
    String? bannerUrl,
    double? commissionPercentage,
    Map<String, dynamic>? address,
    Map<String, dynamic>? bankDetails,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (email != null) updates['email'] = email;
      if (description != null) updates['description'] = description;
      if (logoUrl != null) updates['logo_url'] = logoUrl;
      if (bannerUrl != null) updates['banner_url'] = bannerUrl;
      if (commissionPercentage != null) updates['commission_percentage'] = commissionPercentage;
      if (address != null) updates['address'] = address;
      if (bankDetails != null) {
        updates['bank_account_holder_name'] = bankDetails['accountHolderName'];
        updates['bank_account_number'] = bankDetails['accountNumber'];
        updates['bank_ifsc_code'] = bankDetails['ifscCode'];
        updates['upi_id'] = bankDetails['upiId'];
      }
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _supabase.client.from('vendors').update(updates).eq('id', vendorId);

      debugPrint('Vendor updated: $vendorId');
    } catch (e) {
      debugPrint('Error updating vendor: $e');
      rethrow;
    }
  }

  Future<void> approveVendor(String vendorId) async {
    try {
      await _supabase.client.from('vendors').update({
        'status': 'approved',
        'verification_status': 'verified',
        'verification_date': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', vendorId);

      debugPrint('Vendor approved: $vendorId');
    } catch (e) {
      debugPrint('Error approving vendor: $e');
      rethrow;
    }
  }

  Future<void> rejectVendor(String vendorId, String reason) async {
    try {
      await _supabase.client.from('vendors').update({
        'status': 'rejected',
        'verification_status': 'rejected',
        'rejection_reason': reason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', vendorId);

      debugPrint('Vendor rejected: $vendorId');
    } catch (e) {
      debugPrint('Error rejecting vendor: $e');
      rethrow;
    }
  }

  Future<void> suspendVendor(String vendorId, String reason, [int? suspendDays]) async {
    try {
      DateTime? suspendedUntil;
      if (suspendDays != null) {
        suspendedUntil = DateTime.now().add(Duration(days: suspendDays));
      }

      await _supabase.client.from('vendors').update({
        'status': 'suspended',
        'suspension_reason': reason,
        'suspended_until': suspendedUntil?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', vendorId);

      debugPrint('Vendor suspended: $vendorId');
    } catch (e) {
      debugPrint('Error suspending vendor: $e');
      rethrow;
    }
  }

  Future<List<Vendor>> getApprovedVendors() async {
    try {
      final response = await _supabase.client
          .from('vendors')
          .select()
          .eq('status', 'approved')
          .order('rating', ascending: false);

      return (response as List).map((v) => Vendor.fromJson(v)).toList();
    } catch (e) {
      debugPrint('Error fetching approved vendors: $e');
      return [];
    }
  }

  Future<List<Vendor>> getPendingVendors() async {
    try {
      final response = await _supabase.client
          .from('vendors')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      return (response as List).map((v) => Vendor.fromJson(v)).toList();
    } catch (e) {
      debugPrint('Error fetching pending vendors: $e');
      return [];
    }
  }

  // ============================================================================
  // COMMISSION OPERATIONS
  // ============================================================================

  Future<String> createCommission({
    required String vendorId,
    required String orderId,
    required double orderTotal,
    required double commissionPercentage,
  }) async {
    try {
      final commissionAmount = orderTotal * (commissionPercentage / 100);
      final processingFee = commissionAmount * 0.05; // 5% processing fee
      final vendorNetAmount = commissionAmount - processingFee;

      final response = await _supabase.client
          .from('vendor_commissions')
          .insert({
            'vendor_id': vendorId,
            'order_id': orderId,
            'order_total': orderTotal,
            'vendor_commission_percentage': commissionPercentage,
            'commission_amount': commissionAmount,
            'processing_fee': processingFee,
            'vendor_net_amount': vendorNetAmount,
            'status': 'pending',
          })
          .select('id')
          .single();

      debugPrint('Commission created: ${response['id']}');
      return response['id'];
    } catch (e) {
      debugPrint('Error creating commission: $e');
      rethrow;
    }
  }

  Future<VendorCommission?> getCommission(String commissionId) async {
    try {
      final response = await _supabase.client
          .from('vendor_commissions')
          .select()
          .eq('id', commissionId)
          .single();

      return VendorCommission.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching commission: $e');
      return null;
    }
  }

  Future<List<VendorCommission>> getVendorCommissions(
    String vendorId, {
    String? status,
    int limit = 50,
  }) async {
    try {
      var query = _supabase.client
          .from('vendor_commissions')
          .select()
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false)
          .limit(limit);

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query;
      return (response as List).map((c) => VendorCommission.fromJson(c)).toList();
    } catch (e) {
      debugPrint('Error fetching vendor commissions: $e');
      return [];
    }
  }

  Future<double> getTotalPendingCommission(String vendorId) async {
    try {
      final response = await _supabase.client
          .from('vendor_commissions')
          .select('vendor_net_amount')
          .eq('vendor_id', vendorId)
          .eq('status', 'pending');

      return (response as List)
          .fold<double>(0, (sum, item) => sum + (item['vendor_net_amount'] as num).toDouble());
    } catch (e) {
      debugPrint('Error calculating pending commission: $e');
      return 0.0;
    }
  }

  // ============================================================================
  // PAYOUT OPERATIONS
  // ============================================================================

  Future<String> requestPayout({
    required String vendorId,
    required double totalAmount,
    required int commissionCount,
    String payoutMethod = 'bank',
  }) async {
    try {
      final response = await _supabase.client
          .from('vendor_payouts')
          .insert({
            'vendor_id': vendorId,
            'total_amount': totalAmount,
            'commission_count': commissionCount,
            'payout_method': payoutMethod,
            'status': 'pending',
            'requested_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      debugPrint('Payout requested: ${response['id']}');
      return response['id'];
    } catch (e) {
      debugPrint('Error requesting payout: $e');
      rethrow;
    }
  }

  Future<VendorPayout?> getPayout(String payoutId) async {
    try {
      final response = await _supabase.client
          .from('vendor_payouts')
          .select()
          .eq('id', payoutId)
          .single();

      return VendorPayout.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching payout: $e');
      return null;
    }
  }

  Future<List<VendorPayout>> getVendorPayouts(String vendorId, {int limit = 50}) async {
    try {
      final response = await _supabase.client
          .from('vendor_payouts')
          .select()
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).map((p) => VendorPayout.fromJson(p)).toList();
    } catch (e) {
      debugPrint('Error fetching vendor payouts: $e');
      return [];
    }
  }

  Future<void> updatePayoutStatus(
    String payoutId,
    String status, {
    String? razorpayPayoutId,
    String? razorpaySettlementId,
    String? failureReason,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (razorpayPayoutId != null) updates['razorpay_payout_id'] = razorpayPayoutId;
      if (razorpaySettlementId != null) updates['razorpay_settlement_id'] = razorpaySettlementId;
      if (failureReason != null) updates['failure_reason'] = failureReason;

      if (status == 'completed') {
        updates['processed_at'] = DateTime.now().toIso8601String();
      } else if (status == 'failed') {
        updates['failed_at'] = DateTime.now().toIso8601String();
      }

      await _supabase.client.from('vendor_payouts').update(updates).eq('id', payoutId);

      debugPrint('Payout status updated: $payoutId -> $status');
    } catch (e) {
      debugPrint('Error updating payout status: $e');
      rethrow;
    }
  }

  // ============================================================================
  // ANALYTICS OPERATIONS
  // ============================================================================

  Future<VendorAnalytics?> getVendorAnalytics(String vendorId) async {
    try {
      final response = await _supabase.client
          .from('vendor_analytics')
          .select()
          .eq('vendor_id', vendorId)
          .single();

      return VendorAnalytics.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching vendor analytics: $e');
      return null;
    }
  }

  Future<void> updateVendorAnalytics(
    String vendorId, {
    double? totalSalesThisMonth,
    int? totalOrdersThisMonth,
    double? onTimeDeliveryRate,
    double? returnRate,
    double? cancellationRate,
    double? customerSatisfactionScore,
    int? vendorHealthScore,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (totalSalesThisMonth != null) updates['total_sales_this_month'] = totalSalesThisMonth;
      if (totalOrdersThisMonth != null) updates['total_orders_this_month'] = totalOrdersThisMonth;
      if (onTimeDeliveryRate != null) updates['on_time_delivery_rate'] = onTimeDeliveryRate;
      if (returnRate != null) updates['return_rate'] = returnRate;
      if (cancellationRate != null) updates['cancellation_rate'] = cancellationRate;
      if (customerSatisfactionScore != null) {
        updates['customer_satisfaction_score'] = customerSatisfactionScore;
      }
      if (vendorHealthScore != null) updates['vendor_health_score'] = vendorHealthScore;
      updates['calculated_at'] = DateTime.now().toIso8601String();

      await _supabase.client
          .from('vendor_analytics')
          .update(updates)
          .eq('vendor_id', vendorId);

      debugPrint('Vendor analytics updated: $vendorId');
    } catch (e) {
      debugPrint('Error updating vendor analytics: $e');
      rethrow;
    }
  }

  // ============================================================================
  // DISPUTE OPERATIONS
  // ============================================================================

  Future<String> createDispute({
    required String vendorId,
    required String disputeType,
    required String subject,
    required String description,
    String? orderId,
    String? commissionId,
    List<String>? attachmentUrls,
  }) async {
    try {
      final response = await _supabase.client
          .from('vendor_disputes')
          .insert({
            'vendor_id': vendorId,
            'order_id': orderId,
            'commission_id': commissionId,
            'dispute_type': disputeType,
            'subject': subject,
            'description': description,
            'status': 'open',
            'attachments': attachmentUrls != null
                ? attachmentUrls.map((url) => {'url': url, 'uploaded_at': DateTime.now().toIso8601String()}).toList()
                : null,
          })
          .select('id')
          .single();

      debugPrint('Dispute created: ${response['id']}');
      return response['id'];
    } catch (e) {
      debugPrint('Error creating dispute: $e');
      rethrow;
    }
  }

  Future<VendorDispute?> getDispute(String disputeId) async {
    try {
      final response = await _supabase.client
          .from('vendor_disputes')
          .select()
          .eq('id', disputeId)
          .single();

      return VendorDispute.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching dispute: $e');
      return null;
    }
  }

  Future<List<VendorDispute>> getVendorDisputes(String vendorId, {String? status}) async {
    try {
      var query = _supabase.client
          .from('vendor_disputes')
          .select()
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false);

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query;
      return (response as List).map((d) => VendorDispute.fromJson(d)).toList();
    } catch (e) {
      debugPrint('Error fetching vendor disputes: $e');
      return [];
    }
  }

  Future<void> resolveDispute(String disputeId, String resolution) async {
    try {
      await _supabase.client.from('vendor_disputes').update({
        'status': 'resolved',
        'resolution': resolution,
        'resolution_date': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', disputeId);

      debugPrint('Dispute resolved: $disputeId');
    } catch (e) {
      debugPrint('Error resolving dispute: $e');
      rethrow;
    }
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

class Vendor {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final String businessName;
  final String? businessType;
  final String? businessRegistrationNumber;
  final String? taxId;
  final String? gstin;
  final Map<String, dynamic>? address;
  final Map<String, dynamic>? billingAddress;
  final String? bankAccountHolderName;
  final String? bankAccountNumber;
  final String? bankIfscCode;
  final String? upiId;
  final double rating;
  final int totalReviews;
  final int totalOrders;
  final double? responseTimeHours;
  final double returnRate;
  final String status;
  final String verificationStatus;
  final String documentVerificationStatus;
  final DateTime? verificationDate;
  final String? rejectionReason;
  final String? suspensionReason;
  final DateTime? suspendedUntil;
  final double commissionPercentage;
  final double monthlyFee;
  final double processingFeePercentage;
  final double totalCommissionEarned;
  final double totalCommissionPaid;
  final double balance;
  final int totalProducts;
  final DateTime createdAt;
  final DateTime updatedAt;

  Vendor({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    required this.businessName,
    this.businessType,
    this.businessRegistrationNumber,
    this.taxId,
    this.gstin,
    this.address,
    this.billingAddress,
    this.bankAccountHolderName,
    this.bankAccountNumber,
    this.bankIfscCode,
    this.upiId,
    required this.rating,
    required this.totalReviews,
    required this.totalOrders,
    this.responseTimeHours,
    required this.returnRate,
    required this.status,
    required this.verificationStatus,
    required this.documentVerificationStatus,
    this.verificationDate,
    this.rejectionReason,
    this.suspensionReason,
    this.suspendedUntil,
    required this.commissionPercentage,
    required this.monthlyFee,
    required this.processingFeePercentage,
    required this.totalCommissionEarned,
    required this.totalCommissionPaid,
    required this.balance,
    required this.totalProducts,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      description: json['description'],
      logoUrl: json['logo_url'],
      bannerUrl: json['banner_url'],
      businessName: json['business_name'] ?? '',
      businessType: json['business_type'],
      businessRegistrationNumber: json['business_registration_number'],
      taxId: json['tax_id'],
      gstin: json['gstin'],
      address: json['address'],
      billingAddress: json['billing_address'],
      bankAccountHolderName: json['bank_account_holder_name'],
      bankAccountNumber: json['bank_account_number'],
      bankIfscCode: json['bank_ifsc_code'],
      upiId: json['upi_id'],
      rating: (json['rating'] ?? 0.0).toDouble(),
      totalReviews: json['total_reviews'] ?? 0,
      totalOrders: json['total_orders'] ?? 0,
      responseTimeHours: json['response_time_hours'] != null ? (json['response_time_hours'] as num).toDouble() : null,
      returnRate: (json['return_rate'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'pending',
      verificationStatus: json['verification_status'] ?? 'unverified',
      documentVerificationStatus: json['document_verification_status'] ?? 'pending',
      verificationDate: json['verification_date'] != null ? DateTime.parse(json['verification_date']) : null,
      rejectionReason: json['rejection_reason'],
      suspensionReason: json['suspension_reason'],
      suspendedUntil: json['suspended_until'] != null ? DateTime.parse(json['suspended_until']) : null,
      commissionPercentage: (json['commission_percentage'] ?? 0.0).toDouble(),
      monthlyFee: (json['monthly_fee'] ?? 0.0).toDouble(),
      processingFeePercentage: (json['processing_fee_percentage'] ?? 0.0).toDouble(),
      totalCommissionEarned: (json['total_commission_earned'] ?? 0.0).toDouble(),
      totalCommissionPaid: (json['total_commission_paid'] ?? 0.0).toDouble(),
      balance: (json['balance'] ?? 0.0).toDouble(),
      totalProducts: json['total_products'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'description': description,
      'logo_url': logoUrl,
      'banner_url': bannerUrl,
      'business_name': businessName,
      'business_type': businessType,
      'business_registration_number': businessRegistrationNumber,
      'tax_id': taxId,
      'gstin': gstin,
      'address': address,
      'billing_address': billingAddress,
      'bank_account_holder_name': bankAccountHolderName,
      'bank_account_number': bankAccountNumber,
      'bank_ifsc_code': bankIfscCode,
      'upi_id': upiId,
      'rating': rating,
      'total_reviews': totalReviews,
      'total_orders': totalOrders,
      'response_time_hours': responseTimeHours,
      'return_rate': returnRate,
      'status': status,
      'verification_status': verificationStatus,
      'document_verification_status': documentVerificationStatus,
      'verification_date': verificationDate?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'suspension_reason': suspensionReason,
      'suspended_until': suspendedUntil?.toIso8601String(),
      'commission_percentage': commissionPercentage,
      'monthly_fee': monthlyFee,
      'processing_fee_percentage': processingFeePercentage,
      'total_commission_earned': totalCommissionEarned,
      'total_commission_paid': totalCommissionPaid,
      'balance': balance,
      'total_products': totalProducts,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class VendorCommission {
  final String id;
  final String vendorId;
  final String orderId;
  final double orderTotal;
  final double vendorCommissionPercentage;
  final double commissionAmount;
  final double processingFee;
  final double vendorNetAmount;
  final String status;
  final DateTime? paidAt;
  final String? payoutId;
  final DateTime createdAt;
  final DateTime updatedAt;

  VendorCommission({
    required this.id,
    required this.vendorId,
    required this.orderId,
    required this.orderTotal,
    required this.vendorCommissionPercentage,
    required this.commissionAmount,
    required this.processingFee,
    required this.vendorNetAmount,
    required this.status,
    this.paidAt,
    this.payoutId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorCommission.fromJson(Map<String, dynamic> json) {
    return VendorCommission(
      id: json['id'] ?? '',
      vendorId: json['vendor_id'] ?? '',
      orderId: json['order_id'] ?? '',
      orderTotal: (json['order_total'] ?? 0.0).toDouble(),
      vendorCommissionPercentage: (json['vendor_commission_percentage'] ?? 0.0).toDouble(),
      commissionAmount: (json['commission_amount'] ?? 0.0).toDouble(),
      processingFee: (json['processing_fee'] ?? 0.0).toDouble(),
      vendorNetAmount: (json['vendor_net_amount'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'pending',
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      payoutId: json['payout_id'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class VendorPayout {
  final String id;
  final String vendorId;
  final double totalAmount;
  final int commissionCount;
  final String status;
  final String payoutMethod;
  final String? razorpayPayoutId;
  final String? razorpaySettlementId;
  final String? failureReason;
  final DateTime? requestedAt;
  final DateTime? processedAt;
  final DateTime? failedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  VendorPayout({
    required this.id,
    required this.vendorId,
    required this.totalAmount,
    required this.commissionCount,
    required this.status,
    required this.payoutMethod,
    this.razorpayPayoutId,
    this.razorpaySettlementId,
    this.failureReason,
    this.requestedAt,
    this.processedAt,
    this.failedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorPayout.fromJson(Map<String, dynamic> json) {
    return VendorPayout(
      id: json['id'] ?? '',
      vendorId: json['vendor_id'] ?? '',
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
      commissionCount: json['commission_count'] ?? 0,
      status: json['status'] ?? 'pending',
      payoutMethod: json['payout_method'] ?? 'bank',
      razorpayPayoutId: json['razorpay_payout_id'],
      razorpaySettlementId: json['razorpay_settlement_id'],
      failureReason: json['failure_reason'],
      requestedAt: json['requested_at'] != null ? DateTime.parse(json['requested_at']) : null,
      processedAt: json['processed_at'] != null ? DateTime.parse(json['processed_at']) : null,
      failedAt: json['failed_at'] != null ? DateTime.parse(json['failed_at']) : null,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class VendorAnalytics {
  final String id;
  final String vendorId;
  final double totalSales;
  final double totalSalesThisMonth;
  final int totalOrdersThisMonth;
  final double avgOrderValue;
  final double salesTrendPercentage;
  final double onTimeDeliveryRate;
  final double returnRate;
  final double cancellationRate;
  final double customerSatisfactionScore;
  final double responseTimeHours;
  final double totalCommissionThisMonth;
  final double pendingPayoutAmount;
  final int payoutFrequencyDays;
  final int vendorHealthScore;
  final DateTime? calculatedAt;
  final DateTime createdAt;

  VendorAnalytics({
    required this.id,
    required this.vendorId,
    required this.totalSales,
    required this.totalSalesThisMonth,
    required this.totalOrdersThisMonth,
    required this.avgOrderValue,
    required this.salesTrendPercentage,
    required this.onTimeDeliveryRate,
    required this.returnRate,
    required this.cancellationRate,
    required this.customerSatisfactionScore,
    required this.responseTimeHours,
    required this.totalCommissionThisMonth,
    required this.pendingPayoutAmount,
    required this.payoutFrequencyDays,
    required this.vendorHealthScore,
    this.calculatedAt,
    required this.createdAt,
  });

  factory VendorAnalytics.fromJson(Map<String, dynamic> json) {
    return VendorAnalytics(
      id: json['id'] ?? '',
      vendorId: json['vendor_id'] ?? '',
      totalSales: (json['total_sales'] ?? 0.0).toDouble(),
      totalSalesThisMonth: (json['total_sales_this_month'] ?? 0.0).toDouble(),
      totalOrdersThisMonth: json['total_orders_this_month'] ?? 0,
      avgOrderValue: (json['avg_order_value'] ?? 0.0).toDouble(),
      salesTrendPercentage: (json['sales_trend_percentage'] ?? 0.0).toDouble(),
      onTimeDeliveryRate: (json['on_time_delivery_rate'] ?? 0.0).toDouble(),
      returnRate: (json['return_rate'] ?? 0.0).toDouble(),
      cancellationRate: (json['cancellation_rate'] ?? 0.0).toDouble(),
      customerSatisfactionScore: (json['customer_satisfaction_score'] ?? 0.0).toDouble(),
      responseTimeHours: (json['response_time_hours'] ?? 0.0).toDouble(),
      totalCommissionThisMonth: (json['total_commission_this_month'] ?? 0.0).toDouble(),
      pendingPayoutAmount: (json['pending_payout_amount'] ?? 0.0).toDouble(),
      payoutFrequencyDays: json['payout_frequency_days'] ?? 30,
      vendorHealthScore: json['vendor_health_score'] ?? 0,
      calculatedAt: json['calculated_at'] != null ? DateTime.parse(json['calculated_at']) : null,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class VendorDispute {
  final String id;
  final String vendorId;
  final String? orderId;
  final String? commissionId;
  final String disputeType;
  final String subject;
  final String description;
  final String status;
  final String? resolution;
  final List<dynamic>? attachments;
  final Map<String, dynamic>? evidenceFromVendor;
  final Map<String, dynamic>? evidenceFromAdmin;
  final DateTime? resolutionDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  VendorDispute({
    required this.id,
    required this.vendorId,
    this.orderId,
    this.commissionId,
    required this.disputeType,
    required this.subject,
    required this.description,
    required this.status,
    this.resolution,
    this.attachments,
    this.evidenceFromVendor,
    this.evidenceFromAdmin,
    this.resolutionDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorDispute.fromJson(Map<String, dynamic> json) {
    return VendorDispute(
      id: json['id'] ?? '',
      vendorId: json['vendor_id'] ?? '',
      orderId: json['order_id'],
      commissionId: json['commission_id'],
      disputeType: json['dispute_type'] ?? '',
      subject: json['subject'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'open',
      resolution: json['resolution'],
      attachments: json['attachments'],
      evidenceFromVendor: json['evidence_from_vendor'],
      evidenceFromAdmin: json['evidence_from_admin'],
      resolutionDate: json['resolution_date'] != null ? DateTime.parse(json['resolution_date']) : null,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}
