import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/admob_config_model.dart';
import '../utils/constants.dart';

enum AppLaunchAdState {
  notStarted,
  loading,
  showing,
  completed,
  failed,
  timedOut,
}

class AdMobProvider with ChangeNotifier {
  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AdMobConfig? _adMobConfig;
  bool _isLoading = false;
  String? _error;
  bool _isInterstitialAdLoading = false;
  bool _hasShownAppLaunchAd = false;

  // App launch ad sequence management
  AppLaunchAdState _appLaunchAdState = AppLaunchAdState.notStarted;
  bool _isAppLaunchSequenceComplete = false;
  Timer? _appLaunchAdTimeout;

  // Native ad coordination to prevent multiple screens loading ads simultaneously
  String? _currentNativeAdScreen;
  final Set<String> _nativeAdLoadingScreens = <String>{};

  // Getters
  AdMobConfig? get adMobConfig => _adMobConfig;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInterstitialAdLoading => _isInterstitialAdLoading;
  bool get hasShownAppLaunchAd => _hasShownAppLaunchAd;

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
    // Prevent multiple concurrent loads
    if (_isLoading) {
      _logger.d('AdMob config already loading, waiting for completion');
      // Wait for current load to complete
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    try {
      _setLoading(true);
      _error = null;

      final docSnapshot =
          await _firestore
              .collection(Constants.admobConfigCollection)
              .doc(Constants.config)
              .get();

      if (docSnapshot.exists) {
        try {
          _adMobConfig = AdMobConfig.fromMap(
            docSnapshot.data() as Map<String, dynamic>,
          );
          _logger.i('AdMob config loaded successfully');
        } catch (parseError) {
          _logger.e('Error parsing AdMob config data: $parseError');
          _error = 'Invalid AdMob configuration format';
          _adMobConfig = AdMobConfig.defaultTestConfig();
          _logger.i('Using default test AdMob config due to parse error');
        }
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

      // Fallback to default test config to ensure app continues functioning
      _adMobConfig = AdMobConfig.defaultTestConfig();
      _logger.i('Using default test AdMob config as fallback after error');
    } finally {
      _setLoading(false);
    }
  }

  /// Update AdMob configuration in Firebase (admin functionality)
  Future<void> updateAdMobConfig(AdMobConfig config) async {
    try {
      _setLoading(true);
      _error = null;

      // Validate config before updating
      if (config.bannerAdUnitId?.isEmpty == true ||
          config.interstitialAdUnitId?.isEmpty == true ||
          config.nativeAdUnitId?.isEmpty == true) {
        throw ArgumentError('AdMob config contains empty ad unit IDs');
      }

      await _firestore
          .collection(Constants.admobConfigCollection)
          .doc(Constants.config)
          .update(config.copyWith(lastUpdated: DateTime.now()).toMap());

      _adMobConfig = config;
      _logger.i('AdMob config updated successfully');
    } catch (e) {
      _error = 'Failed to update AdMob configuration: $e';
      _logger.e('Error updating AdMob config: $e');

      // Don't update local config if Firebase update failed
      _logger.w('Keeping existing AdMob config due to update failure');
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
          try {
            if (snapshot.exists) {
              final data = snapshot.data();
              if (data == null) {
                _logger.w('AdMob config snapshot exists but data is null');
                return _adMobConfig; // Return current config
              }

              final config = AdMobConfig.fromMap(data as Map<String, dynamic>);
              _adMobConfig = config;
              _logger.d('AdMob config updated from stream');
              notifyListeners();
              return config;
            } else {
              _logger.w('AdMob config document does not exist in stream');
              return _adMobConfig; // Return current config instead of null
            }
          } catch (parseError) {
            _logger.e('Error parsing AdMob config from stream: $parseError');
            _error = 'Invalid AdMob configuration format in stream';
            notifyListeners();
            return _adMobConfig; // Return current config to maintain functionality
          }
        })
        .handleError((error) {
          _error = 'Error in AdMob config stream: $error';
          _logger.e('AdMob config stream error: $error');

          // Ensure app continues functioning by providing fallback
          if (_adMobConfig == null) {
            _adMobConfig = AdMobConfig.defaultTestConfig();
            _logger.i('Using default test config due to stream error');
          }

          notifyListeners();
          return _adMobConfig;
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
    try {
      // Don't show ads if the user has purchased ad removal
      if (userRemoveAds == true) {
        _logger.d('Ads disabled: user has premium (removeAds = true)');
        return false;
      }

      // Don't show ads if configuration is not loaded
      if (_adMobConfig == null) {
        _logger.w('Ads disabled: AdMob configuration not loaded');
        return false;
      }

      // Don't show ads if ads are disabled in configuration
      if (!isAdsEnabled) {
        _logger.d('Ads disabled: configuration has ads disabled');
        return false;
      }

      _logger.d('Ads should be shown: all conditions met');
      return true;
    } catch (e) {
      _logger.e('Error checking if ads should be shown: $e');
      // Default to not showing ads if there's an error
      return false;
    }
  }

  /// Set interstitial ad loading state
  void setInterstitialAdLoading(bool loading) {
    _isInterstitialAdLoading = loading;
    notifyListeners();
  }

  /// Mark that app launch ad has been shown
  void markAppLaunchAdShown() {
    _hasShownAppLaunchAd = true;
    notifyListeners();
  }

  /// Reset app launch ad flag (useful for testing or new sessions)
  void resetAppLaunchAdFlag() {
    _hasShownAppLaunchAd = false;
    notifyListeners();
  }

  /// Check if app launch ad should be shown
  bool shouldShowAppLaunchAd(bool? userRemoveAds) {
    // Don't show if already shown in this session
    if (_hasShownAppLaunchAd) {
      return false;
    }

    // Check general ad conditions
    return shouldShowAds(userRemoveAds);
  }

  /// Request permission to load native ad for a specific screen
  bool requestNativeAdPermission(String screenName) {
    if (_nativeAdLoadingScreens.contains(screenName)) {
      return true;
    }

    if (_nativeAdLoadingScreens.isEmpty) {
      _nativeAdLoadingScreens.add(screenName);
      _currentNativeAdScreen = screenName;
      return true;
    }

    return false;
  }

  /// Release native ad permission for a specific screen
  void releaseNativeAdPermission(String screenName) {
    _nativeAdLoadingScreens.remove(screenName);
    if (_currentNativeAdScreen == screenName) {
      _currentNativeAdScreen = null;
    }
  }

  /// Check if a specific screen has permission to load native ads
  bool hasNativeAdPermission(String screenName) {
    return _nativeAdLoadingScreens.contains(screenName);
  }

  /// Get the current screen that has native ad permission
  String? get currentNativeAdScreen => _currentNativeAdScreen;

  /// Reset app launch ad flags for a new session with detailed logging
  void resetAppLaunchAdForNewSession() {
    _logger.i(
      'Resetting app launch ad for new session - Current state: $_appLaunchAdState, Sequence complete: $_isAppLaunchSequenceComplete, Ad shown: $_hasShownAppLaunchAd',
    );

    _hasShownAppLaunchAd = false;
    _appLaunchAdState = AppLaunchAdState.notStarted;
    _isAppLaunchSequenceComplete = false;

    // Cancel and cleanup timeout timer
    if (_appLaunchAdTimeout != null) {
      _appLaunchAdTimeout!.cancel();
      _appLaunchAdTimeout = null;
      _logger.i('App launch ad timeout timer cancelled during session reset');
    }

    _logger.i(
      'App launch ad flags reset for new session - New state: $_appLaunchAdState, Sequence complete: $_isAppLaunchSequenceComplete, Ad shown: $_hasShownAppLaunchAd',
    );
    notifyListeners();
  }

  /// Handle app lifecycle state changes for session management
  /// This should be called when the app comes to foreground to reset ad flags
  void handleAppLifecycleChange(AppLifecycleState state) {
    try {
      _logger.d('App lifecycle state changed to: $state');

      switch (state) {
        case AppLifecycleState.resumed:
          // App comes to foreground - reset ad flags for new session
          _logger.i('App resumed - resetting app launch ad for new session');
          resetAppLaunchAdForNewSession();
          break;
        case AppLifecycleState.inactive:
        case AppLifecycleState.paused:
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
          // App goes to background - no action needed for ad flags
          // The flags will be reset when app comes back to foreground
          _logger.d(
            'App went to background - ad flags will reset on next resume',
          );
          break;
      }
    } catch (e) {
      _logger.e('Error handling app lifecycle change: $e');
      // Ensure app continues functioning even if lifecycle handling fails
    }
  }

  /// Check if app launch sequence is currently in progress
  bool isAppLaunchSequenceInProgress() {
    final bool inProgress =
        _appLaunchAdState == AppLaunchAdState.loading ||
        _appLaunchAdState == AppLaunchAdState.showing;

    _logger.d(
      'App launch sequence in progress check - State: $_appLaunchAdState, In progress: $inProgress',
    );
    return inProgress;
  }

  /// Get detailed state information for debugging and coordination
  Map<String, dynamic> getAppLaunchAdStateInfo() {
    return {
      'state': _appLaunchAdState.toString(),
      'sequenceComplete': _isAppLaunchSequenceComplete,
      'adShown': _hasShownAppLaunchAd,
      'timeoutActive': _appLaunchAdTimeout != null,
      'inProgress': isAppLaunchSequenceInProgress(),
    };
  }

  /// Add a listener specifically for app launch sequence completion
  void addAppLaunchSequenceListener(VoidCallback listener) {
    // Store the listener to be called when sequence completes
    // This could be enhanced with a proper listener management system
    addListener(listener);
  }

  /// Remove a listener for app launch sequence completion
  void removeAppLaunchSequenceListener(VoidCallback listener) {
    removeListener(listener);
  }

  /// Start the app launch ad sequence with automatic timeout
  void startAppLaunchAdSequence([VoidCallback? onTimeout]) {
    try {
      _logger.i(
        'Starting app launch ad sequence - Current state: $_appLaunchAdState',
      );

      // Ensure we're in a valid state to start the sequence
      if (_appLaunchAdState == AppLaunchAdState.loading ||
          _appLaunchAdState == AppLaunchAdState.showing) {
        _logger.w(
          'App launch ad sequence already in progress, ignoring start request',
        );
        return;
      }

      // Reset sequence state
      _appLaunchAdState = AppLaunchAdState.loading;
      _isAppLaunchSequenceComplete = false;

      // Automatically set timeout when starting sequence
      setAppLaunchAdTimeout(onTimeout);

      _logger.i(
        'App launch ad sequence started successfully - State: $_appLaunchAdState',
      );
      notifyListeners();
    } catch (e) {
      _logger.e('Error starting app launch ad sequence: $e');
      // Ensure app continues functioning by completing sequence
      _appLaunchAdState = AppLaunchAdState.failed;
      _completeAppLaunchSequenceInternal();
      notifyListeners();
    }
  }

  /// Complete the app launch ad sequence and notify all listeners
  void completeAppLaunchAdSequence() {
    try {
      _logger.i(
        'Completing app launch ad sequence - Current state: $_appLaunchAdState',
      );

      // Only complete if we're in a valid state
      if (_appLaunchAdState == AppLaunchAdState.completed) {
        _logger.w(
          'App launch ad sequence already completed, ignoring complete request',
        );
        return;
      }

      // Set state to completed
      _appLaunchAdState = AppLaunchAdState.completed;

      // Complete internal sequence management
      _completeAppLaunchSequenceInternal();

      _logger.i(
        'App launch ad sequence completed successfully - State: $_appLaunchAdState, Sequence complete: $_isAppLaunchSequenceComplete',
      );

      // Notify all listeners about the completion
      notifyListeners();
    } catch (e) {
      _logger.e('Error completing app launch ad sequence: $e');
      // Force completion to ensure app continues functioning
      try {
        _appLaunchAdState = AppLaunchAdState.completed;
        _completeAppLaunchSequenceInternal();
        notifyListeners();
      } catch (fallbackError) {
        _logger.e(
          'Critical error in app launch sequence completion fallback: $fallbackError',
        );
        // Last resort: force reset to allow app to continue
        _appLaunchAdState = AppLaunchAdState.notStarted;
        _isAppLaunchSequenceComplete = true;
        _hasShownAppLaunchAd = true;
      }
    }
  }

  /// Set app launch ad timeout with 5-second default timeout
  void setAppLaunchAdTimeout([VoidCallback? onTimeout]) {
    try {
      const Duration defaultTimeout = Duration(seconds: 5);

      // Cancel any existing timeout
      _appLaunchAdTimeout?.cancel();

      _appLaunchAdTimeout = Timer(defaultTimeout, () {
        try {
          _handleAppLaunchAdTimeout(onTimeout);
        } catch (e) {
          _logger.e('Error in app launch ad timeout handler: $e');
          // Ensure app continues functioning even if timeout handler fails
          try {
            _appLaunchAdState = AppLaunchAdState.timedOut;
            _completeAppLaunchSequenceInternal();
            onTimeout?.call();
            notifyListeners();
          } catch (fallbackError) {
            _logger.e('Critical error in timeout fallback: $fallbackError');
          }
        }
      });

      _logger.i(
        'App launch ad timeout set for ${defaultTimeout.inSeconds} seconds',
      );
    } catch (e) {
      _logger.e('Error setting app launch ad timeout: $e');
      // If we can't set timeout, complete sequence immediately to avoid hanging
      _appLaunchAdState = AppLaunchAdState.failed;
      _completeAppLaunchSequenceInternal();
      onTimeout?.call();
      notifyListeners();
    }
  }

  /// Handle app launch ad timeout with proper state management
  void _handleAppLaunchAdTimeout([VoidCallback? onTimeout]) {
    _logger.w(
      'App launch ad timeout triggered - Current state: $_appLaunchAdState',
    );

    if (_appLaunchAdState == AppLaunchAdState.loading ||
        _appLaunchAdState == AppLaunchAdState.showing) {
      _logger.w('App launch ad timed out, proceeding with normal app flow');

      // Set state to timed out
      _appLaunchAdState = AppLaunchAdState.timedOut;

      // Complete the sequence to allow normal app flow
      _completeAppLaunchSequenceInternal();

      // Execute timeout callback if provided
      onTimeout?.call();

      _logger.i(
        'App launch ad timeout handled - State: $_appLaunchAdState, Sequence complete: $_isAppLaunchSequenceComplete',
      );

      // Notify listeners of state change
      notifyListeners();
    } else {
      _logger.i(
        'App launch ad timeout ignored - not in loading/showing state: $_appLaunchAdState',
      );
    }
  }

  /// Internal method to complete app launch sequence with proper cleanup
  void _completeAppLaunchSequenceInternal() {
    _logger.i(
      'Completing app launch sequence internally - Current flags: sequence complete: $_isAppLaunchSequenceComplete, ad shown: $_hasShownAppLaunchAd',
    );

    _isAppLaunchSequenceComplete = true;
    _hasShownAppLaunchAd = true; // Mark as shown to prevent retry loops

    // Cancel and cleanup timeout timer
    if (_appLaunchAdTimeout != null) {
      _appLaunchAdTimeout!.cancel();
      _appLaunchAdTimeout = null;
      _logger.i('App launch ad timeout timer cancelled and cleaned up');
    }

    _logger.i(
      'App launch ad sequence completed internally - Final flags: sequence complete: $_isAppLaunchSequenceComplete, ad shown: $_hasShownAppLaunchAd',
    );
  }

  /// Set app launch ad state with proper transitions and cleanup
  void setAppLaunchAdState(AppLaunchAdState state) {
    final AppLaunchAdState previousState = _appLaunchAdState;

    _logger.i('App launch ad state transition: $previousState -> $state');

    // Validate state transitions
    if (!_isValidStateTransition(previousState, state)) {
      _logger.w(
        'Invalid state transition from $previousState to $state, allowing anyway',
      );
    }

    _appLaunchAdState = state;

    // Handle state-specific logic and cleanup
    _handleStateTransition(previousState, state);

    _logger.i('App launch ad state successfully changed to: $state');
    notifyListeners();
  }

  /// Validate if a state transition is allowed
  bool _isValidStateTransition(AppLaunchAdState from, AppLaunchAdState to) {
    // Define valid transitions
    switch (from) {
      case AppLaunchAdState.notStarted:
        return to == AppLaunchAdState.loading;
      case AppLaunchAdState.loading:
        return to == AppLaunchAdState.showing ||
            to == AppLaunchAdState.failed ||
            to == AppLaunchAdState.timedOut;
      case AppLaunchAdState.showing:
        return to == AppLaunchAdState.completed ||
            to == AppLaunchAdState.failed;
      case AppLaunchAdState.completed:
      case AppLaunchAdState.failed:
      case AppLaunchAdState.timedOut:
        return to == AppLaunchAdState.notStarted; // Allow reset
    }
  }

  /// Handle state transition logic and cleanup
  void _handleStateTransition(AppLaunchAdState from, AppLaunchAdState to) {
    switch (to) {
      case AppLaunchAdState.loading:
        // Starting to load - ensure sequence is not marked as complete
        _isAppLaunchSequenceComplete = false;
        break;

      case AppLaunchAdState.showing:
        // Ad is now showing - cancel timeout as ad loaded successfully
        _appLaunchAdTimeout?.cancel();
        _appLaunchAdTimeout = null;
        _logger.i('App launch ad timeout cancelled - ad is showing');
        break;

      case AppLaunchAdState.completed:
        // Ad completed successfully
        _completeAppLaunchSequenceInternal();
        break;

      case AppLaunchAdState.failed:
        // Handle failure with recovery
        _handleAppLaunchAdFailure();
        break;

      case AppLaunchAdState.timedOut:
        // Timeout already handled in timeout callback
        break;

      case AppLaunchAdState.notStarted:
        // Reset state - cleanup everything
        _isAppLaunchSequenceComplete = false;
        _appLaunchAdTimeout?.cancel();
        _appLaunchAdTimeout = null;
        _logger.i(
          'App launch ad state reset to notStarted - all cleanup completed',
        );
        break;
    }
  }

  /// Handle app launch ad failure with recovery mechanism
  void _handleAppLaunchAdFailure() {
    try {
      _logger.w(
        'App launch ad failed, initiating recovery mechanism - State: $_appLaunchAdState',
      );

      // Complete the sequence to allow normal app flow
      _completeAppLaunchSequenceInternal();

      _logger.i(
        'App launch ad failure recovery completed - app flow can continue normally',
      );

      // Additional recovery actions can be added here if needed
      // For example: retry logic, fallback ad types, etc.
    } catch (e) {
      _logger.e('Error in app launch ad failure recovery: $e');
      // Critical fallback to ensure app continues functioning
      try {
        _isAppLaunchSequenceComplete = true;
        _hasShownAppLaunchAd = true;
        _appLaunchAdTimeout?.cancel();
        _appLaunchAdTimeout = null;
        _logger.i('Critical fallback completed for app launch ad failure');
      } catch (criticalError) {
        _logger.e(
          'Critical error in app launch ad failure fallback: $criticalError',
        );
        // At this point, we've done everything we can to recover
      }
    }
  }

  /// Force complete app launch sequence (emergency recovery)
  void forceCompleteAppLaunchSequence() {
    _logger.w('Force completing app launch ad sequence');

    // Set state to completed regardless of current state
    _appLaunchAdState = AppLaunchAdState.completed;
    _completeAppLaunchSequenceInternal();

    notifyListeners();
  }

  /// Check if app launch ad is in a recoverable state
  bool isAppLaunchAdRecoverable() {
    return _appLaunchAdState == AppLaunchAdState.failed ||
        _appLaunchAdState == AppLaunchAdState.timedOut ||
        (_appLaunchAdState == AppLaunchAdState.loading &&
            _appLaunchAdTimeout == null);
  }

  /// Clear all native ad permissions (useful for cleanup)
  void clearAllNativeAdPermissions() {
    try {
      _logger.i('Clearing all native ad permissions');
      _nativeAdLoadingScreens.clear();
      _currentNativeAdScreen = null;
    } catch (e) {
      _logger.e('Error clearing native ad permissions: $e');
    }
  }

  @override
  void dispose() {
    // Cancel and cleanup timeout timer
    _appLaunchAdTimeout?.cancel();
    _appLaunchAdTimeout = null;

    // Clear native ad permissions
    clearAllNativeAdPermissions();

    // Log disposal for debugging
    _logger.i('AdMobProvider disposed, timeout timer cleaned up');

    super.dispose();
  }
}
