import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/admob_provider.dart';
import '../services/admob_service.dart';

/// Manager for app open ads that handles app lifecycle events
/// Shows ads when the app comes to foreground after being backgrounded
class AppOpenAdManager with WidgetsBindingObserver {
  static final Logger _logger = Logger();
  static AppOpenAdManager? _instance;
  static bool _isInitialized = false;

  AppOpenAd? _appOpenAd;
  bool _isLoadingAd = false;
  bool _isShowingAd = false;
  DateTime? _appOpenLoadTime;

  // Configuration
  static const Duration _maxCacheDuration = Duration(hours: 4);
  static const Duration _minTimeBetweenAds = Duration(minutes: 5);
  DateTime? _lastAdShownTime;

  BuildContext? _context;
  ChessUser? _currentUser;

  AppOpenAdManager._();

  /// Get singleton instance
  static AppOpenAdManager get instance {
    _instance ??= AppOpenAdManager._();
    return _instance!;
  }

  /// Initialize the app open ad manager
  static void initialize(BuildContext context, ChessUser user) {
    try {
      if (_isInitialized) {
        _logger.d('AppOpenAdManager already initialized');
        return;
      }

      final manager = AppOpenAdManager.instance;
      manager._context = context;
      manager._currentUser = user;

      // Add as lifecycle observer
      WidgetsBinding.instance.addObserver(manager);

      _isInitialized = true;
      _logger.i('AppOpenAdManager initialized successfully');
    } catch (e) {
      _logger.e('Error initializing AppOpenAdManager: $e');
    }
  }

  /// Update user information
  void updateUser(ChessUser user) {
    _currentUser = user;
  }

  /// Update context
  void updateContext(BuildContext context) {
    _context = context;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    try {
      _logger.d('App lifecycle state changed to: $state');

      switch (state) {
        case AppLifecycleState.resumed:
          _onAppResumed();
          break;
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
          // App going to background - preload ad for next resume
          _preloadAdForNextResume();
          break;
      }
    } catch (e) {
      _logger.e('Error handling app lifecycle state change: $e');
    }
  }

  /// Handle app resume - show ad if appropriate
  void _onAppResumed() {
    try {
      if (!_shouldShowAppOpenAd()) {
        _logger.d('App open ad should not be shown on resume');
        return;
      }

      if (_isShowingAd) {
        _logger.d('App open ad already showing, skipping');
        return;
      }

      _showAppOpenAd();
    } catch (e) {
      _logger.e('Error handling app resume: $e');
    }
  }

  /// Preload ad for next app resume
  void _preloadAdForNextResume() {
    try {
      if (_isLoadingAd || _appOpenAd != null) {
        _logger.d('App open ad already loaded or loading, skipping preload');
        return;
      }

      if (!_shouldShowAppOpenAd()) {
        _logger.d('App open ad should not be shown, skipping preload');
        return;
      }

      _loadAppOpenAd();
    } catch (e) {
      _logger.e('Error preloading app open ad: $e');
    }
  }

  /// Check if app open ad should be shown
  bool _shouldShowAppOpenAd() {
    try {
      if (_context == null || _currentUser == null) {
        _logger.d('Context or user not available for app open ad');
        return false;
      }

      // Don't show if user has premium
      if (_currentUser!.removeAds == true) {
        _logger.d('User has premium, skipping app open ad');
        return false;
      }

      // Check if enough time has passed since last ad
      if (_lastAdShownTime != null) {
        final timeSinceLastAd = DateTime.now().difference(_lastAdShownTime!);
        if (timeSinceLastAd < _minTimeBetweenAds) {
          _logger.d(
            'Not enough time since last app open ad, skipping (${timeSinceLastAd.inMinutes} minutes since last ad)',
          );
          return false;
        }
      }

      // Check AdMob configuration
      try {
        final adMobProvider = Provider.of<AdMobProvider>(
          _context!,
          listen: false,
        );
        if (!adMobProvider.shouldShowAds(_currentUser!.removeAds)) {
          _logger.d('Ads disabled in configuration, skipping app open ad');
          return false;
        }

        // Check if app open ad unit ID is available
        final appOpenAdUnitId = adMobProvider.appOpenAdUnitId;
        if (appOpenAdUnitId == null || appOpenAdUnitId.isEmpty) {
          _logger.d('App open ad unit ID not available, skipping app open ad');
          return false;
        }
      } catch (providerError) {
        _logger.e('Error checking AdMob configuration: $providerError');
        return false;
      }

      _logger.d('App open ad should be shown - all conditions met');
      return true;
    } catch (e) {
      _logger.e('Error checking if app open ad should be shown: $e');
      return false;
    }
  }

