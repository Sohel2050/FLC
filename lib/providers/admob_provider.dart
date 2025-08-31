import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/admob_config_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class AdMobProvider with ChangeNotifier {
  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AdMobConfig? _adMobConfig;
  bool _isLoading = false;
  String? _error;
  bool _isInterstitialAdLoading = false;

  // Getters
  AdMobConfig? get adMobConfig => _adMobConfig;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInterstitialAdLoading => _isInterstitialAdLoading;

  String? get appOpenAdUnitId => _adMobConfig?.appOpenAdUnitId;

  // Platform-specific getters for convenience
  String? get bannerAdUnitId => _adMobConfig?.bannerAdUnitId;
  String? get interstitialAdUnitId => _adMobConfig?.interstitialAdUnitId;
  String? get rewardedAdUnitId => _adMobConfig?.rewardedAdUnitId;
  String? get nativeAdUnitId => _adMobConfig?.nativeAdUnitId;
  bool get isAdsEnabled => _adMobConfig?.enabled ?? false;

  AdMobProvider() {
    _initializeAdMobConfig();
  }

  Future<void> _initializeAdMobConfig() async {
    await loadAdMobConfig();
  }

  /// Load AdMob configuration from Firebase
  Future<void> loadAdMobConfig() async {
    try {
      _setLoading(true);
      _error = null;

      final docSnapshot =
          await _firestore
              .collection(Constants.admobConfigCollection)
              .doc(Constants.config)
              .get();

      if (docSnapshot.exists) {
        _adMobConfig = AdMobConfig.fromMap(
          docSnapshot.data() as Map<String, dynamic>,
        );
        _logger.i('AdMob config loaded successfully');
      } else {
        _logger.w(
          'AdMob config not found in Firebase. Using default test config.',
        );
        // Use default config as fallback (migration should have created it)
        _adMobConfig = AdMobConfig.defaultTestConfig();
      }
    } catch (e) {
      _error = 'Failed to load AdMob configuration: $e';
      _logger.e('Error loading AdMob config: $e');

      // Fallback to default test config
      _adMobConfig = AdMobConfig.defaultTestConfig();
      _logger.i('Using default test AdMob config as fallback');
    } finally {
      _setLoading(false);
    }
  }

  /// Update AdMob configuration in Firebase (admin functionality)
  Future<void> updateAdMobConfig(AdMobConfig config) async {
    try {
      _setLoading(true);
      _error = null;

      await _firestore
          .collection(Constants.admobConfigCollection)
          .doc(Constants.config)
          .update(config.copyWith(lastUpdated: DateTime.now()).toMap());

      _adMobConfig = config;
      _logger.i('AdMob config updated successfully');
    } catch (e) {
      _error = 'Failed to update AdMob configuration: $e';
      _logger.e('Error updating AdMob config: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Listen to real-time updates of AdMob configuration
  Stream<AdMobConfig?> getAdMobConfigStream() {
    return _firestore
        .collection(Constants.admobConfigCollection)
        .doc(Constants.config)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            final config = AdMobConfig.fromMap(
              snapshot.data() as Map<String, dynamic>,
            );
            _adMobConfig = config;
            notifyListeners();
            return config;
          }
          return null;
        })
        .handleError((error) {
          _error = 'Error in AdMob config stream: $error';
          _logger.e('Stream error: $error');
          notifyListeners();
          return null;
        });
  }

  /// Set loading state and notify listeners
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Check if ads should be shown (considering configuration and user preferences)
  bool shouldShowAds(bool? userRemoveAds) {
    // Don't show ads if the user has purchased ad removal
    if (userRemoveAds == true) {
      return false;
    }

    // Don't show ads if ads are disabled in configuration
    if (!isAdsEnabled) {
      return false;
    }

    // Don't show ads if configuration is not loaded
    if (_adMobConfig == null) {
      return false;
    }

    return true;
  }

  /// Set interstitial ad loading state
  void setInterstitialAdLoading(bool loading) {
    _isInterstitialAdLoading = loading;
    notifyListeners();
  }

  /// Check if app launch ad should be shown (always show for non-premium users)
  bool shouldShowAppLaunchAd(bool? userRemoveAds) {
    // Check general ad conditions - this will show on every app launch for non-premium users
    return shouldShowAds(userRemoveAds);
  }

  /// Check if app launch ad should be shown for guest users specifically
  /// This method ensures persistent guest users see ads properly
  bool shouldShowAppLaunchAdForGuestUser(ChessUser? user) {
    try {
      // Don't show ads if configuration is not loaded
      if (_adMobConfig == null) {
        _logger.w(
          'AdMob config not loaded, cannot show app launch ad for guest user',
        );
        return false;
      }

      // Don't show ads if ads are disabled in configuration
      if (!isAdsEnabled) {
        _logger.i(
          'Ads disabled in configuration, not showing app launch ad for guest user',
        );
        return false;
      }

      // For guest users, always show ads (they can't purchase ad removal)
      if (user != null && user.isGuest) {
        _logger.i('Guest user detected, showing app launch ad');
        return true;
      }

      // For regular users, check their ad removal preference
      return shouldShowAds(user?.removeAds);
    } catch (e) {
      _logger.e(
        'Error checking if app launch ad should be shown for guest user: $e',
      );
      return false;
    }
  }
}
