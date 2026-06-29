import 'package:flutter/material.dart';
import '../models/delivery_task_model.dart';
import '../models/proof_of_delivery_model.dart';
import '../models/delivery_location_model.dart';
import '../services/delivery_last_mile_service.dart';
import '../services/location_tracking_service.dart';

class DeliveryLastMileProvider extends ChangeNotifier {
  final DeliveryLastMileService _deliveryService = DeliveryLastMileService();
  final LocationTrackingService _locationService = LocationTrackingService();

  // State
  List<DeliveryTaskModel> assignedDeliveries = [];
  DeliveryTaskModel? currentDelivery;
  DeliveryLocationModel? currentLocation;
  ProofOfDeliveryModel? currentProofOfDelivery;

  bool otpVerified = false;
  int otpAttemptsRemaining = 3;

  List<DeliveryLocationModel> locationHistory = [];
  Map<String, dynamic> todayStats = {};

  bool isLoadingLocation = false;
  bool isLoading = false;
  String? error;

  // Real-time listeners
  Function(DeliveryTaskModel?)? onDeliveryUpdate;
  Function(DeliveryLocationModel?)? onLocationUpdate;

  /// Load all assigned deliveries for an agent
  Future<void> loadAssignedDeliveries(String deliveryAgentId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      assignedDeliveries = await _deliveryService.getAssignedDeliveries(deliveryAgentId);
      notifyListeners();
    } catch (e) {
      error = 'Failed to load deliveries: $e';
      debugPrint(error);
      notifyListeners();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Select a delivery to work on
  Future<void> selectDelivery(String deliveryId) async {
    try {
      currentDelivery = await _deliveryService.getDeliveryDetail(deliveryId);
      locationHistory = await _deliveryService.getLocationHistory(deliveryId);
      notifyListeners();
    } catch (e) {
      error = 'Failed to load delivery detail: $e';
      debugPrint(error);
      notifyListeners();
    }
  }

  /// Start delivery and begin location tracking
  Future<void> startDelivery(String deliveryId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _deliveryService.startDelivery(deliveryId);
      currentDelivery = await _deliveryService.getDeliveryDetail(deliveryId);
      notifyListeners();
    } catch (e) {
      error = 'Failed to start delivery: $e';
      debugPrint(error);
      notifyListeners();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Update delivery location
  Future<void> updateLocation(double lat, double lng) async {
    if (currentDelivery == null) return;

    isLoadingLocation = true;
    try {
      await _deliveryService.updateLocation(currentDelivery!.deliveryId, lat, lng);

      currentLocation = DeliveryLocationModel(
        locationId: 'current',
        deliveryId: currentDelivery!.deliveryId,
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
      );

      onLocationUpdate?.call(currentLocation);
      notifyListeners();
    } catch (e) {
      error = 'Failed to update location: $e';
      debugPrint(error);
    } finally {
      isLoadingLocation = false;
      notifyListeners();
    }
  }

  /// Generate OTP for verification
  Future<String?> generateOTP(String deliveryId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final otp = await _deliveryService.generateOTP(deliveryId);
      otpAttemptsRemaining = 3;
      notifyListeners();
      return otp;
    } catch (e) {
      error = 'Failed to generate OTP: $e';
      debugPrint(error);
      notifyListeners();
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Verify OTP entered by customer
  Future<bool> verifyOTP(String deliveryId, String userOtp) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final isValid = await _deliveryService.verifyOTP(deliveryId, userOtp);

      if (isValid) {
        otpVerified = true;
        notifyListeners();
        return true;
      } else {
        otpAttemptsRemaining--;
        if (otpAttemptsRemaining <= 0) {
          error = 'Too many failed attempts. Please try again later.';
        } else {
          error = 'Invalid OTP. $otpAttemptsRemaining attempts remaining.';
        }
        notifyListeners();
        return false;
      }
    } catch (e) {
      error = 'Error verifying OTP: $e';
      debugPrint(error);
      notifyListeners();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Upload proof photo
  Future<bool> uploadProofPhoto(String deliveryId, String imagePath) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      currentProofOfDelivery = await _deliveryService.uploadProofOfDelivery(
        deliveryId: deliveryId,
        photoPath: imagePath,
      );
      notifyListeners();
      return true;
    } catch (e) {
      error = 'Failed to upload photo: $e';
      debugPrint(error);
      notifyListeners();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Upload signature
  Future<bool> uploadSignature(String deliveryId, String signaturePath) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      currentProofOfDelivery = await _deliveryService.uploadProofOfDelivery(
        deliveryId: deliveryId,
        signaturePath: signaturePath,
      );
      notifyListeners();
      return true;
    } catch (e) {
      error = 'Failed to upload signature: $e';
      debugPrint(error);
      notifyListeners();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Complete delivery
  Future<bool> completeDelivery(
    String deliveryId,
    VerificationMethod verificationMethod,
  ) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _deliveryService.completeDelivery(
        deliveryId: deliveryId,
        verificationMethod: verificationMethod,
      );

      // Update state
      currentDelivery = currentDelivery?.copyWith(
        status: DeliveryTaskStatus.completed,
        completedAt: DateTime.now(),
      );

      notifyListeners();
      return true;
    } catch (e) {
      error = 'Failed to complete delivery: $e';
      debugPrint(error);
      notifyListeners();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Mark delivery as failed
  Future<bool> failDelivery(
    String deliveryId,
    String reason, {
    String? notes,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _deliveryService.failDelivery(
        deliveryId: deliveryId,
        reason: reason,
        notes: notes,
      );

      currentDelivery = currentDelivery?.copyWith(
        status: DeliveryTaskStatus.failed,
        failureReason: reason,
      );

      notifyListeners();
      return true;
    } catch (e) {
      error = 'Failed to mark delivery as failed: $e';
      debugPrint(error);
      notifyListeners();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Retry a failed delivery
  Future<bool> retryDelivery(
    String failedDeliveryId,
    String newDeliveryAgentId,
    DateTime estimatedArrival,
  ) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _deliveryService.retryDelivery(
        failedDeliveryId: failedDeliveryId,
        newDeliveryAgentId: newDeliveryAgentId,
        estimatedArrival: estimatedArrival,
      );

      notifyListeners();
      return true;
    } catch (e) {
      error = 'Failed to retry delivery: $e';
      debugPrint(error);
      notifyListeners();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Load delivery stats
  Future<void> loadTodayStats(String deliveryAgentId) async {
    try {
      todayStats = await _deliveryService.getDeliveryStats(deliveryAgentId, period: 'today');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  /// Clear current delivery
  void clearCurrentDelivery() {
    currentDelivery = null;
    currentLocation = null;
    currentProofOfDelivery = null;
    otpVerified = false;
    otpAttemptsRemaining = 3;
    locationHistory = [];
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _locationService.stopAllTracking();
    super.dispose();
  }
}
