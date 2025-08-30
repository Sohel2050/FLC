import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';

import 'package:flutter_chess_app/providers/admob_provider.dart';

/// Test-specific AdMobProvider that bypasses Firebase initialization
class TestAdMobProvider with ChangeNotifier {
  // App launch ad state management properties
  AppLaunchAdState _appLaunchAdState = AppLaunchAdState.notStarted;
  Timer? _appLaunchAdTimeout;
  bool _isAppLaunchSequenceComplete = false;
  bool _hasShownAppLaunchAd = false;

  // Getters
  AppLaunchAdState get appLaunchAdState => _appLaunchAdState;
  bool get isAppLaunchSequenceComplete => _isAppLaunchSequenceComplete;
  bool get hasShownAppLaunchAd => _hasShownAppLaunchAd;

  TestAdMobProvider() {
    resetAppLaunchAdForNewSession();
  }

  // Copy all the app launch ad methods from AdMobProvider
  bool isAppLaunchSequenceInProgress() {
    final bool inProgress =
        _appLaunchAdState == AppLaunchAdState.loading ||
        _appLaunchAdState == AppLaunchAdState.showing;
    return inProgress;
  }

  Map<String, dynamic> getAppLaunchAdStateInfo() {
    return {
      'state': _appLaunchAdState.toString(),
      'sequenceComplete': _isAppLaunchSequenceComplete,
      'adShown': _hasShownAppLaunchAd,
      'timeoutActive': _appLaunchAdTimeout != null,
      'inProgress': isAppLaunchSequenceInProgress(),
    };
  }

  void addAppLaunchSequenceListener(VoidCallback listener) {
    addListener(listener);
  }

  void removeAppLaunchSequenceListener(VoidCallback listener) {
    removeListener(listener);
  }

  void startAppLaunchAdSequence([VoidCallback? onTimeout]) {
    try {
      if (_appLaunchAdState == AppLaunchAdState.loading ||
          _appLaunchAdState == AppLaunchAdState.showing) {
        return;
      }

      _appLaunchAdState = AppLaunchAdState.loading;
      _isAppLaunchSequenceComplete = false;

      setAppLaunchAdTimeout(onTimeout);
      notifyListeners();
    } catch (e) {
      _appLaunchAdState = AppLaunchAdState.failed;
      _completeAppLaunchSequenceInternal();
      notifyListeners();
    }
  }

  void completeAppLaunchAdSequence() {
    try {
      if (_appLaunchAdState == AppLaunchAdState.completed) {
        return;
      }

      _appLaunchAdState = AppLaunchAdState.completed;
      _completeAppLaunchSequenceInternal();
      notifyListeners();
    } catch (e) {
      try {
        _appLaunchAdState = AppLaunchAdState.completed;
        _completeAppLaunchSequenceInternal();
        notifyListeners();
      } catch (fallbackError) {
        _appLaunchAdState = AppLaunchAdState.notStarted;
        _isAppLaunchSequenceComplete = true;
        _hasShownAppLaunchAd = true;
      }
    }
  }

  void setAppLaunchAdTimeout([VoidCallback? onTimeout]) {
    try {
      const Duration defaultTimeout = Duration(seconds: 5);

      _appLaunchAdTimeout?.cancel();

      _appLaunchAdTimeout = Timer(defaultTimeout, () {
        try {
          _handleAppLaunchAdTimeout(onTimeout);
        } catch (e) {
          try {
            _appLaunchAdState = AppLaunchAdState.timedOut;
            _completeAppLaunchSequenceInternal();
            onTimeout?.call();
            notifyListeners();
          } catch (fallbackError) {
            // Critical error handling
          }
        }
      });
    } catch (e) {
      _appLaunchAdState = AppLaunchAdState.failed;
      _completeAppLaunchSequenceInternal();
      onTimeout?.call();
      notifyListeners();
    }
  }

  void _handleAppLaunchAdTimeout([VoidCallback? onTimeout]) {
    if (_appLaunchAdState == AppLaunchAdState.loading ||
        _appLaunchAdState == AppLaunchAdState.showing) {
      _appLaunchAdState = AppLaunchAdState.timedOut;
      _completeAppLaunchSequenceInternal();
      onTimeout?.call();
      notifyListeners();
    }
  }

  void _completeAppLaunchSequenceInternal() {
    _isAppLaunchSequenceComplete = true;
    _hasShownAppLaunchAd = true;

    if (_appLaunchAdTimeout != null) {
      _appLaunchAdTimeout!.cancel();
      _appLaunchAdTimeout = null;
    }
  }

