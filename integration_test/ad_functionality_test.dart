import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chess_app/main.dart';
import 'package:flutter_chess_app/providers/admob_provider.dart';
import 'package:flutter_chess_app/providers/user_provider.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Ad Functionality Integration Tests', () {
    setUpAll(() async {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    });

    tearDown(() async {
      // Clean up by signing out after each test
      await FirebaseAuth.instance.signOut();
    });

    testWidgets('Guest user should see app open ads on app launch', (
      WidgetTester tester,
    ) async {
      // This test verifies that guest users can see app open ads

      // Launch the app
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => AdMobProvider()),
          ],
          child: const MyApp(),
        ),
      );

      // Wait for initial load
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Create a guest user session
      final userService = UserService();
      final guestUser = await userService.signInAnonymously();

      // Verify guest user was created
      expect(guestUser.isGuest, true);
      expect(guestUser.removeAds, false);

      // Pump the widget tree to trigger ad loading
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify that the AdMobProvider is configured to show ads for guest users
      final adMobProvider =
          tester
                  .widget<MultiProvider>(find.byType(MultiProvider))
                  .providers
                  .whereType<ChangeNotifierProvider<AdMobProvider>>()
                  .first
                  .create(null)
              as AdMobProvider;

      // Wait for AdMob config to load
      await adMobProvider.loadAdMobConfig();
      await tester.pumpAndSettle();

      // Verify ad configuration is loaded
      expect(adMobProvider.adMobConfig, isNotNull);
      expect(adMobProvider.isAdsEnabled, true);

      // Verify that ads should be shown for this guest user
      final shouldShowAds = adMobProvider.shouldShowAppLaunchAdForGuestUser(
        guestUser,
      );
      expect(
        shouldShowAds,
        true,
        reason: 'Guest users should see app launch ads',
      );
    });

    testWidgets('Guest user session persistence maintains ad functionality', (
      WidgetTester tester,
    ) async {
      // This test verifies that persistent guest users maintain ad functionality

      // First, create a guest user
      final userService = UserService();
      final guestUser = await userService.signInAnonymously();

      expect(guestUser.isGuest, true);
      expect(guestUser.uid, isNotNull);

      // Launch the app with the existing guest session
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => AdMobProvider()),
          ],
          child: const MyApp(),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify the guest session is restored
      final currentUser = FirebaseAuth.instance.currentUser;
      expect(currentUser, isNotNull);
      expect(currentUser!.isAnonymous, true);

      // Verify ad functionality is maintained
      final adMobProvider =
          tester
                  .widget<MultiProvider>(find.byType(MultiProvider))
                  .providers
                  .whereType<ChangeNotifierProvider<AdMobProvider>>()
                  .first
                  .create(null)
              as AdMobProvider;

      await adMobProvider.loadAdMobConfig();
      await tester.pumpAndSettle();

      final shouldShowAds = adMobProvider.shouldShowAppLaunchAdForGuestUser(
        guestUser,
      );
      expect(
        shouldShowAds,
        true,
        reason: 'Persistent guest users should maintain ad functionality',
      );
    });

    testWidgets('Ad frequency rules work correctly for guest users', (
      WidgetTester tester,
    ) async {
      // This test verifies that ad frequency rules are applied correctly for guest users

      final userService = UserService();
      final guestUser = await userService.signInAnonymously();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => AdMobProvider()),
          ],
          child: const MyApp(),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      final adMobProvider =
          tester
                  .widget<MultiProvider>(find.byType(MultiProvider))
                  .providers
                  .whereType<ChangeNotifierProvider<AdMobProvider>>()
                  .first
                  .create(null)
              as AdMobProvider;

      await adMobProvider.loadAdMobConfig();
      await tester.pumpAndSettle();

      // Verify that guest users follow the same ad frequency rules as regular users
      final shouldShowAds = adMobProvider.shouldShowAppLaunchAdForGuestUser(
        guestUser,
      );
      expect(shouldShowAds, true);

      // Verify that the ad configuration is consistent
      expect(adMobProvider.appOpenAdUnitId, isNotNull);
      expect(adMobProvider.appOpenAdUnitId, isNotEmpty);
    });

    testWidgets('Regular user with ad removal should not see ads', (
      WidgetTester tester,
    ) async {
      // This test verifies that regular users with ad removal don't see ads

      // Create a mock regular user with ad removal
      final regularUser = ChessUser(
        uid: 'test-user-123',
        displayName: 'Test User',
        isGuest: false,
        removeAds: true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => AdMobProvider()),
          ],
          child: const MyApp(),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      final adMobProvider =
          tester
                  .widget<MultiProvider>(find.byType(MultiProvider))
                  .providers
                  .whereType<ChangeNotifierProvider<AdMobProvider>>()
                  .first
                  .create(null)
              as AdMobProvider;

      await adMobProvider.loadAdMobConfig();
      await tester.pumpAndSettle();

      // Verify that regular users with ad removal don't see ads
      final shouldShowAds = adMobProvider.shouldShowAppLaunchAdForGuestUser(
        regularUser,
      );
      expect(
        shouldShowAds,
        false,
        reason: 'Regular users with ad removal should not see ads',
      );
    });

    testWidgets('Regular user without ad removal should see ads', (
      WidgetTester tester,
    ) async {
      // This test verifies that regular users without ad removal see ads

      // Create a mock regular user without ad removal
      final regularUser = ChessUser(
        uid: 'test-user-456',
        displayName: 'Test User 2',
        isGuest: false,
        removeAds: false,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => AdMobProvider()),
          ],
          child: const MyApp(),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      final adMobProvider =
          tester
                  .widget<MultiProvider>(find.byType(MultiProvider))
                  .providers
                  .whereType<ChangeNotifierProvider<AdMobProvider>>()
                  .first
                  .create(null)
              as AdMobProvider;

      await adMobProvider.loadAdMobConfig();
      await tester.pumpAndSettle();

      // Verify that regular users without ad removal see ads
      final shouldShowAds = adMobProvider.shouldShowAppLaunchAdForGuestUser(
        regularUser,
      );
      expect(
        shouldShowAds,
        true,
        reason: 'Regular users without ad removal should see ads',
      );
    });

    testWidgets('Ad preferences maintained during guest to regular user upgrade', (
      WidgetTester tester,
    ) async {
      // This test simulates a guest user upgrading to a regular account

      // Start with a guest user
      final userService = UserService();
      final guestUser = await userService.signInAnonymously();

      expect(guestUser.isGuest, true);
      expect(guestUser.removeAds, false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => AdMobProvider()),
          ],
          child: const MyApp(),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      final adMobProvider =
          tester
                  .widget<MultiProvider>(find.byType(MultiProvider))
                  .providers
                  .whereType<ChangeNotifierProvider<AdMobProvider>>()
                  .first
                  .create(null)
              as AdMobProvider;

      await adMobProvider.loadAdMobConfig();
      await tester.pumpAndSettle();

      // Verify guest user sees ads
      final shouldShowAdsForGuest = adMobProvider
          .shouldShowAppLaunchAdForGuestUser(guestUser);
      expect(shouldShowAdsForGuest, true);

      // Simulate upgrade to regular user (same UID, but not guest anymore)
      final upgradedUser = ChessUser(
        uid: guestUser.uid,
        displayName: 'Upgraded User',
        isGuest: false,
        removeAds:
            false, // Guest users can't purchase ad removal, so this remains false
      );

      // Verify upgraded user still sees ads (since they didn't purchase ad removal)
      final shouldShowAdsForUpgraded = adMobProvider
          .shouldShowAppLaunchAdForGuestUser(upgradedUser);
      expect(
        shouldShowAdsForUpgraded,
        true,
        reason: 'Upgraded users without ad removal should see ads',
      );
    });
  });
}