  /// Load app open ad
  void _loadAppOpenAd() {
    try {
      if (_context == null) {
        _logger.w('Context not available for loading app open ad');
        return;
      }

      if (_isLoadingAd) {
        _logger.d('App open ad already loading');
        return;
      }

      final adUnitId = AdMobService.getAppOpenAdUnitId(_context!);
      if (adUnitId == null || adUnitId.isEmpty) {
        _logger.w('App open ad unit ID not available');
        return;
      }

      _isLoadingAd = true;
      _logger.i('Loading app open ad with ID: $adUnitId');

      AppOpenAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (AppOpenAd ad) {
            try {
              _logger.i('App open ad loaded successfully');
              _appOpenAd = ad;
              _appOpenLoadTime = DateTime.now();
              _isLoadingAd = false;
            } catch (e) {
              _logger.e('Error in app open ad onAdLoaded callback: $e');
              ad.dispose();
              _isLoadingAd = false;
            }
          },
          onAdFailedToLoad: (LoadAdError error) {
            try {
              _logger.e(
                'App open ad failed to load: ${error.message} (Code: ${error.code})',
              );
              _isLoadingAd = false;
            } catch (e) {
              _logger.e('Error in app open ad onAdFailedToLoad callback: $e');
              _isLoadingAd = false;
            }
          },
        ),
      );
    } catch (e) {
      _logger.e('Error loading app open ad: $e');
      _isLoadingAd = false;
    }
  }

  /// Show app open ad if available
  void _showAppOpenAd() {
    try {
      if (_appOpenAd == null) {
        _logger.d('No app open ad available to show, loading new one');
        _loadAppOpenAd();
        return;
      }

      // Check if ad is too old
      if (_appOpenLoadTime != null) {
        final adAge = DateTime.now().difference(_appOpenLoadTime!);
        if (adAge > _maxCacheDuration) {
          _logger.d('App open ad is too old, disposing and loading new one');
          _appOpenAd!.dispose();
          _appOpenAd = null;
          _appOpenLoadTime = null;
          _loadAppOpenAd();
          return;
        }
      }

      _logger.i('Showing app open ad');
      _isShowingAd = true;

      _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (AppOpenAd ad) {
          try {
            _logger.i('App open ad showed full screen content');
          } catch (e) {
            _logger.e('Error in app open ad onAdShowedFullScreenContent: $e');
          }
        },
        onAdDismissedFullScreenContent: (AppOpenAd ad) {
          try {
            _logger.i('App open ad dismissed');
            ad.dispose();
            _appOpenAd = null;
            _appOpenLoadTime = null;
            _isShowingAd = false;
            _lastAdShownTime = DateTime.now();

            // Preload next ad
            _preloadAdForNextResume();
          } catch (e) {
            _logger.e(
              'Error in app open ad onAdDismissedFullScreenContent: $e',
            );
            _isShowingAd = false;
            _lastAdShownTime = DateTime.now();
          }
        },
        onAdFailedToShowFullScreenContent: (AppOpenAd ad, AdError error) {
          try {
            _logger.e(
              'App open ad failed to show: ${error.message} (Code: ${error.code})',
            );
            ad.dispose();
            _appOpenAd = null;
            _appOpenLoadTime = null;
            _isShowingAd = false;
          } catch (e) {
            _logger.e(
              'Error in app open ad onAdFailedToShowFullScreenContent: $e',
            );
            _isShowingAd = false;
          }
        },
      );

      _appOpenAd!.show();
    } catch (e) {
      _logger.e('Error showing app open ad: $e');
      _isShowingAd = false;
    }
  }

  /// Dispose resources
  void dispose() {
    try {
      _logger.i('Disposing AppOpenAdManager');

      WidgetsBinding.instance.removeObserver(this);

      _appOpenAd?.dispose();
      _appOpenAd = null;
      _appOpenLoadTime = null;
      _isLoadingAd = false;
      _isShowingAd = false;
      _context = null;
      _currentUser = null;

      _isInitialized = false;
      _instance = null;

      _logger.i('AppOpenAdManager disposed successfully');
    } catch (e) {
      _logger.e('Error disposing AppOpenAdManager: $e');
    }
  }
}