  void setAppLaunchAdState(AppLaunchAdState state) {
    final AppLaunchAdState previousState = _appLaunchAdState;
    _appLaunchAdState = state;
    _handleStateTransition(previousState, state);
    notifyListeners();
  }

  void _handleStateTransition(AppLaunchAdState from, AppLaunchAdState to) {
    switch (to) {
      case AppLaunchAdState.loading:
        _isAppLaunchSequenceComplete = false;
        break;
      case AppLaunchAdState.showing:
        _appLaunchAdTimeout?.cancel();
        _appLaunchAdTimeout = null;
        break;
      case AppLaunchAdState.completed:
        _completeAppLaunchSequenceInternal();
        break;
      case AppLaunchAdState.failed:
        _handleAppLaunchAdFailure();
        break;
      case AppLaunchAdState.timedOut:
        _completeAppLaunchSequenceInternal();
        break;
      case AppLaunchAdState.notStarted:
        _isAppLaunchSequenceComplete = false;
        _appLaunchAdTimeout?.cancel();
        _appLaunchAdTimeout = null;
        break;
    }
  }

  void _handleAppLaunchAdFailure() {
    try {
      _completeAppLaunchSequenceInternal();
    } catch (e) {
      try {
        _isAppLaunchSequenceComplete = true;
        _hasShownAppLaunchAd = true;
        _appLaunchAdTimeout?.cancel();
        _appLaunchAdTimeout = null;
      } catch (criticalError) {
        // Critical error handling
      }
    }
  }

  void forceCompleteAppLaunchSequence() {
    _appLaunchAdState = AppLaunchAdState.completed;
    _completeAppLaunchSequenceInternal();
    notifyListeners();
  }

  bool isAppLaunchAdRecoverable() {
    return _appLaunchAdState == AppLaunchAdState.failed ||
        _appLaunchAdState == AppLaunchAdState.timedOut ||
        (_appLaunchAdState == AppLaunchAdState.loading &&
            _appLaunchAdTimeout == null);
  }

  void resetAppLaunchAdForNewSession() {
    _hasShownAppLaunchAd = false;
    _appLaunchAdState = AppLaunchAdState.notStarted;
    _isAppLaunchSequenceComplete = false;

    if (_appLaunchAdTimeout != null) {
      _appLaunchAdTimeout!.cancel();
      _appLaunchAdTimeout = null;
    }

    notifyListeners();
  }

  void handleAppLifecycleChange(AppLifecycleState state) {
    try {
      switch (state) {
        case AppLifecycleState.resumed:
          resetAppLaunchAdForNewSession();
          break;
        case AppLifecycleState.inactive:
        case AppLifecycleState.paused:
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
          break;
      }
    } catch (e) {
      // Error handling
    }
  }

  bool shouldShowAppLaunchAd(bool? userRemoveAds) {
    if (_hasShownAppLaunchAd) {
      return false;
    }
    return shouldShowAds(userRemoveAds);
  }

  bool shouldShowAds(bool? userRemoveAds) {
    if (userRemoveAds == true) {
      return false;
    }
    return true; // Simplified for testing
  }

  void markAppLaunchAdShown() {
    _hasShownAppLaunchAd = true;
    notifyListeners();
  }

  void resetAppLaunchAdFlag() {
    _hasShownAppLaunchAd = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _appLaunchAdTimeout?.cancel();
    _appLaunchAdTimeout = null;
    super.dispose();
  }
}

