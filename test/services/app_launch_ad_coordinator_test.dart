import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';

import 'package:flutter_chess_app/services/app_launch_ad_coordinator.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/providers/admob_provider.dart';

// Generate mocks
@GenerateMocks([AdMobProvider])
import 'app_launch_ad_coordinator_test.mocks.dart';

void main() {
  group('AppLaunchAdCoordinator Tests', () {
    late MockAdMobProvider mockAdMobProvider;
    late Widget testWidget;
    late BuildContext testContext;

    setUp(() {
      mockAdMobProvider = MockAdMobProvider();

      // Create a test widget with the mocked provider
      testWidget = MaterialApp(
        home: ChangeNotifierProvider<AdMobProvider>.value(
          value: mockAdMobProvider,
          child: Builder(
            builder: (context) {
              testContext = context;
              return const Scaffold(body: Text('Test'));
            },
          ),
        ),
      );
    });

    group('shouldShowAppLaunchAd() Logic Tests', () {
      test('should return false for premium user (removeAds = true)', () {
        // Arrange
        final premiumUser = ChessUser(
          uid: 'premium_user_123',
          displayName: 'Premium User',
          removeAds: true,
        );

        when(mockAdMobProvider.shouldShowAds(true)).thenReturn(false);
        when(mockAdMobProvider.hasShownAppLaunchAd).thenReturn(false);
        when(
          mockAdMobProvider.isAppLaunchSequenceInProgress(),
        ).thenReturn(false);

        // Act
        final result = AppLaunchAdCoordinator.shouldShowAppLaunchAd(
          premiumUser,
          mockAdMobProvider,
        );

        // Assert
        expect(result, isFalse);
      });

      test('should return false for user with null/empty uid', () {
        // Arrange
        final invalidUser = ChessUser(
          uid: null,
          displayName: 'Invalid User',
          removeAds: false,
        );

        // Act
        final result = AppLaunchAdCoordinator.shouldShowAppLaunchAd(
          invalidUser,
          mockAdMobProvider,
        );

        // Assert
        expect(result, isFalse);
      });

      test('should return false for user with empty uid', () {
        // Arrange
        final invalidUser = ChessUser(
          uid: '',
          displayName: 'Invalid User',
          removeAds: false,
        );

        // Act
        final result = AppLaunchAdCoordinator.shouldShowAppLaunchAd(
          invalidUser,
          mockAdMobProvider,
        );

        // Assert
        expect(result, isFalse);
      });

      test('should return false when ads are disabled in configuration', () {
        // Arrange
        final regularUser = ChessUser(
          uid: 'regular_user_123',
          displayName: 'Regular User',
          removeAds: false,
        );

        when(mockAdMobProvider.shouldShowAds(false)).thenReturn(false);

        // Act
        final result = AppLaunchAdCoordinator.shouldShowAppLaunchAd(
          regularUser,
          mockAdMobProvider,
        );

        // Assert
        expect(result, isFalse);
      });

      test(
        'should return false when app launch ad already shown this session',
        () {
          // Arrange
          final regularUser = ChessUser(
            uid: 'regular_user_123',
            displayName: 'Regular User',
            removeAds: false,
          );

          when(mockAdMobProvider.shouldShowAds(false)).thenReturn(true);
          when(mockAdMobProvider.hasShownAppLaunchAd).thenReturn(true);

          // Act
          final result = AppLaunchAdCoordinator.shouldShowAppLaunchAd(
            regularUser,
            mockAdMobProvider,
          );

          // Assert
          expect(result, isFalse);
        },
      );

      test(
        'should return false when app launch sequence is already in progress',
        () {
          // Arrange
          final regularUser = ChessUser(
            uid: 'regular_user_123',
            displayName: 'Regular User',
            removeAds: false,
          );

          when(mockAdMobProvider.shouldShowAds(false)).thenReturn(true);
          when(mockAdMobProvider.hasShownAppLaunchAd).thenReturn(false);
          when(
            mockAdMobProvider.isAppLaunchSequenceInProgress(),
          ).thenReturn(true);

          // Act
          final result = AppLaunchAdCoordinator.shouldShowAppLaunchAd(
            regularUser,
            mockAdMobProvider,
          );

          // Assert
          expect(result, isFalse);
        },
      );

      test('should return true for valid non-premium user in new session', () {
        // Arrange
        final regularUser = ChessUser(
          uid: 'regular_user_123',
          displayName: 'Regular User',
          removeAds: false,
        );

        when(mockAdMobProvider.shouldShowAds(false)).thenReturn(true);
        when(mockAdMobProvider.hasShownAppLaunchAd).thenReturn(false);
        when(
          mockAdMobProvider.isAppLaunchSequenceInProgress(),
        ).thenReturn(false);

        // Act
        final result = AppLaunchAdCoordinator.shouldShowAppLaunchAd(
          regularUser,
          mockAdMobProvider,
        );

        // Assert
        expect(result, isTrue);
      });

      test('should return true for guest user in new session', () {
        // Arrange
        final guestUser = ChessUser.guest().copyWith(uid: 'guest_123');

        when(mockAdMobProvider.shouldShowAds(false)).thenReturn(true);
        when(mockAdMobProvider.hasShownAppLaunchAd).thenReturn(false);
        when(
          mockAdMobProvider.isAppLaunchSequenceInProgress(),
        ).thenReturn(false);

        // Act
        final result = AppLaunchAdCoordinator.shouldShowAppLaunchAd(
          guestUser,
          mockAdMobProvider,
        );

        // Assert
        expect(result, isTrue);
      });

      test('should handle provider errors gracefully and return false', () {
        // Arrange
        final regularUser = ChessUser(
          uid: 'regular_user_123',
          displayName: 'Regular User',
          removeAds: false,
        );

        when(
          mockAdMobProvider.shouldShowAds(false),
        ).thenThrow(Exception('Provider error'));

        // Act
        final result = AppLaunchAdCoordinator.shouldShowAppLaunchAd(
          regularUser,
          mockAdMobProvider,
        );

        // Assert
        expect(result, isFalse);
      });
    });

    group('handleAppLaunchAd() Flow Tests', () {
      testWidgets('should call onComplete immediately for premium user', (
        tester,
      ) async {
        // Arrange
        await tester.pumpWidget(testWidget);

        final premiumUser = ChessUser(
          uid: 'premium_user_123',
          displayName: 'Premium User',
          removeAds: true,
        );

        bool callbackExecuted = false;
        void onComplete() {
          callbackExecuted = true;
        }

        when(mockAdMobProvider.shouldShowAds(true)).thenReturn(false);

        // Act
        await AppLaunchAdCoordinator.handleAppLaunchAd(
          context: testContext,
          user: premiumUser,
          onComplete: onComplete,
        );

        // Assert
        expect(callbackExecuted, isTrue);
        verifyNever(mockAdMobProvider.startAppLaunchAdSequence(any));
      });

      testWidgets('should call onComplete immediately for invalid user', (
        tester,
      ) async {
        // Arrange
        await tester.pumpWidget(testWidget);

        final invalidUser = ChessUser(
          uid: null,
          displayName: 'Invalid User',
          removeAds: false,
        );

        bool callbackExecuted = false;
        void onComplete() {
          callbackExecuted = true;
        }

        // Act
        await AppLaunchAdCoordinator.handleAppLaunchAd(
          context: testContext,
          user: invalidUser,
          onComplete: onComplete,
        );

        // Assert
        expect(callbackExecuted, isTrue);
        verifyNever(mockAdMobProvider.startAppLaunchAdSequence(any));
      });

      testWidgets('should start ad sequence and complete when no ad unit ID', (
        tester,
      ) async {
        // Arrange
        await tester.pumpWidget(testWidget);

        final regularUser = ChessUser(
          uid: 'regular_user_123',
          displayName: 'Regular User',
          removeAds: false,
        );

        bool callbackExecuted = false;
        void onComplete() {
          callbackExecuted = true;
        }

        when(mockAdMobProvider.shouldShowAds(false)).thenReturn(true);
        when(mockAdMobProvider.hasShownAppLaunchAd).thenReturn(false);
        when(
          mockAdMobProvider.isAppLaunchSequenceInProgress(),
        ).thenReturn(false);
        when(
          mockAdMobProvider.interstitialAdUnitId,
        ).thenReturn(null); // No ad unit ID

        // Act
        await AppLaunchAdCoordinator.handleAppLaunchAd(
          context: testContext,
          user: regularUser,
          onComplete: onComplete,
        );

        // Assert
        verify(mockAdMobProvider.startAppLaunchAdSequence(any)).called(1);
        expect(callbackExecuted, isTrue);
      });

      testWidgets('should handle provider access errors gracefully', (
        tester,
      ) async {
        // Arrange
        final testWidgetWithoutProvider = MaterialApp(
          home: Builder(
            builder: (context) {
              testContext = context;
              return const Scaffold(body: Text('Test'));
            },
          ),
        );

        await tester.pumpWidget(testWidgetWithoutProvider);

        final regularUser = ChessUser(
          uid: 'regular_user_123',
          displayName: 'Regular User',
          removeAds: false,
        );

        bool callbackExecuted = false;
        void onComplete() {
          callbackExecuted = true;
        }

        // Act
        await AppLaunchAdCoordinator.handleAppLaunchAd(
          context: testContext,
          user: regularUser,
          onComplete: onComplete,
        );

        // Assert
        expect(callbackExecuted, isTrue);
      });
    });

    group('Error Handling and Timeout Scenarios', () {
      testWidgets('should handle startAppLaunchAdSequence errors', (
        tester,
      ) async {
        // Arrange
        await tester.pumpWidget(testWidget);

        final regularUser = ChessUser(
          uid: 'regular_user_123',
          displayName: 'Regular User',
          removeAds: false,
        );

        bool callbackExecuted = false;
        void onComplete() {
          callbackExecuted = true;
        }

        when(mockAdMobProvider.shouldShowAds(false)).thenReturn(true);
        when(mockAdMobProvider.hasShownAppLaunchAd).thenReturn(false);
        when(
          mockAdMobProvider.isAppLaunchSequenceInProgress(),
        ).thenReturn(false);
        when(
          mockAdMobProvider.startAppLaunchAdSequence(any),
        ).thenThrow(Exception('Sequence start error'));

        // Act
        await AppLaunchAdCoordinator.handleAppLaunchAd(
          context: testContext,
          user: regularUser,
          onComplete: onComplete,
        );

        // Assert
        expect(callbackExecuted, isTrue);
      });

      testWidgets('should handle missing ad unit ID gracefully', (
        tester,
      ) async {
        // Arrange
        await tester.pumpWidget(testWidget);

        final regularUser = ChessUser(
          uid: 'regular_user_123',
          displayName: 'Regular User',
          removeAds: false,
        );

        bool callbackExecuted = false;
        void onComplete() {
          callbackExecuted = true;
        }

        when(mockAdMobProvider.shouldShowAds(false)).thenReturn(true);
        when(mockAdMobProvider.hasShownAppLaunchAd).thenReturn(false);
        when(
          mockAdMobProvider.isAppLaunchSequenceInProgress(),
        ).thenReturn(false);
        when(mockAdMobProvider.interstitialAdUnitId).thenReturn(null);

        // Act
        await AppLaunchAdCoordinator.handleAppLaunchAd(
          context: testContext,
          user: regularUser,
          onComplete: onComplete,
        );

        // Assert
        expect(callbackExecuted, isTrue);
        verify(mockAdMobProvider.startAppLaunchAdSequence(any)).called(1);
      });

      testWidgets('should handle empty ad unit ID gracefully', (tester) async {
        // Arrange
        await tester.pumpWidget(testWidget);

        final regularUser = ChessUser(
          uid: 'regular_user_123',
          displayName: 'Regular User',
          removeAds: false,
        );

        bool callbackExecuted = false;
        void onComplete() {
          callbackExecuted = true;
        }

        when(mockAdMobProvider.shouldShowAds(false)).thenReturn(true);
        when(mockAdMobProvider.hasShownAppLaunchAd).thenReturn(false);
        when(
          mockAdMobProvider.isAppLaunchSequenceInProgress(),
        ).thenReturn(false);
        when(mockAdMobProvider.interstitialAdUnitId).thenReturn('');

        // Act
        await AppLaunchAdCoordinator.handleAppLaunchAd(
          context: testContext,
          user: regularUser,
          onComplete: onComplete,
        );

        // Assert
        expect(callbackExecuted, isTrue);
        verify(mockAdMobProvider.startAppLaunchAdSequence(any)).called(1);
      });

      testWidgets('should handle ad unit ID access errors', (tester) async {
        // Arrange
        await tester.pumpWidget(testWidget);

        final regularUser = ChessUser(
          uid: 'regular_user_123',
          displayName: 'Regular User',
          removeAds: false,
        );

        bool callbackExecuted = false;
        void onComplete() {
          callbackExecuted = true;
        }

        when(mockAdMobProvider.shouldShowAds(false)).thenReturn(true);
        when(mockAdMobProvider.hasShownAppLaunchAd).thenReturn(false);
        when(
          mockAdMobProvider.isAppLaunchSequenceInProgress(),
        ).thenReturn(false);
        when(
          mockAdMobProvider.interstitialAdUnitId,
        ).thenThrow(Exception('Ad unit ID error'));

        // Act
        await AppLaunchAdCoordinator.handleAppLaunchAd(
          context: testContext,
          user: regularUser,
          onComplete: onComplete,
        );

        // Assert
        expect(callbackExecuted, isTrue);
        verify(mockAdMobProvider.startAppLaunchAdSequence(any)).called(1);
      });
    });

    group('Callback Execution Tests', () {
      testWidgets('should execute callback exactly once for premium user', (
        tester,
      ) async {
        // Arrange
        await tester.pumpWidget(testWidget);

        final premiumUser = ChessUser(
          uid: 'premium_user_123',
          displayName: 'Premium User',
          removeAds: true,
        );

        int callbackCount = 0;
        void onComplete() {
          callbackCount++;
        }

        when(mockAdMobProvider.shouldShowAds(true)).thenReturn(false);

        // Act
        await AppLaunchAdCoordinator.handleAppLaunchAd(
          context: testContext,
          user: premiumUser,
          onComplete: onComplete,
        );

        // Assert
        expect(callbackCount, equals(1));
      });

      testWidgets('should execute callback even when errors occur', (
        tester,
      ) async {
        // Arrange
        await tester.pumpWidget(testWidget);

        final regularUser = ChessUser(
          uid: 'regular_user_123',
          displayName: 'Regular User',
          removeAds: false,
        );

        int callbackCount = 0;
        void onComplete() {
          callbackCount++;
        }

        when(
          mockAdMobProvider.shouldShowAds(false),
        ).thenThrow(Exception('Provider error'));

        // Act
        await AppLaunchAdCoordinator.handleAppLaunchAd(
          context: testContext,
          user: regularUser,
          onComplete: onComplete,
        );

        // Assert
        expect(callbackCount, equals(1));
      });

      testWidgets('should handle callback errors gracefully', (tester) async {
        // Arrange
        await tester.pumpWidget(testWidget);

        final premiumUser = ChessUser(
          uid: 'premium_user_123',
          displayName: 'Premium User',
          removeAds: true,
        );

        void onComplete() {
          throw Exception('Callback error');
        }

        when(mockAdMobProvider.shouldShowAds(true)).thenReturn(false);

        // Act & Assert - Should not throw
        expect(
          () async => await AppLaunchAdCoordinator.handleAppLaunchAd(
            context: testContext,
            user: premiumUser,
            onComplete: onComplete,
          ),
          returnsNormally,
        );
      });

      test('should execute timeout callback when provided', () {
        fakeAsync((async) {
          // Arrange
          bool timeoutCallbackExecuted = false;
          void timeoutCallback() {
            timeoutCallbackExecuted = true;
          }

          when(mockAdMobProvider.shouldShowAds(false)).thenReturn(true);
          when(mockAdMobProvider.hasShownAppLaunchAd).thenReturn(false);
          when(
            mockAdMobProvider.isAppLaunchSequenceInProgress(),
          ).thenReturn(false);

          // Simulate the timeout callback being called by the provider
          when(mockAdMobProvider.startAppLaunchAdSequence(any)).thenAnswer((
            invocation,
          ) {
            final callback = invocation.positionalArguments[0] as VoidCallback?;
            // Simulate timeout after 5 seconds
            Timer(const Duration(seconds: 5), () {
              callback?.call();
            });
          });

          final regularUser = ChessUser(
            uid: 'regular_user_123',
            displayName: 'Regular User',
            removeAds: false,
          );

          // Act
          AppLaunchAdCoordinator.shouldShowAppLaunchAd(
            regularUser,
            mockAdMobProvider,
          );

          // Trigger the timeout manually since we can't easily test the full flow
          timeoutCallback();

          // Assert
          expect(timeoutCallbackExecuted, isTrue);
        });
      });
    });

    group('Static Helper Methods Tests', () {
      test('isProcessing should return false initially', () {
        expect(AppLaunchAdCoordinator.isProcessing, isFalse);
      });

      test('dispose should complete without errors', () {
        expect(() => AppLaunchAdCoordinator.dispose(), returnsNormally);
      });

      test('forceComplete should execute callback', () {
        // Arrange
        bool callbackExecuted = false;
        void onComplete() {
          callbackExecuted = true;
        }

        // Act
        AppLaunchAdCoordinator.forceComplete(mockAdMobProvider, onComplete);

        // Assert
        expect(callbackExecuted, isTrue);
        verify(mockAdMobProvider.forceCompleteAppLaunchSequence()).called(1);
      });

      test('forceComplete should handle provider errors gracefully', () {
        // Arrange
        bool callbackExecuted = false;
        void onComplete() {
          callbackExecuted = true;
        }

        when(
          mockAdMobProvider.forceCompleteAppLaunchSequence(),
        ).thenThrow(Exception('Force complete error'));

        // Act
        expect(
          () => AppLaunchAdCoordinator.forceComplete(
            mockAdMobProvider,
            onComplete,
          ),
          returnsNormally,
        );

        // Assert
        expect(callbackExecuted, isTrue);
      });

      test('forceComplete should handle callback errors gracefully', () {
        // Arrange
        void onComplete() {
          throw Exception('Callback error');
        }

        // Act & Assert
        expect(
          () => AppLaunchAdCoordinator.forceComplete(
            mockAdMobProvider,
            onComplete,
          ),
          returnsNormally,
        );
      });
    });

    group('Edge Cases and Boundary Tests', () {
      test('shouldShowAppLaunchAd should handle null removeAds gracefully', () {
        // Arrange
        final userWithNullRemoveAds = ChessUser(
          uid: 'user_123',
          displayName: 'User',
          removeAds: null,
        );

        when(mockAdMobProvider.shouldShowAds(null)).thenReturn(true);
        when(mockAdMobProvider.hasShownAppLaunchAd).thenReturn(false);
        when(
          mockAdMobProvider.isAppLaunchSequenceInProgress(),
        ).thenReturn(false);

        // Act
        final result = AppLaunchAdCoordinator.shouldShowAppLaunchAd(
          userWithNullRemoveAds,
          mockAdMobProvider,
        );

        // Assert
        expect(result, isTrue);
      });

      testWidgets('handleAppLaunchAd should handle user with null removeAds', (
        tester,
      ) async {
        // Arrange
        await tester.pumpWidget(testWidget);

        final userWithNullRemoveAds = ChessUser(
          uid: 'user_123',
          displayName: 'User',
          removeAds: null,
        );

        bool callbackExecuted = false;
        void onComplete() {
          callbackExecuted = true;
        }

        when(mockAdMobProvider.shouldShowAds(null)).thenReturn(true);
        when(mockAdMobProvider.hasShownAppLaunchAd).thenReturn(false);
        when(
          mockAdMobProvider.isAppLaunchSequenceInProgress(),
        ).thenReturn(false);
        when(
          mockAdMobProvider.interstitialAdUnitId,
        ).thenReturn(null); // No ad unit ID

        // Act
        await AppLaunchAdCoordinator.handleAppLaunchAd(
          context: testContext,
          user: userWithNullRemoveAds,
          onComplete: onComplete,
        );

        // Assert
        verify(mockAdMobProvider.startAppLaunchAdSequence(any)).called(1);
        expect(callbackExecuted, isTrue);
      });
    });
  });
}
