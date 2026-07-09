import '../../../services/api_client.dart';

class CheckoutApi {
  final ApiClient _apiClient = ApiClient.instance;

  Future<Map<String, dynamic>> processCheckout(Map<String, dynamic> checkoutData) async {
    final response = await _apiClient.post('/api/v1/checkout/process', checkoutData);
    return response.data as Map<String, dynamic>;
  }
}