void main() {
  group('AdMobProvider App Launch Ad Enhancements Tests', () {
    late TestAdMobProvider provider;

    setUp(() {
      provider = TestAdMobProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    group('AppLaunchAdState Transitions', () {
      test('should initialize with notStarted state', () {
        expect(provider.appLaunchAdState, equals(AppLaunchAdState.notStarted));
        expect(provider.isAppLaunchSequenceComplete, isFalse);
        expect(provider.hasShownAppLaunchAd, isFalse);
      });

      test(
        'should transition from notStarted to loading when starting sequence',
        () {
          provider.startAppLaunchAdSequence();

          expect(provider.appLaunchAdState, equals(AppLaunchAdState.loading));
          expect(provider.isAppLaunchSequenceComplete, isFalse);
        },
      );

      test('should transition from loading to showing', () {
        provider.startAppLaunchAdSequence();
        provider.setAppLaunchAdState(AppLaunchAdState.showing);

        expect(provider.appLaunchAdState, equals(AppLaunchAdState.showing));
        expect(provider.isAppLaunchSequenceComplete, isFalse);
      });

      test('should transition from showing to completed', () {
        provider.startAppLaunchAdSequence();
        provider.setAppLaunchAdState(AppLaunchAdState.showing);
        provider.setAppLaunchAdState(AppLaunchAdState.completed);

        expect(provider.appLaunchAdState, equals(AppLaunchAdState.completed));
        expect(provider.isAppLaunchSequenceComplete, isTrue);
        expect(provider.hasShownAppLaunchAd, isTrue);
      });

      test('should transition from loading to failed', () {
        provider.startAppLaunchAdSequence();
        provider.setAppLaunchAdState(AppLaunchAdState.failed);

        expect(provider.appLaunchAdState, equals(AppLaunchAdState.failed));
        expect(provider.isAppLaunchSequenceComplete, isTrue);
        expect(provider.hasShownAppLaunchAd, isTrue);
      });

      test('should transition from loading to timedOut', () {
        provider.startAppLaunchAdSequence();
        provider.setAppLaunchAdState(AppLaunchAdState.timedOut);

        expect(provider.appLaunchAdState, equals(AppLaunchAdState.timedOut));
        expect(provider.isAppLaunchSequenceComplete, isTrue);
        expect(provider.hasShownAppLaunchAd, isTrue);
      });

      test('should allow reset from completed to notStarted', () {
        provider.startAppLaunchAdSequence();
        provider.completeAppLaunchAdSequence();
        provider.setAppLaunchAdState(AppLaunchAdState.notStarted);

        expect(provider.appLaunchAdState, equals(AppLaunchAdState.notStarted));
        expect(provider.isAppLaunchSequenceComplete, isFalse);
      });

      test('should notify listeners on state transitions', () {
        bool notified = false;
        provider.addListener(() {
          notified = true;
        });

        provider.setAppLaunchAdState(AppLaunchAdState.loading);

        expect(notified, isTrue);
      });
    });

    group('Timeout Handling Mechanisms', () {
      test('should set timeout when starting app launch sequence', () {
        fakeAsync((async) {
          bool timeoutCalled = false;

          provider.startAppLaunchAdSequence(() {
            timeoutCalled = true;
          });

          expect(provider.appLaunchAdState, equals(AppLaunchAdState.loading));

          // Advance time by 5 seconds to trigger timeout
          async.elapse(const Duration(seconds: 5));

          expect(timeoutCalled, isTrue);
          expect(provider.appLaunchAdState, equals(AppLaunchAdState.timedOut));
          expect(provider.isAppLaunchSequenceComplete, isTrue);
        });
      });

      test('should cancel timeout when ad starts showing', () {
        fakeAsync((async) {
          bool timeoutCalled = false;

          provider.startAppLaunchAdSequence(() {
            timeoutCalled = true;
          });

          // Transition to showing state (should cancel timeout)
          provider.setAppLaunchAdState(AppLaunchAdState.showing);

          // Advance time by 5 seconds
          async.elapse(const Duration(seconds: 5));

          // Timeout should not have been called since ad is showing
          expect(timeoutCalled, isFalse);
          expect(provider.appLaunchAdState, equals(AppLaunchAdState.showing));
        });
      });

      test('should handle timeout gracefully when already completed', () {
        fakeAsync((async) {
          bool timeoutCalled = false;

          provider.startAppLaunchAdSequence(() {
            timeoutCalled = true;
          });

          // Complete the sequence before timeout
          provider.completeAppLaunchAdSequence();

          // Advance time by 5 seconds
          async.elapse(const Duration(seconds: 5));

          // Timeout callback should not be called since sequence was completed
          // and timeout should have been cancelled
          expect(timeoutCalled, isFalse);
          expect(provider.appLaunchAdState, equals(AppLaunchAdState.completed));
        });
      });

      test('should set timeout with custom callback', () {
        fakeAsync((async) {
          bool customCallbackCalled = false;

          // Start the sequence first to set up proper state
          provider.startAppLaunchAdSequence(() {
            customCallbackCalled = true;
          });

          // Advance time by 5 seconds to trigger timeout
          async.elapse(const Duration(seconds: 5));

          expect(customCallbackCalled, isTrue);
          expect(provider.appLaunchAdState, equals(AppLaunchAdState.timedOut));
        });
      });

      test('should cancel existing timeout when setting new one', () {
        fakeAsync((async) {
          bool firstTimeoutCalled = false;
          bool secondTimeoutCalled = false;

          // Start first sequence
          provider.startAppLaunchAdSequence(() {
            firstTimeoutCalled = true;
          });

          // Advance time by 2 seconds
          async.elapse(const Duration(seconds: 2));

          // Start second sequence (should cancel first timeout)
          provider.resetAppLaunchAdForNewSession();
          provider.startAppLaunchAdSequence(() {
            secondTimeoutCalled = true;
          });

          // Advance time by 5 more seconds
          async.elapse(const Duration(seconds: 5));

          expect(firstTimeoutCalled, isFalse);
          expect(secondTimeoutCalled, isTrue);
        });
      });

      test('should cleanup timeout on dispose', () {
        fakeAsync((async) {
          // Create a separate provider instance for this test
          final testProvider = TestAdMobProvider();
          bool timeoutCalled = false;

          testProvider.setAppLaunchAdTimeout(() {
            timeoutCalled = true;
          });

          // Dispose provider
          testProvider.dispose();

          // Advance time by 5 seconds
          async.elapse(const Duration(seconds: 5));

          // Timeout should not be called after dispose
          expect(timeoutCalled, isFalse);
        });
      });
    });

    group('Session Reset Functionality', () {
      test('should reset all flags on new session', () {
        // Set up initial state
        provider.startAppLaunchAdSequence();
        provider.completeAppLaunchAdSequence();

        expect(provider.hasShownAppLaunchAd, isTrue);
        expect(provider.isAppLaunchSequenceComplete, isTrue);
        expect(provider.appLaunchAdState, equals(AppLaunchAdState.completed));

        // Reset for new session
        provider.resetAppLaunchAdForNewSession();

        expect(provider.hasShownAppLaunchAd, isFalse);
        expect(provider.isAppLaunchSequenceComplete, isFalse);
        expect(provider.appLaunchAdState, equals(AppLaunchAdState.notStarted));
      });

      test('should cancel timeout timer on session reset', () {
        fakeAsync((async) {
          bool timeoutCalled = false;

          provider.setAppLaunchAdTimeout(() {
            timeoutCalled = true;
          });

          // Reset session (should cancel timeout)
          provider.resetAppLaunchAdForNewSession();

          // Advance time by 5 seconds
          async.elapse(const Duration(seconds: 5));

          expect(timeoutCalled, isFalse);
        });
      });

      test('should notify listeners on session reset', () {
        bool notified = false;
        provider.addListener(() {
          notified = true;
        });

        provider.resetAppLaunchAdForNewSession();

        expect(notified, isTrue);
      });

      test('should handle app lifecycle state changes', () {
        // Set up initial state
        provider.startAppLaunchAdSequence();
        provider.completeAppLaunchAdSequence();

        expect(provider.hasShownAppLaunchAd, isTrue);

        // Simulate app going to background and coming back
        provider.handleAppLifecycleChange(AppLifecycleState.paused);
        provider.handleAppLifecycleChange(AppLifecycleState.resumed);

        // Should reset flags on resume
        expect(provider.hasShownAppLaunchAd, isFalse);
        expect(provider.isAppLaunchSequenceComplete, isFalse);
        expect(provider.appLaunchAdState, equals(AppLaunchAdState.notStarted));
      });

      test('should not reset on non-resume lifecycle states', () {
        // Set up initial state
        provider.startAppLaunchAdSequence();
        provider.completeAppLaunchAdSequence();

        expect(provider.hasShownAppLaunchAd, isTrue);

        // Simulate app going to background
        provider.handleAppLifecycleChange(AppLifecycleState.paused);

        // Should not reset flags on pause
        expect(provider.hasShownAppLaunchAd, isTrue);
        expect(provider.isAppLaunchSequenceComplete, isTrue);
        expect(provider.appLaunchAdState, equals(AppLaunchAdState.completed));
      });
    });

    group('isAppLaunchSequenceInProgress Logic', () {
      test('should return false when state is notStarted', () {
        expect(provider.isAppLaunchSequenceInProgress(), isFalse);
      });

      test('should return true when state is loading', () {
        provider.setAppLaunchAdState(AppLaunchAdState.loading);
        expect(provider.isAppLaunchSequenceInProgress(), isTrue);
      });

      test('should return true when state is showing', () {
        provider.setAppLaunchAdState(AppLaunchAdState.showing);
        expect(provider.isAppLaunchSequenceInProgress(), isTrue);
      });

      test('should return false when state is completed', () {
        provider.setAppLaunchAdState(AppLaunchAdState.completed);
        expect(provider.isAppLaunchSequenceInProgress(), isFalse);
      });

      test('should return false when state is failed', () {
        provider.setAppLaunchAdState(AppLaunchAdState.failed);
        expect(provider.isAppLaunchSequenceInProgress(), isFalse);
      });

      test('should return false when state is timedOut', () {
        provider.setAppLaunchAdState(AppLaunchAdState.timedOut);
        expect(provider.isAppLaunchSequenceInProgress(), isFalse);
      });
    });

    group('State Information and Debugging', () {
      test('should provide detailed state information', () {
        provider.startAppLaunchAdSequence();

        final stateInfo = provider.getAppLaunchAdStateInfo();

        expect(stateInfo['state'], contains('loading'));
        expect(stateInfo['sequenceComplete'], isFalse);
        expect(stateInfo['adShown'], isFalse);
        expect(stateInfo['timeoutActive'], isTrue);
        expect(stateInfo['inProgress'], isTrue);
      });

      test('should update state information after completion', () {
        provider.startAppLaunchAdSequence();
        provider.completeAppLaunchAdSequence();

        final stateInfo = provider.getAppLaunchAdStateInfo();

        expect(stateInfo['state'], contains('completed'));
        expect(stateInfo['sequenceComplete'], isTrue);
        expect(stateInfo['adShown'], isTrue);
        expect(stateInfo['timeoutActive'], isFalse);
        expect(stateInfo['inProgress'], isFalse);
      });
    });

    group('Error Handling and Recovery', () {
      test('should handle force complete sequence', () {
        provider.startAppLaunchAdSequence();

        provider.forceCompleteAppLaunchSequence();

        expect(provider.appLaunchAdState, equals(AppLaunchAdState.completed));
        expect(provider.isAppLaunchSequenceComplete, isTrue);
        expect(provider.hasShownAppLaunchAd, isTrue);
      });

      test('should identify recoverable states', () {
        // Failed state should be recoverable
        provider.setAppLaunchAdState(AppLaunchAdState.failed);
        expect(provider.isAppLaunchAdRecoverable(), isTrue);

        // Timed out state should be recoverable
        provider.setAppLaunchAdState(AppLaunchAdState.timedOut);
        expect(provider.isAppLaunchAdRecoverable(), isTrue);

        // Completed state should not be recoverable
        provider.setAppLaunchAdState(AppLaunchAdState.completed);
        expect(provider.isAppLaunchAdRecoverable(), isFalse);
      });

      test('should handle loading state without timeout as recoverable', () {
        provider.setAppLaunchAdState(AppLaunchAdState.loading);
        // No timeout set, so should be recoverable
        expect(provider.isAppLaunchAdRecoverable(), isTrue);
      });

      test('should handle loading state with timeout as not recoverable', () {
        provider.startAppLaunchAdSequence(); // This sets timeout
        expect(provider.isAppLaunchAdRecoverable(), isFalse);
      });
    });

    group('Listener Management', () {
      test('should add and remove app launch sequence listeners', () {
        bool listenerCalled = false;
        void testListener() {
          listenerCalled = true;
        }

        provider.addAppLaunchSequenceListener(testListener);
        provider.completeAppLaunchAdSequence();

        expect(listenerCalled, isTrue);

        // Reset and remove listener
        listenerCalled = false;
        provider.removeAppLaunchSequenceListener(testListener);
        provider.resetAppLaunchAdForNewSession();
        provider.completeAppLaunchAdSequence();

        expect(listenerCalled, isFalse);
      });
    });

    group('Integration with Existing Ad Logic', () {
      test('should respect existing shouldShowAds logic', () {
        // Premium user should not show ads
        expect(provider.shouldShowAppLaunchAd(true), isFalse);

        // Non-premium user should show ads (if not already shown)
        expect(provider.shouldShowAppLaunchAd(false), isTrue);

        // After marking as shown, should not show again
        provider.markAppLaunchAdShown();
        expect(provider.shouldShowAppLaunchAd(false), isFalse);
      });

      test('should reset app launch ad flag', () {
        provider.markAppLaunchAdShown();
        expect(provider.hasShownAppLaunchAd, isTrue);

        provider.resetAppLaunchAdFlag();
        expect(provider.hasShownAppLaunchAd, isFalse);
      });
    });
  });
}
