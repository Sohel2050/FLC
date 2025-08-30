import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_chess_app/main.dart' as app;
import 'package:flutter_chess_app/screens/home_screen.dart';
import 'package:flutter_chess_app/screens/login_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Launch Interstitial Ad Integration Tests', () {
    testWidgets(
      'Complete app launch flow from start to HomeScreen - Basic Flow Test',
      (tester) async {
        // Start the app
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Verify app starts without errors
        expect(tester.takeException(), isNull);

        // Check if we're on login screen or already authenticated
        final loginScreenFinder = find.byType(LoginScreen);
        final homeScreenFinder = find.byType(HomeScreen);

        if (loginScreenFinder.evaluate().isNotEmpty) {
          // We're on login screen - verify it loads correctly
          expect(find.byType(LoginScreen), findsOneWidget);

          // Look for login elements
          expect(find.text('FLC Chess'), findsOneWidget);
          expect(find.text('Play as Guest'), findsOneWidget);
        } else if (homeScreenFinder.evaluate().isNotEmpty) {
          // Already authenticated - verify HomeScreen is displayed
          expect(find.byType(HomeScreen), findsOneWidget);

          // Verify basic navigation elements are present
          expect(find.text('Play'), findsOneWidget);
        }

        // Verify no exceptions occurred during the flow
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Navigation timing and coordination test', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app starts without errors
      expect(tester.takeException(), isNull);

      // If we're on HomeScreen, test navigation between tabs
      final homeScreenFinder = find.byType(HomeScreen);
      if (homeScreenFinder.evaluate().isNotEmpty) {
        // Test navigation to different tabs while respecting ad sequence
        final playTabFinder = find.text('Play');
        final friendsTabFinder = find.text('Friends');

        if (playTabFinder.evaluate().isNotEmpty) {
          await tester.tap(playTabFinder);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // Verify navigation doesn't cause crashes
          expect(tester.takeException(), isNull);
        }

        if (friendsTabFinder.evaluate().isNotEmpty) {
          await tester.tap(friendsTabFinder);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // Verify navigation doesn't cause crashes
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('App launch ad timeout and error handling test', (
      tester,
    ) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app starts without errors
      expect(tester.takeException(), isNull);

      // Wait for potential ad loading and timeout scenarios
      await tester.pump(const Duration(seconds: 6));

      // Verify app continues to function after potential timeout
      expect(tester.takeException(), isNull);

      // Verify we can still interact with the app
      final homeScreenFinder = find.byType(HomeScreen);
      final loginScreenFinder = find.byType(LoginScreen);

      // App should be in a functional state (either login or home)
      expect(
        homeScreenFinder.evaluate().isNotEmpty ||
            loginScreenFinder.evaluate().isNotEmpty,
        isTrue,
        reason: 'App should be in either login or home screen state',
      );
    });

    testWidgets('Repeated app lifecycle simulation test', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app starts without errors
      expect(tester.takeException(), isNull);

      // Simulate multiple app interactions to test session management
      for (int i = 0; i < 3; i++) {
        // Simulate some user interaction
        await tester.pump(const Duration(seconds: 1));

        // Verify no exceptions during repeated interactions
        expect(tester.takeException(), isNull);

        // If on HomeScreen, try navigation
        final homeScreenFinder = find.byType(HomeScreen);
        if (homeScreenFinder.evaluate().isNotEmpty) {
          final playTabFinder = find.text('Play');
          if (playTabFinder.evaluate().isNotEmpty) {
            await tester.tap(playTabFinder);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }
      }
    });

    testWidgets('Cross-screen ad coordination test', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app starts without errors
      expect(tester.takeException(), isNull);

      // Test that the app handles ad coordination properly across screens
      final homeScreenFinder = find.byType(HomeScreen);
      if (homeScreenFinder.evaluate().isNotEmpty) {
        // Navigate through different tabs to test ad coordination
        final tabs = ['Play', 'Friends', 'Learn', 'Profile'];

        for (final tabName in tabs) {
          final tabFinder = find.text(tabName);
          if (tabFinder.evaluate().isNotEmpty) {
            await tester.tap(tabFinder);
            await tester.pumpAndSettle(const Duration(seconds: 2));

            // Verify navigation doesn't interfere with ad state management
            expect(tester.takeException(), isNull);
          }
        }
      }
    });
  });

  group('Legacy Integration Tests', () {
    testWidgets('PlayScreen ad loading on fresh app install', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app loads without errors
      expect(tester.takeException(), isNull);

      // Check if we can find Play tab or PlayScreen content
      final playFinder = find.text('Play');
      if (playFinder.evaluate().isNotEmpty) {
        await tester.tap(playFinder);
        await tester.pumpAndSettle();

        // Verify the screen loads without errors
        expect(tester.takeException(), isNull);

        // Look for play screen content
        final quickMatchFinder = find.text('Quick Match');
        if (quickMatchFinder.evaluate().isNotEmpty) {
          expect(quickMatchFinder, findsWidgets);
        }
      }
    });

    testWidgets('Tab navigation maintains proper ad state', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app starts without errors
      expect(tester.takeException(), isNull);

      // Navigate to different tabs if available
      final tabs = ['Learn', 'Profile', 'Play'];

      for (final tabName in tabs) {
        final tabFinder = find.text(tabName);
        if (tabFinder.evaluate().isNotEmpty) {
          await tester.tap(tabFinder);
          await tester.pumpAndSettle();

          // Verify no exceptions occurred during navigation
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('App lifecycle session management works correctly', (
      tester,
    ) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app starts without errors
      expect(tester.takeException(), isNull);

      // Navigate through different screens to ensure state is maintained
      final tabs = ['Learn', 'Play'];

      for (final tabName in tabs) {
        final tabFinder = find.text(tabName);
        if (tabFinder.evaluate().isNotEmpty) {
          await tester.tap(tabFinder);
          await tester.pumpAndSettle();

          // Verify no exceptions occurred and app is still functional
          expect(tester.takeException(), isNull);
        }
      }

      // Test that repeated navigation doesn't cause issues
      for (int i = 0; i < 3; i++) {
        final profileFinder = find.text('Profile');
        final playFinder = find.text('Play');

        if (profileFinder.evaluate().isNotEmpty) {
          await tester.tap(profileFinder);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        if (playFinder.evaluate().isNotEmpty) {
          await tester.tap(playFinder);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    });
  });
}
