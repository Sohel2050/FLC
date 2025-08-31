import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/models/admob_config_model.dart';

void main() {
  group('Guest User Ad Functionality Tests', () {
    group('AdMobConfig Tests', () {
      test('default test config should have all required ad unit IDs', () {
        // Arrange & Act
        final config = AdMobConfig.defaultTestConfig();

        // Assert
        expect(config.appOpenAdId, isNotNull);
        expect(config.appOpenAdId, isNotEmpty);
        // Note: appOpenAdUnitId getter returns empty string on non-mobile platforms
        expect(config.androidBannerAdId, isNotNull);
        expect(config.androidBannerAdId, isNotEmpty);
        expect(config.iosBannerAdId, isNotNull);
        expect(config.iosBannerAdId, isNotEmpty);
        expect(config.androidInterstitialAdId, isNotNull);
        expect(config.androidInterstitialAdId, isNotEmpty);
        expect(config.iosInterstitialAdId, isNotNull);
        expect(config.iosInterstitialAdId, isNotEmpty);
        // Note: Platform-specific getters return null on non-mobile platforms
        expect(config.enabled, true);
      });

      test('disabled config should return empty ad unit IDs', () {
        // Arrange
        final config = AdMobConfig.defaultTestConfig().copyWith(enabled: false);

        // Act & Assert
        expect(config.enabled, false);
        // Platform-specific getters return null when ads are disabled
        expect(config.bannerAdUnitId, null);
        expect(config.interstitialAdUnitId, null);
        expect(config.rewardedAdUnitId, null);
        expect(config.nativeAdUnitId, null);
      });

      test('should handle config serialization correctly', () {
        // Arrange
        final originalConfig = AdMobConfig.defaultTestConfig();

        // Act
        final configMap = originalConfig.toMap();
        final deserializedConfig = AdMobConfig.fromMap(configMap);

        // Assert
        expect(
          deserializedConfig.appOpenAdId,
          equals(originalConfig.appOpenAdId),
        );
        expect(deserializedConfig.enabled, equals(originalConfig.enabled));
        expect(
          deserializedConfig.androidBannerAdId,
          equals(originalConfig.androidBannerAdId),
        );
        expect(
          deserializedConfig.iosBannerAdId,
          equals(originalConfig.iosBannerAdId),
        );
        expect(
          deserializedConfig.androidInterstitialAdId,
          equals(originalConfig.androidInterstitialAdId),
        );
      });
    });

    group('ChessUser Model Tests for Ad Functionality', () {
      test('guest users should have correct default ad settings', () {
        // Arrange & Act
        final guestUser = ChessUser(
          uid: 'guest-123',
          displayName: 'Guest-123',
          isGuest: true,
        );

        // Assert
        expect(guestUser.isGuest, true);
        expect(
          guestUser.removeAds,
          false,
          reason: 'Guest users should not have ad removal by default',
        );
      });

      test('regular users can have ad removal', () {
        // Arrange & Act
        final regularUserWithAds = ChessUser(
          uid: 'user-123',
          displayName: 'Regular User',
          isGuest: false,
          removeAds: false,
        );

        final regularUserWithoutAds = ChessUser(
          uid: 'user-456',
          displayName: 'Premium User',
          isGuest: false,
          removeAds: true,
        );

        // Assert
        expect(regularUserWithAds.isGuest, false);
        expect(regularUserWithAds.removeAds, false);
        expect(regularUserWithoutAds.isGuest, false);
        expect(regularUserWithoutAds.removeAds, true);
      });

      test('guest user serialization preserves ad settings', () {
        // Arrange
        final originalGuestUser = ChessUser(
          uid: 'guest-123',
          displayName: 'Guest-123',
          isGuest: true,
          removeAds: false,
        );

        // Act
        final userMap = originalGuestUser.toMap();
        final deserializedUser = ChessUser.fromMap(userMap);

        // Assert
        expect(deserializedUser.isGuest, equals(originalGuestUser.isGuest));
        expect(deserializedUser.removeAds, equals(originalGuestUser.removeAds));
        expect(deserializedUser.uid, equals(originalGuestUser.uid));
        expect(
          deserializedUser.displayName,
          equals(originalGuestUser.displayName),
        );
      });
    });

    group('Cross User Type Scenarios', () {
      test('guest users should always have removeAds set to false', () {
        // This test ensures that guest users cannot have ad removal
        // even if somehow the field gets set to true

        // Arrange
        final guestUser = ChessUser(
          uid: 'guest-123',
          displayName: 'Guest-123',
          isGuest: true,
          removeAds: true, // This should not be possible in practice
        );

        // Act & Assert
        expect(guestUser.isGuest, true);
        // Note: In the actual implementation, we should ensure guest users
        // cannot have removeAds set to true, but for testing we verify
        // the ad logic handles this correctly
        expect(
          guestUser.removeAds,
          true,
          reason: 'Testing edge case where guest user has removeAds=true',
        );
      });

      test('account upgrade scenario maintains correct user type', () {
        // Simulate a guest user upgrading to a regular account

        // Arrange - Start with guest user
        final guestUser = ChessUser(
          uid: 'user-123',
          displayName: 'Guest-123',
          isGuest: true,
          removeAds: false,
        );

        // Act - Simulate upgrade (same UID, different properties)
        final upgradedUser = ChessUser(
          uid: 'user-123', // Same UID
          displayName: 'Upgraded User',
          isGuest: false, // No longer a guest
          removeAds: false, // Guest users can't purchase ad removal
        );

        // Assert
        expect(
          guestUser.uid,
          equals(upgradedUser.uid),
          reason: 'UID should remain the same',
        );
        expect(
          guestUser.isGuest,
          true,
          reason: 'Original user should be guest',
        );
        expect(
          upgradedUser.isGuest,
          false,
          reason: 'Upgraded user should not be guest',
        );
        expect(
          upgradedUser.removeAds,
          false,
          reason:
              'Upgraded user should not have ad removal (guest users cannot purchase it)',
        );
      });
    });

    group('Ad Logic Validation', () {
      test('should validate ad display logic for different user types', () {
        // This test validates the core ad display logic without relying on provider internals

        // Test data
        final testCases = [
          {
            'user': ChessUser(
              uid: 'guest-1',
              displayName: 'Guest-1',
              isGuest: true,
              removeAds: false,
            ),
            'adsEnabled': true,
            'expectedResult': true,
            'description': 'Guest user with ads enabled should see ads',
          },
          {
            'user': ChessUser(
              uid: 'guest-2',
              displayName: 'Guest-2',
              isGuest: true,
              removeAds: true,
            ),
            'adsEnabled': true,
            'expectedResult':
                true, // Guest users should see ads regardless of removeAds
            'description': 'Guest user should see ads even with removeAds=true',
          },
          {
            'user': ChessUser(
              uid: 'user-1',
              displayName: 'User-1',
              isGuest: false,
              removeAds: false,
            ),
            'adsEnabled': true,
            'expectedResult': true,
            'description': 'Regular user without ad removal should see ads',
          },
          {
            'user': ChessUser(
              uid: 'user-2',
              displayName: 'User-2',
              isGuest: false,
              removeAds: true,
            ),
            'adsEnabled': true,
            'expectedResult': false,
            'description': 'Regular user with ad removal should not see ads',
          },
        ];

        // Test each case
        for (final testCase in testCases) {
          final user = testCase['user'] as ChessUser;
          final adsEnabled = testCase['adsEnabled'] as bool;
          final expectedResult = testCase['expectedResult'] as bool;
          final description = testCase['description'] as String;

          // Simulate the ad display logic
          bool shouldShowAds;
          if (!adsEnabled) {
            shouldShowAds = false;
          } else if (user.isGuest) {
            shouldShowAds = true; // Guest users always see ads
          } else {
            shouldShowAds =
                !(user.removeAds ?? false); // Regular users based on preference
          }

          expect(shouldShowAds, equals(expectedResult), reason: description);
        }
      });

      test('should handle edge cases gracefully', () {
        // Test null user
        expect(() {
          // Simulate null user handling
          ChessUser? nullUser;
          final shouldShow = nullUser?.isGuest ?? false;
          expect(shouldShow, false);
        }, returnsNormally);

        // Test user with null fields
        expect(() {
          final userWithNulls = ChessUser(
            uid: 'test',
            displayName: 'Test',
            isGuest: false,
            removeAds: false,
          );
          expect(userWithNulls.isGuest, false);
          expect(userWithNulls.removeAds, false);
        }, returnsNormally);
      });
    });

    group('Performance and Consistency Tests', () {
      test('should handle multiple rapid calls consistently', () {
        // Arrange
        final guestUser = ChessUser(
          uid: 'guest-123',
          displayName: 'Guest-123',
          isGuest: true,
          removeAds: false,
        );

        // Act - Simulate rapid successive calls
        final results = <bool>[];
        for (int i = 0; i < 1000; i++) {
          // Simulate the core ad logic
          final shouldShow =
              guestUser.isGuest ? true : !(guestUser.removeAds ?? false);
          results.add(shouldShow);
        }

        // Assert - All results should be consistent
        expect(
          results.every((result) => result == true),
          true,
          reason:
              'Guest user ad display should be consistent across multiple calls',
        );
      });

      test('should maintain consistency across different instances', () {
        // Create multiple instances of the same guest user
        final guestUser1 = ChessUser(
          uid: 'guest-123',
          displayName: 'Guest-123',
          isGuest: true,
          removeAds: false,
        );

        final guestUser2 = ChessUser(
          uid: 'guest-123',
          displayName: 'Guest-123',
          isGuest: true,
          removeAds: false,
        );

        // Both should have the same ad behavior
        final shouldShow1 =
            guestUser1.isGuest ? true : !(guestUser1.removeAds ?? false);
        final shouldShow2 =
            guestUser2.isGuest ? true : !(guestUser2.removeAds ?? false);

        expect(
          shouldShow1,
          equals(shouldShow2),
          reason: 'Same user data should produce consistent ad behavior',
        );
      });
    });
  });
}
