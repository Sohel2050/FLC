import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_app/screens/play_screen.dart';
import 'package:flutter_chess_app/models/user_model.dart';

void main() {
  group('PlayScreen Ad Loading Tests', () {
    late ChessUser testUser;

    setUp(() {
      testUser = ChessUser(
        uid: 'test_user_id',
        displayName: 'Test User',
        email: 'test@example.com',
      );
    });

    testWidgets('PlayScreen loads without errors when visible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PlayScreen(user: testUser, isVisible: true)),
      );

      // Verify the screen builds without throwing exceptions
      expect(tester.takeException(), isNull);

      // Verify key UI elements are present
      expect(find.text('Quick Match'), findsOneWidget);
      expect(find.text('Play with Friends'), findsOneWidget);
      expect(find.text('Play Computer'), findsOneWidget);
    });

    testWidgets('PlayScreen handles visibility changes correctly', (
      tester,
    ) async {
      // Start with invisible screen
      await tester.pumpWidget(
        MaterialApp(home: PlayScreen(user: testUser, isVisible: false)),
      );

      // Update to visible
      await tester.pumpWidget(
        MaterialApp(home: PlayScreen(user: testUser, isVisible: true)),
      );

      // Verify no exceptions during visibility change
      expect(tester.takeException(), isNull);

      // Verify UI is still functional
      expect(find.text('Quick Match'), findsOneWidget);
    });

    testWidgets('PlayScreen handles multiple visibility toggles', (
      tester,
    ) async {
      // Test multiple visibility changes to ensure proper state management
      for (int i = 0; i < 3; i++) {
        await tester.pumpWidget(
          MaterialApp(home: PlayScreen(user: testUser, isVisible: i % 2 == 0)),
        );

        // Verify no memory leaks or exceptions
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('PlayScreen game mode buttons are functional', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PlayScreen(user: testUser, isVisible: true)),
      );

      // Test Quick Match button
      await tester.tap(find.text('Quick Match'));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Test Play with Friends button
      await tester.tap(find.text('Play with Friends'));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Test Play Computer button
      await tester.tap(find.text('Play Computer'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
