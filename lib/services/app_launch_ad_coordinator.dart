import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/admob_provider.dart';
import '../services/admob_service.dart';

/// Centralized coordinator for managing app launch ads
/// Handles timing, state management, and coordination with other ad types
class AppLaunchAdCoordinator {
  static final Logger _logger = Logger();
  static bool _isAdLoading = false;

  /// Main entry point for handling app launch ads
  ///
  /// [context] - BuildContext for navigation and provider access
  /// [user] - Current user to check premium status
  /// [onComplete] - Callback to execute after ad sequence completes
  static Future<void> handleAppLaunchAd({
    required BuildContext context,
    required ChessUser user,
    required VoidCallback onComplete,
  }) async {
    try {
      _logger.i('Starting app launch ad sequence for user: ${user.uid}');

      // Validate inputs
      if (user.uid == null || user.uid!.isEmpty) {
        _logger.w('Invalid user ID, skipping app launch ad');
        onComplete();
        return;
      }

      AdMobProvider? adMobProvider;
      try {
        adMobProvider = Provider.of<AdMobProvider>(context, listen: false);
      } catch (providerError) {
        _logger.e('Error accessing AdMobProvider: $providerError');
        onComplete();
        return;
      }

      // Check if we should show the ad
      if (!shouldShowAppLaunchAd(user, adMobProvider)) {
        _logger.i('App launch ad not needed, proceeding with normal flow');
        onComplete();
        return;
      }

      _logger.i('App launch ad should be shown, starting sequence');

      // Start the app launch ad sequence with error handling
      try {
        adMobProvider.startAppLaunchAdSequence(() {
          _logger.w('App launch ad timed out, proceeding with callback');
          try {
            onComplete();
          } catch (callbackError) {
            _logger.e('Error in timeout callback: $callbackError');
          }
        });
      } catch (sequenceError) {
        _logger.e('Error starting app launch ad sequence: $sequenceError');
        onComplete();
        return;
      }

      // Load and show the ad
      await _loadAndShowAd(context, user, adMobProvider, onComplete);
    } catch (e) {
      _logger.e('Critical error in app launch ad sequence: $e');
      // Ensure we always call the completion callback
      try {
        onComplete();
      } catch (callbackError) {
        _logger.e('Error in completion callback: $callbackError');
      }
    }
  }

  /// Determines if an app launch ad should be shown
  ///
  /// [user] - Current user to check premium status
  /// [adMobProvider] - Provider to check ad configuration
  static bool shouldShowAppLaunchAd(
    ChessUser user,
    AdMobProvider adMobProvider,
  ) {
    try {
      // Validate inputs
      if (user.uid == null || user.uid!.isEmpty) {
        _logger.w('Invalid user, skipping app launch ad');
        return false;
      }

      // Don't show if user has premium (removeAds = true)
      if (user.removeAds == true) {
        _logger.i('User has premium, skipping app launch ad');
        return false;
      }

      // Don't show if ads are disabled in configuration
      try {
        if (!adMobProvider.shouldShowAds(user.removeAds)) {
          _logger.i('Ads disabled in configuration, skipping app launch ad');
          return false;
        }
      } catch (configError) {
        _logger.e('Error checking ad configuration: $configError');
        return false;
      }

      // Don't show if already shown in this session
      try {
        if (adMobProvider.hasShownAppLaunchAd) {
          _logger.i('App launch ad already shown this session');
          return false;
        }
      } catch (stateError) {
        _logger.e('Error checking app launch ad state: $stateError');
        return false;
      }

      // Don't show if sequence is already in progress
      try {
        if (adMobProvider.isAppLaunchSequenceInProgress()) {
          _logger.i('App launch ad sequence already in progress');
          return false;
        }
      } catch (progressError) {
        _logger.e(
          'Error checking app launch sequence progress: $progressError',
        );
        return false;
      }

      // Check if app open ad unit ID is available
      try {
        final appOpenAdUnitId = adMobProvider.appOpenAdUnitId;
        if (appOpenAdUnitId == null || appOpenAdUnitId.isEmpty) {
          _logger.w(
            'App open ad unit ID not available, skipping app launch ad',
          );
          return false;
        }
      } catch (adUnitError) {
        _logger.e('Error checking app open ad unit ID: $adUnitError');
        return false;
      }

      _logger.i('App launch ad should be shown for new session');
      return true;
    } catch (e) {
      _logger.e('Error determining if app launch ad should be shown: $e');
      // Default to not showing ads if there's an error
      return false;
    }
  }

