import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chess_app/services/admob_service.dart';
import 'package:flutter_chess_app/providers/admob_provider.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/models/admob_config_model.dart';

// Generate mocks
@GenerateMocks([AdMobProvider])
import 'admob_service_test.mocks.dart';

void main() {
  group('AdMobService Guest User Tests', () {
    late MockAdMobProvider mockAdMobProvider;
    late Widget testWidget;

    setUp(() {
      mockAdMobProvider = MockAdMobProvider();

      testWidget = MaterialApp(
        home: ChangeNotifierProvider<AdMobProvider>.value(
          value: mockAdMobProvider,
          child: const Scaffold(body: Text('Test')),
        ),
      );
    });

    group('shouldShowAdsForGuestUser', () {
      testWidgets('should return true for guest users when ads are enabled', (
        WidgetTester tester,
      ) async {
        // Arrange
        final guestUser = ChessUser(
          uid: 'guest-123',
          displayName: 'Guest-123',
          isGuest: true,
          removeAds: false,
        );

        final adConfig = AdMobConfig.defaultTestConfig();
        when(mockAdMobProvider.adMobConfig).thenReturn(adConfig);
        when(mockAdMobProvider.isAdsEnabled).thenReturn(true);

        await tester.pumpWidget(testWidget);

        // Act
        final shouldShow = AdMobService.shouldShowAdsForGuestUser(
          tester.element(find.byType(Scaffold)),
          guestUser,
        );

        // Assert
        expect(shouldShow, true);
      });

      testWidgets('should return false for guest users when ads are disabled', (
        WidgetTester tester,
      ) async {
        // Arrange
        final guestUser = ChessUser(
          uid: 'guest-123',
          displayName: 'Guest-123',
          isGuest: true,
          removeAds: false,
        );

        final adConfig = AdMobConfig.defaultTestConfig().copyWith(
          enabled: false,
        );
        when(mockAdMobProvider.adMobConfig).thenReturn(adConfig);
        when(mockAdMobProvider.isAdsEnabled).thenReturn(false);

        await tester.pumpWidget(testWidget);

        // Act
        final shouldShow = AdMobService.shouldShowAdsForGuestUser(
          tester.element(find.byType(Scaffold)),
          guestUser,
        );

        // Assert
        expect(shouldShow, false);
      });

      testWidgets('should return false when AdMob config is not loaded', (
        WidgetTester tester,
      ) async {
        // Arrange
        final guestUser = ChessUser(
          uid: 'guest-123',
          displayName: 'Guest-123',
          isGuest: true,
          removeAds: false,
        );

        when(mockAdMobProvider.adMobConfig).thenReturn(null);

        await tester.pumpWidget(testWidget);

        // Act
        final shouldShow = AdMobService.shouldShowAdsForGuestUser(
          tester.element(find.byType(Scaffold)),
          guestUser,
        );

        // Assert
        expect(shouldShow, false);
      });

      testWidgets('should respect ad removal preference for regular users', (
        WidgetTester tester,
      ) async {
        // Arrange
        final regularUser = ChessUser(
          uid: 'user-123',
          displayName: 'Regular User',
          isGuest: false,
          removeAds: true,
        );

        final adConfig = AdMobConfig.defaultTestConfig();
        when(mockAdMobProvider.adMobConfig).thenReturn(adConfig);
        when(mockAdMobProvider.isAdsEnabled).thenReturn(true);
        when(mockAdMobProvider.shouldShowAds(true)).thenReturn(false);

        await tester.pumpWidget(testWidget);

        // Act
        final shouldShow = AdMobService.shouldShowAdsForGuestUser(
          tester.element(find.byType(Scaffold)),
          regularUser,
        );

        // Assert
        expect(shouldShow, false);
        verify(mockAdMobProvider.shouldShowAds(true)).called(1);
      });
    });

    group('Ad Unit ID Retrieval', () {
      testWidgets('should return valid app open ad unit ID for guest users', (
        WidgetTester tester,
      ) async {
        // Arrange
        final adConfig = AdMobConfig.defaultTestConfig();
        when(
          mockAdMobProvider.appOpenAdUnitId,
        ).thenReturn(adConfig.appOpenAdUnitId);

        await tester.pumpWidget(testWidget);

        // Act
        final adUnitId = AdMobService.getAppOpenAdUnitId(
          tester.element(find.byType(Scaffold)),
        );

        // Assert
        expect(adUnitId, isNotNull);
        expect(adUnitId, isNotEmpty);
        expect(adUnitId, equals(adConfig.appOpenAdUnitId));
      });

      testWidgets('should return valid banner ad unit ID for guest users', (
        WidgetTester tester,
      ) async {
        // Arrange
        final adConfig = AdMobConfig.defaultTestConfig();
        when(
          mockAdMobProvider.bannerAdUnitId,
        ).thenReturn(adConfig.bannerAdUnitId);

        await tester.pumpWidget(testWidget);

        // Act
        final adUnitId = AdMobService.getBannerAdUnitId(
          tester.element(find.byType(Scaffold)),
        );

        // Assert
        expect(adUnitId, isNotNull);
        expect(adUnitId, isNotEmpty);
        expect(adUnitId, equals(adConfig.bannerAdUnitId));
      });

      testWidgets(
        'should return valid interstitial ad unit ID for guest users',
        (WidgetTester tester) async {
          // Arrange
          final adConfig = AdMobConfig.defaultTestConfig();
          when(
            mockAdMobProvider.interstitialAdUnitId,
          ).thenReturn(adConfig.interstitialAdUnitId);

          await tester.pumpWidget(testWidget);

          // Act
          final adUnitId = AdMobService.getInterstitialAdUnitId(
            tester.element(find.byType(Scaffold)),
          );

          // Assert
          expect(adUnitId, isNotNull);
          expect(adUnitId, isNotEmpty);
          expect(adUnitId, equals(adConfig.interstitialAdUnitId));
        },
      );

      testWidgets('should return valid rewarded ad unit ID for guest users', (
        WidgetTester tester,
      ) async {
        // Arrange
        final adConfig = AdMobConfig.defaultTestConfig();
        when(
          mockAdMobProvider.rewardedAdUnitId,
        ).thenReturn(adConfig.rewardedAdUnitId);

        await tester.pumpWidget(testWidget);

        // Act
        final adUnitId = AdMobService.getRewardedAdUnitId(
          tester.element(find.byType(Scaffold)),
        );

        // Assert
        expect(adUnitId, isNotNull);
        expect(adUnitId, isNotEmpty);
        expect(adUnitId, equals(adConfig.rewardedAdUnitId));
      });
    });
  });

  group('Cross User Type Ad Functionality', () {
    late MockAdMobProvider mockAdMobProvider;
    late Widget testWidget;

    setUp(() {
      mockAdMobProvider = MockAdMobProvider();

      testWidget = MaterialApp(
        home: ChangeNotifierProvider<AdMobProvider>.value(
          value: mockAdMobProvider,
          child: const Scaffold(body: Text('Test')),
        ),
      );
    });

    testWidgets(
      'guest users should always see ads regardless of removeAds field',
      (WidgetTester tester) async {
        // Arrange
        final guestUserWithRemoveAds = ChessUser(
          uid: 'guest-123',
          displayName: 'Guest-123',
          isGuest: true,
          removeAds: true, // This should be ignored for guest users
        );

        final adConfig = AdMobConfig.defaultTestConfig();
        when(mockAdMobProvider.adMobConfig).thenReturn(adConfig);
        when(mockAdMobProvider.isAdsEnabled).thenReturn(true);

        await tester.pumpWidget(testWidget);

        // Act
        final shouldShow = AdMobService.shouldShowAdsForGuestUser(
          tester.element(find.byType(Scaffold)),
          guestUserWithRemoveAds,
        );

        // Assert
        expect(shouldShow, true, reason: 'Guest users should always see ads');
      },
    );

    testWidgets('regular users should respect removeAds preference', (
      WidgetTester tester,
    ) async {
      // Arrange
      final regularUserWithRemoveAds = ChessUser(
        uid: 'user-123',
        displayName: 'Regular User',
        isGuest: false,
        removeAds: true,
      );

      final regularUserWithoutRemoveAds = ChessUser(
        uid: 'user-456',
        displayName: 'Regular User 2',
        isGuest: false,
        removeAds: false,
      );

      final adConfig = AdMobConfig.defaultTestConfig();
      when(mockAdMobProvider.adMobConfig).thenReturn(adConfig);
      when(mockAdMobProvider.isAdsEnabled).thenReturn(true);
      when(mockAdMobProvider.shouldShowAds(true)).thenReturn(false);
      when(mockAdMobProvider.shouldShowAds(false)).thenReturn(true);

      await tester.pumpWidget(testWidget);

      // Act
      final shouldShowForUserWithRemoveAds =
          AdMobService.shouldShowAdsForGuestUser(
            tester.element(find.byType(Scaffold)),
            regularUserWithRemoveAds,
          );
      final shouldShowForUserWithoutRemoveAds =
          AdMobService.shouldShowAdsForGuestUser(
            tester.element(find.byType(Scaffold)),
            regularUserWithoutRemoveAds,
          );

      // Assert
      expect(
        shouldShowForUserWithRemoveAds,
        false,
        reason: 'Users with removeAds should not see ads',
      );
      expect(
        shouldShowForUserWithoutRemoveAds,
        true,
        reason: 'Users without removeAds should see ads',
      );
    });

    testWidgets('ad preferences should be maintained during account upgrades', (
      WidgetTester tester,
    ) async {
      // This test simulates the scenario where a guest user upgrades to a regular account
      // The ad preferences should be properly handled during the transition

      // Arrange - Start with guest user
      final guestUser = ChessUser(
        uid: 'user-123',
        displayName: 'Guest-123',
        isGuest: true,
        removeAds: false,
      );

      // Simulate upgrade to regular user (guest users can't purchase ad removal)
      final upgradedUser = ChessUser(
        uid: 'user-123', // Same UID
        displayName: 'Upgraded User',
        isGuest: false,
        removeAds: false, // Should remain false after upgrade
      );

      final adConfig = AdMobConfig.defaultTestConfig();
      when(mockAdMobProvider.adMobConfig).thenReturn(adConfig);
      when(mockAdMobProvider.isAdsEnabled).thenReturn(true);
      when(mockAdMobProvider.shouldShowAds(false)).thenReturn(true);

      await tester.pumpWidget(testWidget);

      // Act
      final shouldShowForGuest = AdMobService.shouldShowAdsForGuestUser(
        tester.element(find.byType(Scaffold)),
        guestUser,
      );
      final shouldShowForUpgraded = AdMobService.shouldShowAdsForGuestUser(
        tester.element(find.byType(Scaffold)),
        upgradedUser,
      );

      // Assert
      expect(shouldShowForGuest, true, reason: 'Guest user should see ads');
      expect(
        shouldShowForUpgraded,
        true,
        reason: 'Upgraded user should still see ads (no ad removal purchased)',
      );
    });
  });
}
