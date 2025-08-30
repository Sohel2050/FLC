import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../providers/admob_provider.dart';

class AdMobService {
  static final Logger _logger = Logger();
  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialAdReady = false;
  static RewardedAd? _rewardedAd;
  static bool _isRewardedAdReady = false;

  /// Get banner ad unit ID from AdMobProvider
  static String? getBannerAdUnitId(BuildContext context) {
    try {
      final adMobProvider = Provider.of<AdMobProvider>(context, listen: false);
      final adUnitId = adMobProvider.bannerAdUnitId;
      if (adUnitId == null || adUnitId.isEmpty) {
        _logger.w('Banner ad unit ID is null or empty');
      }
      return adUnitId;
    } catch (e) {
      _logger.e('Error getting banner ad unit ID: $e');
      return null;
    }
  }

  /// Get interstitial ad unit ID from AdMobProvider
  static String? getInterstitialAdUnitId(BuildContext context) {
    try {
      final adMobProvider = Provider.of<AdMobProvider>(context, listen: false);
      final adUnitId = adMobProvider.interstitialAdUnitId;
      if (adUnitId == null || adUnitId.isEmpty) {
        _logger.w('Interstitial ad unit ID is null or empty');
      }
      return adUnitId;
    } catch (e) {
      _logger.e('Error getting interstitial ad unit ID: $e');
      return null;
    }
  }

  /// Get rewarded ad unit ID from AdMobProvider
  static String? getRewardedAdUnitId(BuildContext context) {
    try {
      final adMobProvider = Provider.of<AdMobProvider>(context, listen: false);
      final adUnitId = adMobProvider.rewardedAdUnitId;
      if (adUnitId == null || adUnitId.isEmpty) {
        _logger.w('Rewarded ad unit ID is null or empty');
      }
      return adUnitId;
    } catch (e) {
      _logger.e('Error getting rewarded ad unit ID: $e');
      return null;
    }
  }

  /// Get native ad unit ID from AdMobProvider
  static String? getNativeAdUnitId(BuildContext context) {
    try {
      final adMobProvider = Provider.of<AdMobProvider>(context, listen: false);
      final adUnitId = adMobProvider.nativeAdUnitId;
      if (adUnitId == null || adUnitId.isEmpty) {
        _logger.w('Native ad unit ID is null or empty');
      }
      return adUnitId;
    } catch (e) {
      _logger.e('Error getting native ad unit ID: $e');
      return null;
    }
  }