  /// Internal method to load and show the app open ad
  static Future<void> _loadAndShowAd(
    BuildContext context,
    ChessUser user,
    AdMobProvider adMobProvider,
    VoidCallback onComplete,
  ) async {
    try {
      // Prevent multiple simultaneous loads
      if (_isAdLoading) {
        _logger.w('Ad already loading, skipping duplicate request');
        _completeSequence(adMobProvider, onComplete);
        return;
      }

      _isAdLoading = true;

      _logger.i('Loading app launch app open ad');

      // Update state to showing with error handling
      try {
        adMobProvider.setAppLaunchAdState(AppLaunchAdState.showing);
      } catch (stateError) {
        _logger.e('Error setting app launch ad state to showing: $stateError');
        // Continue with showing the ad even if state update fails
      }

      // Use AdMobService to load and show the app open ad
      await AdMobService.loadAndShowAppOpenAd(
        context: context,
        onAdClosed: () {
          try {
            _logger.i('App launch app open ad closed');
            _completeSequence(adMobProvider, onComplete);
          } catch (e) {
            _logger.e('Error in app open ad closed callback: $e');
            _completeSequence(adMobProvider, onComplete);
          }
        },
        onAdFailedToLoad: () {
          try {
            _logger.w('App launch app open ad failed to load');
            _completeSequence(adMobProvider, onComplete);
          } catch (e) {
            _logger.e('Error in app open ad failed callback: $e');
            _completeSequence(adMobProvider, onComplete);
          }
        },
      );
    } catch (e) {
      _logger.e('Critical error loading app launch ad: $e');
      _completeSequence(adMobProvider, onComplete);
    } finally {
      _isAdLoading = false;
    }
  }

  /// Completes the app launch ad sequence and calls the completion callback
  static void _completeSequence(
    AdMobProvider adMobProvider,
    VoidCallback onComplete,
  ) {
    try {
      _logger.i('Completing app launch ad sequence');

      // Mark the sequence as complete with error handling
      try {
        adMobProvider.completeAppLaunchAdSequence();
      } catch (sequenceError) {
        _logger.e('Error completing app launch ad sequence: $sequenceError');
        // Try force completion as fallback
        try {
          adMobProvider.forceCompleteAppLaunchSequence();
        } catch (forceError) {
          _logger.e(
            'Error force completing app launch ad sequence: $forceError',
          );
        }
      }

      // Clean up loading state
      _isAdLoading = false;

      // Execute the completion callback with error handling
      try {
        onComplete();
      } catch (callbackError) {
        _logger.e('Error in completion callback: $callbackError');
        // Don't rethrow - we've done our best to complete the sequence
      }
    } catch (e) {
      _logger.e('Critical error completing app launch ad sequence: $e');
      // Ensure basic cleanup even in critical error
      try {
        _isAdLoading = false;
        onComplete();
      } catch (criticalError) {
        _logger.e(
          'Critical error in sequence completion fallback: $criticalError',
        );
      }
    }
  }

  /// Force complete the ad sequence (emergency recovery)
  static void forceComplete(
    AdMobProvider adMobProvider,
    VoidCallback onComplete,
  ) {
    try {
      _logger.w('Force completing app launch ad sequence');

      // Clean up any loading state
      _isAdLoading = false;

      // Force complete the provider sequence
      try {
        adMobProvider.forceCompleteAppLaunchSequence();
      } catch (forceError) {
        _logger.e('Error force completing provider sequence: $forceError');
      }

      // Execute callback
      try {
        onComplete();
      } catch (callbackError) {
        _logger.e('Error in force complete callback: $callbackError');
      }
    } catch (e) {
      _logger.e('Critical error in force complete: $e');
      // Last resort cleanup
      _isAdLoading = false;
      try {
        onComplete();
      } catch (criticalCallbackError) {
        _logger.e(
          'Critical error in force complete callback: $criticalCallbackError',
        );
      }
    }
  }

  /// Check if the coordinator is currently processing an ad
  static bool get isProcessing => _isAdLoading;

  /// Dispose of any resources (call on app disposal)
  static void dispose() {
    try {
      _logger.i('Disposing AppLaunchAdCoordinator resources');

      _isAdLoading = false;

      _logger.i('AppLaunchAdCoordinator resources disposed successfully');
    } catch (e) {
      _logger.e('Error disposing AppLaunchAdCoordinator resources: $e');
      // Ensure basic cleanup even if there's an error
      _isAdLoading = false;
    }
  }
}
