import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../providers/admob_provider.dart';
import '../models/user_model.dart';

class AdMobService {
  static final Logger _logger = Logger();
  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialAdReady = false;
  static RewardedAd? _rewardedAd;
  static bool _isRewardedAdReady = false;
  static AppOpenAd? _appOpenAd;

  /// Get appOpen ad unit ID from AdMobProvider
  static String? getAppOpenAdUnitId(BuildContext context) {
    try {
      final adMobProvider = Provider.of<AdMobProvider>(context, listen: false);
      final adUnitId = adMobProvider.appOpenAdUnitId;
      if (adUnitId == null || adUnitId.isEmpty) {
        _logger.w('AppOpen ad unit ID is null or empty');
      }
      return adUnitId;
    } catch (e) {
      _logger.e('Error getting appOpen ad unit ID: $e');
      return null;
    }
  }

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

  /// Check if ads should be shown for guest users specifically
  /// This method ensures guest users with persistent sessions can see ads
  static bool shouldShowAdsForGuestUser(BuildContext context, ChessUser? user) {
    try {
      final adMobProvider = Provider.of<AdMobProvider>(context, listen: false);

      // Don't show ads if configuration is not loaded
      if (adMobProvider.adMobConfig == null) {
        _logger.w('AdMob config not loaded, cannot show ads for guest user');
        return false;
      }

      // Don't show ads if ads are disabled in configuration
      if (!adMobProvider.isAdsEnabled) {
        _logger.i('Ads disabled in configuration, not showing for guest user');
        return false;
      }

      // For guest users, always show ads (they can't purchase ad removal)
      if (user != null && user.isGuest) {
        _logger.i('Guest user detected, showing ads');
        return true;
      }

      // For regular users, check their ad removal preference
      return adMobProvider.shouldShowAds(user?.removeAds);
    } catch (e) {
      _logger.e('Error checking if ads should be shown for guest user: $e');
      return false;
    }
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
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  /// Load and show an app open ad with enhanced guest user support
  static Future<void> loadAndShowAppOpenAd({
    required BuildContext context,
    required VoidCallback onAdClosed,
    VoidCallback? onAdFailedToLoad,
    ChessUser? user,
  }) async {
    try {
      final adUnitId = getAppOpenAdUnitId(context);
      if (adUnitId == null || adUnitId.isEmpty) {
        _logger.w(
          'Cannot load and show app open ad: ad unit ID is null or empty',
        );
        try {
          onAdFailedToLoad?.call();
        } catch (callbackError) {
          _logger.e('Error in onAdFailedToLoad callback: $callbackError');
        }
        return;
      }

      // Log user type for debugging
      if (user != null) {
        _logger.i(
          'Loading app open ad for ${user.isGuest ? 'guest' : 'registered'} user: ${user.uid}',
        );
      }

      _logger.i('Loading and showing app open ad with ID: $adUnitId');

      // Dispose any existing app open ad
      _appOpenAd?.dispose();
      _appOpenAd = null;

      await AppOpenAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (AppOpenAd ad) {
            try {
              _logger.i('App open ad loaded, setting up callbacks and showing');
              _appOpenAd = ad;

              ad.fullScreenContentCallback = FullScreenContentCallback<
                AppOpenAd
              >(
                onAdShowedFullScreenContent: (AppOpenAd ad) {
                  try {
                    _logger.i('App open ad showed full screen content');
                  } catch (e) {
                    _logger.e(
                      'Error in app open ad onAdShowedFullScreenContent: $e',
                    );
                  }
                },
                onAdDismissedFullScreenContent: (AppOpenAd ad) {
                  try {
                    _logger.i('App open ad dismissed full screen content');
                    ad.dispose();
                    _appOpenAd = null;
                    onAdClosed();
                  } catch (e) {
                    _logger.e(
                      'Error in app open ad onAdDismissedFullScreenContent: $e',
                    );
                    try {
                      ad.dispose();
                      _appOpenAd = null;
                      onAdClosed();
                    } catch (cleanupError) {
                      _logger.e(
                        'Error in app open ad dismissal cleanup: $cleanupError',
                      );
                    }
                  }
                },
                onAdFailedToShowFullScreenContent: (
                  AppOpenAd ad,
                  AdError error,
                ) {
                  try {
                    _logger.e(
                      'App open ad failed to show full screen content: ${error.message} (Code: ${error.code})',
                    );
                    ad.dispose();
                    _appOpenAd = null;
                    onAdFailedToLoad?.call();
                  } catch (e) {
                    _logger.e(
                      'Error in app open ad onAdFailedToShowFullScreenContent: $e',
                    );
                    try {
                      ad.dispose();
                      _appOpenAd = null;
                      onAdFailedToLoad?.call();
                    } catch (cleanupError) {
                      _logger.e(
                        'Error in app open ad show failure cleanup: $cleanupError',
                      );
                    }
                  }
                },
              );

              ad.show();
            } catch (e) {
              _logger.e('Error setting up or showing loaded app open ad: $e');
              try {
                ad.dispose();
                _appOpenAd = null;
                onAdFailedToLoad?.call();
              } catch (cleanupError) {
                _logger.e(
                  'Error in app open ad setup failure cleanup: $cleanupError',
                );
              }
            }
          },
          onAdFailedToLoad: (LoadAdError error) {
            try {
              _logger.e(
                'App open ad failed to load: ${error.message} (Code: ${error.code})',
              );
              _appOpenAd = null;
              onAdFailedToLoad?.call();
            } catch (e) {
              _logger.e('Error in app open ad onAdFailedToLoad callback: $e');
            }
          },
        ),
      );
    } catch (e) {
      _logger.e('Critical error loading and showing app open ad: $e');
      try {
        _appOpenAd = null;
        onAdFailedToLoad?.call();
      } catch (callbackError) {
        _logger.e('Error in critical failure callback: $callbackError');
      }
    }
  }

  /// Show loaded interstitial ad
  static void showInterstitialAd({
    required VoidCallback onAdClosed,
    VoidCallback? onAdFailedToShow,
  }) {
    if (_interstitialAd == null || !_isInterstitialAdReady) {
      onAdFailedToShow?.call();
      return;
    }

    _interstitialAd!
        .fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (InterstitialAd ad) {},
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdReady = false;
        onAdClosed();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
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
          _rewardedAd = ad;
          _isRewardedAdReady = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
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
      onAdFailedToShow?.call();
      return;
    }

    _rewardedAd!
        .fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdShowedFullScreenContent: (RewardedAd ad) {},
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        onAdClosed();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
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

  /// Dispose app open ad
  static void disposeAppOpenAd() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _logger.i('App open ad disposed');
  }

  /// Get the current app open ad instance
  static AppOpenAd? get appOpenAd => _appOpenAd;

  /// Load and show a rewarded ad with reward callback
  static Future<void> loadAndShowRewardedAd({
    required BuildContext context,
    required OnUserEarnedRewardCallback onUserEarnedReward,
    required VoidCallback onAdClosed,
    VoidCallback? onAdFailedToLoad,
  }) async {
    final adUnitId = getRewardedAdUnitId(context);
    if (adUnitId == null) {
      onAdFailedToLoad?.call();
      return;
    }

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
            onAdShowedFullScreenContent: (RewardedAd ad) {},
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              ad.dispose();
              onAdClosed();
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              ad.dispose();
              onAdFailedToLoad?.call();
            },
          );
          ad.show(onUserEarnedReward: onUserEarnedReward);
        },
        onAdFailedToLoad: (LoadAdError error) {
          onAdFailedToLoad?.call();
        },
      ),
    );
  }

  static final BannerAdListener bannerAdListener = BannerAdListener(
    onAdLoaded: (Ad ad) => print('Ad loaded.'),
    onAdFailedToLoad: (Ad ad, LoadAdError error) {
      ad.dispose();
      print('Ad failed to load: $error');
    },
    onAdOpened: (Ad ad) => print('Ad opened.'),
    onAdClosed: (Ad ad) {
      ad.dispose();
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
      onAdFailedToLoad?.call();
      return;
    }

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          ad.fullScreenContentCallback =
              FullScreenContentCallback<InterstitialAd>(
                onAdShowedFullScreenContent: (InterstitialAd ad) {},
                onAdDismissedFullScreenContent: (InterstitialAd ad) {
                  ad.dispose();
                  onAdClosed();
                },
                onAdFailedToShowFullScreenContent: (
                  InterstitialAd ad,
                  AdError error,
                ) {
                  ad.dispose();
                  onAdFailedToLoad?.call();
                },
              );
          ad.show();
        },
        onAdFailedToLoad: (LoadAdError error) {
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
        onAdShowedFullScreenContent?.call(ad);
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        onAdDismissedFullScreenContent?.call(ad);
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        onAdFailedToShowFullScreenContent?.call(ad, error);
      },
    );
  }
}