  /// Check if ads should be shown based on provider configuration and user preferences
  static bool shouldShowAds(BuildContext context, bool? userRemoveAds) {
    try {
      final adMobProvider = Provider.of<AdMobProvider>(context, listen: false);
      return adMobProvider.shouldShowAds(userRemoveAds);
    } catch (e) {
      _logger.e('Error checking if ads should be shown: $e');
      // Default to not showing ads if there's an error
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
    try {
      final adUnitId = getInterstitialAdUnitId(context);
      if (adUnitId == null || adUnitId.isEmpty) {
        _logger.w('Cannot load interstitial ad: ad unit ID is null or empty');
        return;
      }

      // Dispose existing ad if any
      try {
        _interstitialAd?.dispose();
      } catch (disposeError) {
        _logger.e('Error disposing existing interstitial ad: $disposeError');
      }
      _interstitialAd = null;
      _isInterstitialAdReady = false;

      _logger.i('Loading interstitial ad with ID: $adUnitId');

      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            try {
              _logger.i('Interstitial ad loaded and ready to show');
              _interstitialAd = ad;
              _isInterstitialAdReady = true;
            } catch (e) {
              _logger.e('Error in interstitial ad onAdLoaded callback: $e');
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdReady = false;
            }
          },
          onAdFailedToLoad: (LoadAdError error) {
            try {
              _logger.e(
                'Interstitial ad failed to load: ${error.message} (Code: ${error.code})',
              );
              _interstitialAd = null;
              _isInterstitialAdReady = false;
            } catch (e) {
              _logger.e(
                'Error in interstitial ad onAdFailedToLoad callback: $e',
              );
              _interstitialAd = null;
              _isInterstitialAdReady = false;
            }
          },
        ),
      );
    } catch (e) {
      _logger.e('Critical error loading interstitial ad: $e');
      _interstitialAd = null;
      _isInterstitialAdReady = false;
    }
  }

  /// Show loaded interstitial ad
  static void showInterstitialAd({
    required VoidCallback onAdClosed,
    VoidCallback? onAdFailedToShow,
  }) {
    try {
      if (_interstitialAd == null || !_isInterstitialAdReady) {
        _logger.w('Interstitial ad is not ready to show');
        try {
          onAdFailedToShow?.call();
        } catch (callbackError) {
          _logger.e('Error in onAdFailedToShow callback: $callbackError');
        }
        return;
      }

      _logger.i('Showing interstitial ad');

      try {
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback<
          InterstitialAd
        >(
          onAdShowedFullScreenContent: (InterstitialAd ad) {
            try {
              _logger.i('Interstitial ad showed full screen content');
            } catch (e) {
              _logger.e('Error in onAdShowedFullScreenContent callback: $e');
            }
          },
          onAdDismissedFullScreenContent: (InterstitialAd ad) {
            try {
              _logger.i('Interstitial ad dismissed full screen content');
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdReady = false;
              onAdClosed();
            } catch (e) {
              _logger.e('Error in onAdDismissedFullScreenContent callback: $e');
              // Ensure cleanup even if callback fails
              try {
                ad.dispose();
                _interstitialAd = null;
                _isInterstitialAdReady = false;
                onAdClosed();
              } catch (cleanupError) {
                _logger.e('Error in ad dismissal cleanup: $cleanupError');
              }
            }
          },
          onAdFailedToShowFullScreenContent: (
            InterstitialAd ad,
            AdError error,
          ) {
            try {
              _logger.e(
                'Interstitial ad failed to show full screen content: ${error.message} (Code: ${error.code})',
              );
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdReady = false;
              onAdFailedToShow?.call();
            } catch (e) {
              _logger.e(
                'Error in onAdFailedToShowFullScreenContent callback: $e',
              );
              // Ensure cleanup even if callback fails
              try {
                ad.dispose();
                _interstitialAd = null;
                _isInterstitialAdReady = false;
                onAdFailedToShow?.call();
              } catch (cleanupError) {
                _logger.e('Error in ad show failure cleanup: $cleanupError');
              }
            }
          },
        );

        _interstitialAd!.show();
      } catch (showError) {
        _logger.e('Error showing interstitial ad: $showError');
        // Clean up and call failure callback
        try {
          _interstitialAd?.dispose();
          _interstitialAd = null;
          _isInterstitialAdReady = false;
          onAdFailedToShow?.call();
        } catch (cleanupError) {
          _logger.e('Error in show failure cleanup: $cleanupError');
        }
      }
    } catch (e) {
      _logger.e('Critical error showing interstitial ad: $e');
      // Ensure cleanup and callback execution
      try {
        _interstitialAd?.dispose();
        _interstitialAd = null;
        _isInterstitialAdReady = false;
        onAdFailedToShow?.call();
      } catch (criticalError) {
        _logger.e('Critical error in show ad cleanup: $criticalError');
      }
    }
  }

  /// Dispose interstitial ad
  static void disposeInterstitialAd() {
    try {
      _interstitialAd?.dispose();
    } catch (e) {
      _logger.e('Error disposing interstitial ad: $e');
    } finally {
      _interstitialAd = null;
      _isInterstitialAdReady = false;
    }
  }

  /// Load rewarded ad without showing it immediately
  static Future<void> loadRewardedAd(BuildContext context) async {
    try {
      final adUnitId = getRewardedAdUnitId(context);
      if (adUnitId == null || adUnitId.isEmpty) {
        _logger.w('Cannot load rewarded ad: ad unit ID is null or empty');
        return;
      }

      // Dispose existing ad if any
      try {
        _rewardedAd?.dispose();
      } catch (disposeError) {
        _logger.e('Error disposing existing rewarded ad: $disposeError');
      }
      _rewardedAd = null;
      _isRewardedAdReady = false;

      _logger.i('Loading rewarded ad with ID: $adUnitId');

      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            try {
              _logger.i('Rewarded ad loaded and ready to show');
              _rewardedAd = ad;
              _isRewardedAdReady = true;
            } catch (e) {
              _logger.e('Error in rewarded ad onAdLoaded callback: $e');
              ad.dispose();
              _rewardedAd = null;
              _isRewardedAdReady = false;
            }
          },
          onAdFailedToLoad: (LoadAdError error) {
            try {
              _logger.e(
                'Rewarded ad failed to load: ${error.message} (Code: ${error.code})',
              );
              _rewardedAd = null;
              _isRewardedAdReady = false;
            } catch (e) {
              _logger.e('Error in rewarded ad onAdFailedToLoad callback: $e');
              _rewardedAd = null;
              _isRewardedAdReady = false;
            }
          },
        ),
      );
    } catch (e) {
      _logger.e('Critical error loading rewarded ad: $e');
      _rewardedAd = null;
      _isRewardedAdReady = false;
    }
  }

  /// Show loaded rewarded ad
  static void showRewardedAd({
    required OnUserEarnedRewardCallback onUserEarnedReward,
    required VoidCallback onAdClosed,
    VoidCallback? onAdFailedToShow,
  }) {
    try {
      if (_rewardedAd == null || !_isRewardedAdReady) {
        _logger.w('Rewarded ad is not ready to show');
        try {
          onAdFailedToShow?.call();
        } catch (callbackError) {
          _logger.e('Error in onAdFailedToShow callback: $callbackError');
        }
        return;
      }

      _logger.i('Showing rewarded ad');

      try {
        _rewardedAd!
            .fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
          onAdShowedFullScreenContent: (RewardedAd ad) {
            try {
              _logger.i('Rewarded ad showed full screen content');
            } catch (e) {
              _logger.e(
                'Error in rewarded ad onAdShowedFullScreenContent callback: $e',
              );
            }
          },
          onAdDismissedFullScreenContent: (RewardedAd ad) {
            try {
              _logger.i('Rewarded ad dismissed full screen content');
              ad.dispose();
              _rewardedAd = null;
              _isRewardedAdReady = false;
              onAdClosed();
            } catch (e) {
              _logger.e(
                'Error in rewarded ad onAdDismissedFullScreenContent callback: $e',
              );
              // Ensure cleanup even if callback fails
              try {
                ad.dispose();
                _rewardedAd = null;
                _isRewardedAdReady = false;
                onAdClosed();
              } catch (cleanupError) {
                _logger.e(
                  'Error in rewarded ad dismissal cleanup: $cleanupError',
                );
              }
            }
          },
          onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
            try {
              _logger.e(
                'Rewarded ad failed to show full screen content: ${error.message} (Code: ${error.code})',
              );
              ad.dispose();
              _rewardedAd = null;
              _isRewardedAdReady = false;
              onAdFailedToShow?.call();
            } catch (e) {
              _logger.e(
                'Error in rewarded ad onAdFailedToShowFullScreenContent callback: $e',
              );
              // Ensure cleanup even if callback fails
              try {
                ad.dispose();
                _rewardedAd = null;
                _isRewardedAdReady = false;
                onAdFailedToShow?.call();
              } catch (cleanupError) {
                _logger.e(
                  'Error in rewarded ad show failure cleanup: $cleanupError',
                );
              }
            }
          },
        );

        _rewardedAd!.show(onUserEarnedReward: onUserEarnedReward);
      } catch (showError) {
        _logger.e('Error showing rewarded ad: $showError');
        // Clean up and call failure callback
        try {
          _rewardedAd?.dispose();
          _rewardedAd = null;
          _isRewardedAdReady = false;
          onAdFailedToShow?.call();
        } catch (cleanupError) {
          _logger.e('Error in rewarded ad show failure cleanup: $cleanupError');
        }
      }
    } catch (e) {
      _logger.e('Critical error showing rewarded ad: $e');
      // Ensure cleanup and callback execution
      try {
        _rewardedAd?.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        onAdFailedToShow?.call();
      } catch (criticalError) {
        _logger.e('Critical error in rewarded ad show cleanup: $criticalError');
      }
    }
  }

  /// Dispose rewarded ad
  static void disposeRewardedAd() {
    try {
      _rewardedAd?.dispose();
    } catch (e) {
      _logger.e('Error disposing rewarded ad: $e');
    } finally {
      _rewardedAd = null;
      _isRewardedAdReady = false;
    }
  }

  /// Load and show a rewarded ad with reward callback
  static Future<void> loadAndShowRewardedAd({
    required BuildContext context,
    required OnUserEarnedRewardCallback onUserEarnedReward,
    required VoidCallback onAdClosed,
    VoidCallback? onAdFailedToLoad,
  }) async {
    try {
      final adUnitId = getRewardedAdUnitId(context);
      if (adUnitId == null || adUnitId.isEmpty) {
        _logger.w(
          'Cannot load and show rewarded ad: ad unit ID is null or empty',
        );
        try {
          onAdFailedToLoad?.call();
        } catch (callbackError) {
          _logger.e('Error in onAdFailedToLoad callback: $callbackError');
        }
        return;
      }

      _logger.i('Loading and showing rewarded ad with ID: $adUnitId');

      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            try {
              _logger.i('Rewarded ad loaded, setting up callbacks and showing');

              ad.fullScreenContentCallback = FullScreenContentCallback<
                RewardedAd
              >(
                onAdShowedFullScreenContent: (RewardedAd ad) {
                  try {
                    _logger.i('Rewarded ad showed full screen content');
                  } catch (e) {
                    _logger.e(
                      'Error in rewarded ad onAdShowedFullScreenContent: $e',
                    );
                  }
                },
                onAdDismissedFullScreenContent: (RewardedAd ad) {
                  try {
                    _logger.i('Rewarded ad dismissed full screen content');
                    ad.dispose();
                    onAdClosed();
                  } catch (e) {
                    _logger.e(
                      'Error in rewarded ad onAdDismissedFullScreenContent: $e',
                    );
                    try {
                      ad.dispose();
                      onAdClosed();
                    } catch (cleanupError) {
                      _logger.e(
                        'Error in rewarded ad dismissal cleanup: $cleanupError',
                      );
                    }
                  }
                },
                onAdFailedToShowFullScreenContent: (
                  RewardedAd ad,
                  AdError error,
                ) {
                  try {
                    _logger.e(
                      'Rewarded ad failed to show full screen content: ${error.message} (Code: ${error.code})',
                    );
                    ad.dispose();
                    onAdFailedToLoad?.call();
                  } catch (e) {
                    _logger.e(
                      'Error in rewarded ad onAdFailedToShowFullScreenContent: $e',
                    );
                    try {
                      ad.dispose();
                      onAdFailedToLoad?.call();
                    } catch (cleanupError) {
                      _logger.e(
                        'Error in rewarded ad show failure cleanup: $cleanupError',
                      );
                    }
                  }
                },
              );

              ad.show(onUserEarnedReward: onUserEarnedReward);
            } catch (e) {
              _logger.e('Error setting up or showing loaded rewarded ad: $e');
              try {
                ad.dispose();
                onAdFailedToLoad?.call();
              } catch (cleanupError) {
                _logger.e(
                  'Error in rewarded ad setup failure cleanup: $cleanupError',
                );
              }
            }
          },
          onAdFailedToLoad: (LoadAdError error) {
            try {
              _logger.e(
                'Rewarded ad failed to load: ${error.message} (Code: ${error.code})',
              );
              onAdFailedToLoad?.call();
            } catch (e) {
              _logger.e('Error in rewarded ad onAdFailedToLoad callback: $e');
            }
          },
        ),
      );
    } catch (e) {
      _logger.e('Critical error loading and showing rewarded ad: $e');
      try {
        onAdFailedToLoad?.call();
      } catch (callbackError) {
        _logger.e('Error in critical failure callback: $callbackError');
      }
    }
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
    onAdLoaded: (Ad ad) {
      try {
        _logger.i('Banner ad loaded successfully');
      } catch (e) {
        _logger.e('Error in banner ad onAdLoaded callback: $e');
      }
    },
    onAdFailedToLoad: (Ad ad, LoadAdError error) {
      try {
        _logger.e(
          'Banner ad failed to load: ${error.message} (Code: ${error.code})',
        );
        ad.dispose();
      } catch (e) {
        _logger.e('Error in banner ad onAdFailedToLoad callback: $e');
        try {
          ad.dispose();
        } catch (disposeError) {
          _logger.e(
            'Error disposing banner ad after load failure: $disposeError',
          );
        }
      }
    },
    onAdOpened: (Ad ad) {
      try {
        _logger.i('Banner ad opened');
      } catch (e) {
        _logger.e('Error in banner ad onAdOpened callback: $e');
      }
    },
    onAdClosed: (Ad ad) {
      try {
        _logger.i('Banner ad closed');
        ad.dispose();
      } catch (e) {
        _logger.e('Error in banner ad onAdClosed callback: $e');
        try {
          ad.dispose();
        } catch (disposeError) {
          _logger.e('Error disposing banner ad after close: $disposeError');
        }
      }
    },
    onAdImpression: (Ad ad) {
      try {
        _logger.d('Banner ad impression recorded');
      } catch (e) {
        _logger.e('Error in banner ad onAdImpression callback: $e');
      }
    },
  );

  /// Load and show an interstitial ad
  static Future<void> loadAndShowInterstitialAd({
    required BuildContext context,
    required VoidCallback onAdClosed,
    VoidCallback? onAdFailedToLoad,
  }) async {
    try {
      final adUnitId = getInterstitialAdUnitId(context);
      if (adUnitId == null || adUnitId.isEmpty) {
        _logger.w(
          'Cannot load and show interstitial ad: ad unit ID is null or empty',
        );
        try {
          onAdFailedToLoad?.call();
        } catch (callbackError) {
          _logger.e('Error in onAdFailedToLoad callback: $callbackError');
        }
        return;
      }

      _logger.i('Loading and showing interstitial ad with ID: $adUnitId');

      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            try {
              _logger.i(
                'Interstitial ad loaded, setting up callbacks and showing',
              );

              ad.fullScreenContentCallback = FullScreenContentCallback<
                InterstitialAd
              >(
                onAdShowedFullScreenContent: (InterstitialAd ad) {
                  try {
                    _logger.i('Interstitial ad showed full screen content');
                  } catch (e) {
                    _logger.e(
                      'Error in interstitial ad onAdShowedFullScreenContent: $e',
                    );
                  }
                },
                onAdDismissedFullScreenContent: (InterstitialAd ad) {
                  try {
                    _logger.i('Interstitial ad dismissed full screen content');
                    ad.dispose();
                    onAdClosed();
                  } catch (e) {
                    _logger.e(
                      'Error in interstitial ad onAdDismissedFullScreenContent: $e',
                    );
                    try {
                      ad.dispose();
                      onAdClosed();
                    } catch (cleanupError) {
                      _logger.e(
                        'Error in interstitial ad dismissal cleanup: $cleanupError',
                      );
                    }
                  }
                },
                onAdFailedToShowFullScreenContent: (
                  InterstitialAd ad,
                  AdError error,
                ) {
                  try {
                    _logger.e(
                      'Interstitial ad failed to show full screen content: ${error.message} (Code: ${error.code})',
                    );
                    ad.dispose();
                    onAdFailedToLoad?.call();
                  } catch (e) {
                    _logger.e(
                      'Error in interstitial ad onAdFailedToShowFullScreenContent: $e',
                    );
                    try {
                      ad.dispose();
                      onAdFailedToLoad?.call();
                    } catch (cleanupError) {
                      _logger.e(
                        'Error in interstitial ad show failure cleanup: $cleanupError',
                      );
                    }
                  }
                },
              );

              ad.show();
            } catch (e) {
              _logger.e(
                'Error setting up or showing loaded interstitial ad: $e',
              );
              try {
                ad.dispose();
                onAdFailedToLoad?.call();
              } catch (cleanupError) {
                _logger.e(
                  'Error in interstitial ad setup failure cleanup: $cleanupError',
                );
              }
            }
          },
          onAdFailedToLoad: (LoadAdError error) {
            try {
              _logger.e(
                'Interstitial ad failed to load: ${error.message} (Code: ${error.code})',
              );
              onAdFailedToLoad?.call();
            } catch (e) {
              _logger.e(
                'Error in interstitial ad onAdFailedToLoad callback: $e',
              );
            }
          },
        ),
      );
    } catch (e) {
      _logger.e('Critical error loading and showing interstitial ad: $e');
      try {
        onAdFailedToLoad?.call();
      } catch (callbackError) {
        _logger.e('Error in critical failure callback: $callbackError');
      }
    }
  }

  /// Create interstitial ad load callback for custom handling
  static InterstitialAdLoadCallback createInterstitialAdLoadCallback({
    required Function(InterstitialAd) onAdLoaded,
    required Function(LoadAdError) onAdFailedToLoad,
  }) {
    try {
      return InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          try {
            onAdLoaded(ad);
          } catch (e) {
            _logger.e(
              'Error in custom interstitial ad onAdLoaded callback: $e',
            );
            ad.dispose();
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          try {
            onAdFailedToLoad(error);
          } catch (e) {
            _logger.e(
              'Error in custom interstitial ad onAdFailedToLoad callback: $e',
            );
          }
        },
      );
    } catch (e) {
      _logger.e('Error creating interstitial ad load callback: $e');
      // Return a safe fallback callback
      return InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _logger.w('Fallback: disposing ad due to callback creation error');
          ad.dispose();
        },
        onAdFailedToLoad: (LoadAdError error) {
          _logger.w(
            'Fallback: ad failed to load due to callback creation error',
          );
        },
      );
    }
  }

  /// Create full screen content callback for interstitial ads
  static FullScreenContentCallback<InterstitialAd>
  createFullScreenContentCallback({
    void Function(InterstitialAd)? onAdShowedFullScreenContent,
    void Function(InterstitialAd)? onAdDismissedFullScreenContent,
    void Function(InterstitialAd, AdError)? onAdFailedToShowFullScreenContent,
  }) {
    try {
      return FullScreenContentCallback<InterstitialAd>(
        onAdShowedFullScreenContent: (InterstitialAd ad) {
          try {
            _logger.i('Interstitial ad showed full screen content');
            onAdShowedFullScreenContent?.call(ad);
          } catch (e) {
            _logger.e(
              'Error in custom onAdShowedFullScreenContent callback: $e',
            );
          }
        },
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          try {
            _logger.i('Interstitial ad dismissed full screen content');
            ad.dispose();
            onAdDismissedFullScreenContent?.call(ad);
          } catch (e) {
            _logger.e(
              'Error in custom onAdDismissedFullScreenContent callback: $e',
            );
            try {
              ad.dispose();
            } catch (disposeError) {
              _logger.e(
                'Error disposing ad in dismissal callback: $disposeError',
              );
            }
          }
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          try {
            _logger.e(
              'Interstitial ad failed to show full screen content: ${error.message} (Code: ${error.code})',
            );
            ad.dispose();
            onAdFailedToShowFullScreenContent?.call(ad, error);
          } catch (e) {
            _logger.e(
              'Error in custom onAdFailedToShowFullScreenContent callback: $e',
            );
            try {
              ad.dispose();
            } catch (disposeError) {
              _logger.e(
                'Error disposing ad in show failure callback: $disposeError',
              );
            }
          }
        },
      );
    } catch (e) {
      _logger.e('Error creating full screen content callback: $e');
      // Return a safe fallback callback
      return FullScreenContentCallback<InterstitialAd>(
        onAdShowedFullScreenContent: (InterstitialAd ad) {
          _logger.w('Fallback: ad showed full screen content');
        },
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          _logger.w('Fallback: disposing ad on dismissal');
          try {
            ad.dispose();
          } catch (disposeError) {
            _logger.e(
              'Error disposing ad in fallback dismissal: $disposeError',
            );
          }
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          _logger.w('Fallback: disposing ad on show failure');
          try {
            ad.dispose();
          } catch (disposeError) {
            _logger.e(
              'Error disposing ad in fallback show failure: $disposeError',
            );
          }
        },
      );
    }
  }
}
