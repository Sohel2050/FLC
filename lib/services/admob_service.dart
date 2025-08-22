import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../providers/admob_provider.dart';

class AdMobService {
  /// Get banner ad unit ID from AdMobProvider
  static String? getBannerAdUnitId(BuildContext context) {
    final adMobProvider = Provider.of<AdMobProvider>(context, listen: false);
    return adMobProvider.bannerAdUnitId;
  }

  /// Get interstitial ad unit ID from AdMobProvider
  static String? getInterstitialAdUnitId(BuildContext context) {
    final adMobProvider = Provider.of<AdMobProvider>(context, listen: false);
    return adMobProvider.interstitialAdUnitId;
  }

  /// Get rewarded ad unit ID from AdMobProvider
  static String? getRewardedAdUnitId(BuildContext context) {
    final adMobProvider = Provider.of<AdMobProvider>(context, listen: false);
    return adMobProvider.rewardedAdUnitId;
  }

  /// Get native ad unit ID from AdMobProvider
  static String? getNativeAdUnitId(BuildContext context) {
    final adMobProvider = Provider.of<AdMobProvider>(context, listen: false);
    return adMobProvider.nativeAdUnitId;
  }

  /// Check if ads should be shown based on provider configuration and user preferences
  static bool shouldShowAds(BuildContext context, bool? userRemoveAds) {
    final adMobProvider = Provider.of<AdMobProvider>(context, listen: false);
    return adMobProvider.shouldShowAds(userRemoveAds);
  }

  /// Backward compatibility - Legacy getters (deprecated)
  // @deprecated
  // static String? get bannerAdUnitId {
  //   if (Platform.isAndroid) {
  //     return 'ca-app-pub-3940256099942544/6300978111';
  //   } else if (Platform.isIOS) {
  //     return 'ca-app-pub-3940256099942544/2934735716';
  //   } else {
  //     return null;
  //   }
  // }

  // @deprecated
  // static String? get interstitialAdUnitId {
  //   if (Platform.isAndroid) {
  //     return 'ca-app-pub-3940256099942544/1033173712';
  //   } else if (Platform.isIOS) {
  //     return 'ca-app-pub-3940256099942544/4411468910';
  //   } else {
  //     return null;
  //   }
  // }

  // @deprecated
  // static String? get rewardedAdUnitId {
  //   if (Platform.isAndroid) {
  //     return 'ca-app-pub-3940256099942544/5224354917';
  //   } else if (Platform.isIOS) {
  //     return 'ca-app-pub-3940256099942544/1712485313';
  //   } else {
  //     return null;
  //   }
  // }

  // @deprecated
  // static String? get nativeAdUnitId {
  //   if (Platform.isAndroid) {
  //     return 'ca-app-pub-3940256099942544/2247696110';
  //   } else if (Platform.isIOS) {
  //     return 'ca-app-pub-3940256099942544/3986624511';
  //   } else {
  //     return null;
  //   }
  // }

  static final BannerAdListener bannerAdListener = BannerAdListener(
    onAdLoaded: (Ad ad) => print('Ad loaded.'),
    onAdFailedToLoad: (Ad ad, LoadAdError error) {
      ad.dispose();
      print('Ad failed to load: $error');
    },
    onAdOpened: (Ad ad) => print('Ad opened.'),
    onAdClosed: (Ad ad) {
      ad.dispose();
      print('Ad closed.');
    },
    onAdImpression: (Ad ad) => print('Ad impression.'),
  );
}
