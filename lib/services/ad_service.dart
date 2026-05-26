import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class AdService {
  static String get bannerAdUnitId {
    if (kReleaseMode) {
      return 'ca-app-pub-6854648050465232/6247814346';
    } else {
      // Test Banner ID
      return 'ca-app-pub-3940256099942544/6300978111';
    }
  }

  static BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => debugPrint('Ad loaded.'),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Ad failed to load: $error');
        },
      ),
    );
  }
}
