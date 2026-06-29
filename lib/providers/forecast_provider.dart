import 'package:flutter/foundation.dart';
import '../services/forecast_service.dart';

class ForecastProvider with ChangeNotifier {
  final ForecastService _forecastService = ForecastService();

  double _predictedRevenue7Days = 0.0;
  double _predictedRevenue30Days = 0.0;
  int _predictedOrders7Days = 0;
  int _predictedOrders30Days = 0;
  Map<String, double> _demandForecasts = {};
  String _forecastNarrative = '';
  bool _isLoading = false;
  String? _errorMessage;

  double get predictedRevenue7Days => _predictedRevenue7Days;
  double get predictedRevenue30Days => _predictedRevenue30Days;
  int get predictedOrders7Days => _predictedOrders7Days;
  int get predictedOrders30Days => _predictedOrders30Days;
  Map<String, double> get demandForecasts => _demandForecasts;
  String get forecastNarrative => _forecastNarrative;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Compiles mathematical forecasts and requests Bedrock narratives
  Future<void> compileForecasts({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Calculate Holt Smoothing Demand Forecasts
      _demandForecasts = await _forecastService.generateDemandForecast(forecastDays: 7);
      
      // 2. Calculate 7d and 30d Revenue Forecasts
      _predictedRevenue7Days = await _forecastService.generateRevenueForecast(forecastDays: 7);
      _predictedRevenue30Days = await _forecastService.generateRevenueForecast(forecastDays: 30);

      // Estimate order counts based on average order size
      _predictedOrders7Days = (_predictedRevenue7Days / 450).round();
      _predictedOrders30Days = (_predictedRevenue30Days / 450).round();

      // 3. Request narrative reasoning explanation from Bedrock
      _forecastNarrative = await _forecastService.generateExplainableForecastBriefing(
        _predictedRevenue7Days,
        7,
      );
    } catch (e) {
      _errorMessage = 'Failed to generate forecasts: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
