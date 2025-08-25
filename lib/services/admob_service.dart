import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../providers/admob_provider.dart';

class AdMobService {
  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialAdReady = false;
  static RewardedAd? _rewardedAd;
  static bool _isRewardedAdReady = false;

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

  /// Get the current interstitial ad instance
  static InterstitialAd? get interstitialAd => _interstitialAd;

  /// Check if interstitial ad is ready to show
  static bool get isInterstitialAdReady => _isInterstitialAdReady;

  /// Get the current rewarded ad instance
  static RewardedAd? get rewardedAd => _rewardedAd;

  /// Check if rewarded ad is ready to show
  static bool get isRewardedAdReady => _isRewardedAdReady;

  /// Load interstitial ad without showing it immediately
  static Future<void> loadInterstitialAd(BuildContext context) async {
    final adUnitId = getInterstitialAdUnitId(context);
    if (adUnitId == null) {
      print('Interstitial ad unit ID is null');
      return;
    }

    // Dispose existing ad if any
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdReady = false;

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          print('Interstitial ad loaded and ready to show.');
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Interstitial ad failed to load: $error');
          _interstitialAd = null;
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  /// Show loaded interstitial ad
  static void showInterstitialAd({
    required VoidCallback onAdClosed,
    VoidCallback? onAdFailedToShow,
  }) {
    if (_interstitialAd == null || !_isInterstitialAdReady) {
      print('Interstitial ad is not ready to show');
      onAdFailedToShow?.call();
      return;
    }

    _interstitialAd!
        .fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        print('Interstitial ad showed full screen content.');
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('Interstitial ad dismissed full screen content.');
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdReady = false;
        onAdClosed();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('Interstitial ad failed to show full screen content: $error');
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdReady = false;
        onAdFailedToShow?.call();
      },
    );

    _interstitialAd!.show();
  }

  /// Dispose interstitial ad
  static void disposeInterstitialAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdReady = false;
  }

  /// Load rewarded ad without showing it immediately
  static Future<void> loadRewardedAd(BuildContext context) async {
    final adUnitId = getRewardedAdUnitId(context);
    if (adUnitId == null) {
      print('Rewarded ad unit ID is null');
      return;
    }

    // Dispose existing ad if any
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedAdReady = false;

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          print('Rewarded ad loaded and ready to show.');
          _rewardedAd = ad;
          _isRewardedAdReady = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Rewarded ad failed to load: $error');
          _rewardedAd = null;
          _isRewardedAdReady = false;
        },
      ),
    );
  }

  /// Show loaded rewarded ad
  static void showRewardedAd({
    required OnUserEarnedRewardCallback onUserEarnedReward,
    required VoidCallback onAdClosed,
    VoidCallback? onAdFailedToShow,
  }) {
    if (_rewardedAd == null || !_isRewardedAdReady) {
      print('Rewarded ad is not ready to show');
      onAdFailedToShow?.call();
      return;
    }

    _rewardedAd!
        .fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        print('Rewarded ad showed full screen content.');
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        print('Rewarded ad dismissed full screen content.');
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        onAdClosed();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        print('Rewarded ad failed to show full screen content: $error');
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        onAdFailedToShow?.call();
      },
    );

    _rewardedAd!.show(onUserEarnedReward: onUserEarnedReward);
  }

  /// Dispose rewarded ad
  static void disposeRewardedAd() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedAdReady = false;
  }

  /// Load and show a rewarded ad with reward callback
  static Future<void> loadAndShowRewardedAd({
    required BuildContext context,
    required OnUserEarnedRewardCallback onUserEarnedReward,
    required VoidCallback onAdClosed,
    VoidCallback? onAdFailedToLoad,
  }) async {
    final adUnitId = getRewardedAdUnitId(context);
    if (adUnitId == null) {
      print('Rewarded ad unit ID is null');
      onAdFailedToLoad?.call();
      return;
    }

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          print('Rewarded ad loaded.');
          ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
            onAdShowedFullScreenContent: (RewardedAd ad) {
              print('Rewarded ad showed full screen content.');
            },
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              print('Rewarded ad dismissed full screen content.');
              ad.dispose();
              onAdClosed();
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              print('Rewarded ad failed to show full screen content: $error');
              ad.dispose();
              onAdFailedToLoad?.call();
            },
          );
          ad.show(onUserEarnedReward: onUserEarnedReward);
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Rewarded ad failed to load: $error');
          onAdFailedToLoad?.call();
        },
      ),
    );
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

  /// Load and show an interstitial ad
  static Future<void> loadAndShowInterstitialAd({
    required BuildContext context,
    required VoidCallback onAdClosed,
    VoidCallback? onAdFailedToLoad,
  }) async {
    final adUnitId = getInterstitialAdUnitId(context);
    if (adUnitId == null) {
      print('Interstitial ad unit ID is null');
      onAdFailedToLoad?.call();
      return;
    }

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          print('Interstitial ad loaded.');
          ad.fullScreenContentCallback = FullScreenContentCallback<
            InterstitialAd
          >(
            onAdShowedFullScreenContent: (InterstitialAd ad) {
              print('Interstitial ad showed full screen content.');
            },
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              print('Interstitial ad dismissed full screen content.');
              ad.dispose();
              onAdClosed();
            },
            onAdFailedToShowFullScreenContent: (
              InterstitialAd ad,
              AdError error,
            ) {
              print(
                'Interstitial ad failed to show full screen content: $error',
              );
              ad.dispose();
              onAdFailedToLoad?.call();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Interstitial ad failed to load: $error');
          onAdFailedToLoad?.call();
        },
      ),
    );
  }

  /// Create interstitial ad load callback for custom handling
  static InterstitialAdLoadCallback createInterstitialAdLoadCallback({
    required Function(InterstitialAd) onAdLoaded,
    required Function(LoadAdError) onAdFailedToLoad,
  }) {
    return InterstitialAdLoadCallback(
      onAdLoaded: onAdLoaded,
      onAdFailedToLoad: onAdFailedToLoad,
    );
  }

  /// Create full screen content callback for interstitial ads
  static FullScreenContentCallback<InterstitialAd>
  createFullScreenContentCallback({
    void Function(InterstitialAd)? onAdShowedFullScreenContent,
    void Function(InterstitialAd)? onAdDismissedFullScreenContent,
    void Function(InterstitialAd, AdError)? onAdFailedToShowFullScreenContent,
  }) {
    return FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        print('Interstitial ad showed full screen content.');
        onAdShowedFullScreenContent?.call(ad);
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('Interstitial ad dismissed full screen content.');
        ad.dispose();
        onAdDismissedFullScreenContent?.call(ad);
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('Interstitial ad failed to show full screen content: $error');
        ad.dispose();
        onAdFailedToShowFullScreenContent?.call(ad, error);
      },
    );
  }
}
