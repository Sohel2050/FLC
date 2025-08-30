import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/admob_provider.dart';

/// Centralized coordinator for managing app launch interstitial ads
/// Handles timing, state management, and coordination with other ad types
class AppLaunchAdCoordinator {
  static final Logger _logger = Logger();
  static InterstitialAd? _interstitialAd;
  static bool _isAdLoading = false;

  /// Configuration for ad coordinator behavior
  static const Duration _loadTimeout = Duration(seconds: 5);
  static const Duration _showDelay = Duration(milliseconds: 500);

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

      _logger.i('App launch ad should be shown for new session');
      return true;
    } catch (e) {
      _logger.e('Error determining if app launch ad should be shown: $e');
      // Default to not showing ads if there's an error
      return false;
    }
  }

  /// Internal method to load and show the interstitial ad
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

      // Get the interstitial ad unit ID with error handling
      String? adUnitId;
      try {
        adUnitId = adMobProvider.interstitialAdUnitId;
      } catch (e) {
        _logger.e('Error getting interstitial ad unit ID: $e');
        _completeSequence(adMobProvider, onComplete);
        return;
      }

      if (adUnitId == null || adUnitId.isEmpty) {
        _logger.w('No interstitial ad unit ID available or empty');
        _completeSequence(adMobProvider, onComplete);
        return;
      }

      _logger.i('Loading app launch interstitial ad with ID: $adUnitId');

      // Create a completer for timeout handling
      final Completer<void> loadCompleter = Completer<void>();
      Timer? timeoutTimer;

      try {
        // Set up timeout with error handling
        timeoutTimer = Timer(_loadTimeout, () {
          if (!loadCompleter.isCompleted) {
            _logger.w(
              'App launch ad load timed out after ${_loadTimeout.inSeconds} seconds',
            );
            try {
              loadCompleter.complete();
              _completeSequence(adMobProvider, onComplete);
            } catch (timeoutError) {
              _logger.e('Error in timeout handler: $timeoutError');
            }
          }
        });

        // Load the interstitial ad with comprehensive error handling
        await InterstitialAd.load(
          adUnitId: adUnitId,
          request: const AdRequest(),
          adLoadCallback: InterstitialAdLoadCallback(
            onAdLoaded: (InterstitialAd ad) {
              try {
                _logger.i('App launch interstitial ad loaded successfully');
                _interstitialAd = ad;

                if (!loadCompleter.isCompleted) {
                  loadCompleter.complete();
                  _showLoadedAd(context, adMobProvider, onComplete);
                } else {
                  // Completer already completed, dispose the ad
                  ad.dispose();
                  _logger.w(
                    'Ad loaded but completer already completed, disposing ad',
                  );
                }
              } catch (e) {
                _logger.e('Error in onAdLoaded callback: $e');
                ad.dispose();
                if (!loadCompleter.isCompleted) {
                  loadCompleter.complete();
                  _completeSequence(adMobProvider, onComplete);
                }
              }
            },
            onAdFailedToLoad: (LoadAdError error) {
              try {
                _logger.e(
                  'App launch interstitial ad failed to load: ${error.message} (Code: ${error.code})',
                );

                if (!loadCompleter.isCompleted) {
                  loadCompleter.complete();
                  _completeSequence(adMobProvider, onComplete);
                }
              } catch (e) {
                _logger.e('Error in onAdFailedToLoad callback: $e');
                if (!loadCompleter.isCompleted) {
                  loadCompleter.complete();
                  _completeSequence(adMobProvider, onComplete);
                }
              }
            },
          ),
        );

        // Wait for load completion or timeout
        await loadCompleter.future;
      } catch (loadError) {
        _logger.e('Error during InterstitialAd.load: $loadError');
        if (!loadCompleter.isCompleted) {
          loadCompleter.complete();
        }
        _completeSequence(adMobProvider, onComplete);
      } finally {
        // Clean up timeout timer
        try {
          timeoutTimer?.cancel();
        } catch (e) {
          _logger.e('Error canceling timeout timer: $e');
        }
      }
    } catch (e) {
      _logger.e('Critical error loading app launch ad: $e');
      _completeSequence(adMobProvider, onComplete);
    } finally {
      _isAdLoading = false;
    }
  }

  /// Shows the loaded interstitial ad
  static void _showLoadedAd(
    BuildContext context,
    AdMobProvider adMobProvider,
    VoidCallback onComplete,
  ) {
    try {
      if (_interstitialAd == null) {
        _logger.w('No ad to show, completing sequence');
        _completeSequence(adMobProvider, onComplete);
        return;
      }

      _logger.i('Showing app launch interstitial ad');

      // Update state to showing with error handling
      try {
        adMobProvider.setAppLaunchAdState(AppLaunchAdState.showing);
      } catch (stateError) {
        _logger.e('Error setting app launch ad state to showing: $stateError');
        // Continue with showing the ad even if state update fails
      }

      // Set up ad callbacks with comprehensive error handling
      try {
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (InterstitialAd ad) {
            try {
              _logger.i(
                'App launch interstitial ad showed full screen content',
              );
            } catch (e) {
              _logger.e('Error in onAdShowedFullScreenContent callback: $e');
            }
          },
          onAdDismissedFullScreenContent: (InterstitialAd ad) {
            try {
              _logger.i('App launch interstitial ad dismissed');
              ad.dispose();
              _interstitialAd = null;
              _completeSequence(adMobProvider, onComplete);
            } catch (e) {
              _logger.e('Error in onAdDismissedFullScreenContent callback: $e');
              // Ensure cleanup even if there's an error
              try {
                ad.dispose();
                _interstitialAd = null;
                _completeSequence(adMobProvider, onComplete);
              } catch (cleanupError) {
                _logger.e('Error in ad dismissal cleanup: $cleanupError');
                _completeSequence(adMobProvider, onComplete);
              }
            }
          },
          onAdFailedToShowFullScreenContent: (
            InterstitialAd ad,
            AdError error,
          ) {
            try {
              _logger.e(
                'App launch interstitial ad failed to show: ${error.message} (Code: ${error.code})',
              );
              ad.dispose();
              _interstitialAd = null;
              _completeSequence(adMobProvider, onComplete);
            } catch (e) {
              _logger.e(
                'Error in onAdFailedToShowFullScreenContent callback: $e',
              );
              // Ensure cleanup even if there's an error
              try {
                ad.dispose();
                _interstitialAd = null;
                _completeSequence(adMobProvider, onComplete);
              } catch (cleanupError) {
                _logger.e('Error in ad show failure cleanup: $cleanupError');
                _completeSequence(adMobProvider, onComplete);
              }
            }
          },
        );
      } catch (callbackError) {
        _logger.e('Error setting up ad callbacks: $callbackError');
        // If we can't set up callbacks, dispose the ad and complete
        try {
          _interstitialAd?.dispose();
          _interstitialAd = null;
        } catch (disposeError) {
          _logger.e(
            'Error disposing ad after callback setup failure: $disposeError',
          );
        }
        _completeSequence(adMobProvider, onComplete);
        return;
      }

      // Show the ad with a small delay for better UX
      try {
        Future.delayed(_showDelay, () {
          try {
            _interstitialAd?.show();
          } catch (showError) {
            _logger.e('Error showing interstitial ad: $showError');
            // Clean up and complete sequence if show fails
            try {
              _interstitialAd?.dispose();
              _interstitialAd = null;
            } catch (disposeError) {
              _logger.e('Error disposing ad after show failure: $disposeError');
            }
            _completeSequence(adMobProvider, onComplete);
          }
        });
      } catch (delayError) {
        _logger.e('Error setting up delayed ad show: $delayError');
        // Try to show immediately as fallback
        try {
          _interstitialAd?.show();
        } catch (immediateShowError) {
          _logger.e(
            'Error showing ad immediately after delay failure: $immediateShowError',
          );
          try {
            _interstitialAd?.dispose();
            _interstitialAd = null;
          } catch (disposeError) {
            _logger.e(
              'Error disposing ad after immediate show failure: $disposeError',
            );
          }
          _completeSequence(adMobProvider, onComplete);
        }
      }
    } catch (e) {
      _logger.e('Critical error showing loaded ad: $e');
      // Ensure cleanup and completion even in critical error
      try {
        _interstitialAd?.dispose();
        _interstitialAd = null;
      } catch (disposeError) {
        _logger.e(
          'Error disposing ad in critical error handler: $disposeError',
        );
      }
      _completeSequence(adMobProvider, onComplete);
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

      // Clean up any remaining ad instance
      try {
        _interstitialAd?.dispose();
        _interstitialAd = null;
      } catch (disposeError) {
        _logger.e('Error disposing interstitial ad: $disposeError');
        _interstitialAd = null; // Set to null even if dispose fails
      }

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
        _interstitialAd = null;
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

      try {
        _interstitialAd?.dispose();
      } catch (disposeError) {
        _logger.e('Error disposing ad during force complete: $disposeError');
      }
      _interstitialAd = null;

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
      _interstitialAd = null;
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
  static bool get isProcessing => _isAdLoading || _interstitialAd != null;

  /// Dispose of any resources (call on app disposal)
  static void dispose() {
    try {
      _logger.i('Disposing AppLaunchAdCoordinator resources');

      try {
        _interstitialAd?.dispose();
      } catch (disposeError) {
        _logger.e(
          'Error disposing interstitial ad during coordinator disposal: $disposeError',
        );
      }

      _interstitialAd = null;
      _isAdLoading = false;

      _logger.i('AppLaunchAdCoordinator resources disposed successfully');
    } catch (e) {
      _logger.e('Error disposing AppLaunchAdCoordinator resources: $e');
      // Ensure basic cleanup even if there's an error
      _interstitialAd = null;
      _isAdLoading = false;
    }
  }
}
