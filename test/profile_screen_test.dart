import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chess_app/screens/profile_screen.dart';
import 'package:flutter_chess_app/providers/user_provider.dart';
import 'package:flutter_chess_app/models/user_model.dart';

void main() {
  group('ProfileScreen Widget Tests', () {
    late ChessUser testGuestUser;
    late UserProvider userProvider;

    setUp(() {
      testGuestUser = ChessUser(
        uid: 'guest-123',
        displayName: 'Guest-123',
        isGuest: true,
        removeAds: false,
      );
      userProvider = UserProvider();
      userProvider.setUser(testGuestUser);
    });

    testWidgets('should dispose properly without throwing errors', (
      WidgetTester tester,
    ) async {
      // This test verifies that the ProfileScreen can be disposed without
      // throwing the "Looking up a deactivated widget's ancestor is unsafe" error

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<UserProvider>.value(
            value: userProvider,
            child: ProfileScreen(user: testGuestUser),
          ),
        ),
      );

      // Verify the screen loads
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Simulate navigation away (which triggers dispose)
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<UserProvider>.value(
            value: userProvider,
            child: const Scaffold(body: Text('Different Screen')),
          ),
        ),
      );

      // If we get here without throwing, the dispose issue is fixed
      expect(find.text('Different Screen'), findsOneWidget);
    });

    testWidgets('should handle user provider changes correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<UserProvider>.value(
            value: userProvider,
            child: ProfileScreen(user: testGuestUser),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Guest-123'), findsOneWidget);

      // Update user in provider
      final updatedUser = testGuestUser.copyWith(displayName: 'Updated Guest');
      userProvider.setUser(updatedUser);

      await tester.pump();

      // Verify the UI updates
      expect(find.text('Updated Guest'), findsOneWidget);
    });

    testWidgets('should show sign in button for guest users', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<UserProvider>.value(
            value: userProvider,
            child: ProfileScreen(user: testGuestUser),
          ),
        ),
      );

      // Verify sign in button is shown for guest users
      expect(find.text('Sign In'), findsOneWidget);
      expect(
        find.text('Sign In or Create an Account to Save Your Progress'),
        findsOneWidget,
      );
    });

    testWidgets('should not show premium features for guest users', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<UserProvider>.value(
            value: userProvider,
            child: ProfileScreen(user: testGuestUser),
          ),
        ),
      );

      // Verify premium features section is not shown for guest users
      expect(find.text('Premium Features'), findsNothing);
      expect(find.text('Remove Ads'), findsNothing);
    });

    testWidgets('should show premium features for regular users', (
      WidgetTester tester,
    ) async {
      final regularUser = ChessUser(
        uid: 'user-123',
        displayName: 'Regular User',
        isGuest: false,
        removeAds: false,
      );

      userProvider.setUser(regularUser);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<UserProvider>.value(
            value: userProvider,
            child: ProfileScreen(user: regularUser),
          ),
        ),
      );

      // Verify premium features section is shown for regular users
      expect(find.text('Premium Features'), findsOneWidget);
      expect(find.text('Remove Ads'), findsOneWidget);
    });
  });
}
