import 'package:flutter/foundation.dart';
import '../services/customer_retention_service.dart';

class RetentionProvider extends ChangeNotifier {
  final CustomerRetentionService _retentionService = CustomerRetentionService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<Map<String, dynamic>> _atRiskCustomers = [];
  List<Map<String, dynamic>> get atRiskCustomers => _atRiskCustomers;

  Map<String, dynamic> _recoveryStats = {
    'totalIncentivized': 0,
    'successfullyRecovered': 0,
    'recoveryRate': 0.0,
    'recoveredRevenue': 0.0,
  };
  Map<String, dynamic> get recoveryStats => _recoveryStats;

  Future<void> loadRetentionData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Find customers who haven't ordered in 14 days
      _atRiskCustomers = await _retentionService.getAtRiskCustomers(14);
      _recoveryStats = await _retentionService.calculateRecoveryStats();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendIncentiveToCustomer({
    required String userId,
    required double amount,
    required String message,
    required String adminId,
    required String adminName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _retentionService.sendReactivationIncentive(
        userId: userId,
        amount: amount,
        message: message,
        adminId: adminId,
        adminName: adminName,
      );
      
      // Refresh the lists to show updated stats/users
      await loadRetentionData();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
