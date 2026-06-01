import 'shop_config_service.dart';

@deprecated
class ShopService {
  final ShopConfigService _configService = ShopConfigService();

  static final ShopService _instance = ShopService._internal();
  factory ShopService() => _instance;
  ShopService._internal();

  Future<bool> getShopStatus() async {
    final config = await _configService.getShopConfig();
    return config.isOpen;
  }

  Future<void> updateShopStatus(bool isOpen) async {
    final config = await _configService.getShopConfig();
    await _configService.updateShopConfig(config.copyWith(isOpen: isOpen));
  }

  Stream<bool> getShopStatusStream() {
    return _configService.getShopConfigStream().map((config) => config.isOpen);
  }
}
