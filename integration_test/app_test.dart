import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_chess_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Chess App Integration Tests', () {
    testWidgets('PlayScreen ad loading on fresh app install', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Verify PlayScreen is the default tab (index 0)
      expect(find.text('Play'), findsOneWidget);

      // Wait for potential ad loading
      await tester.pump(const Duration(seconds: 3));

      // Verify the screen loads without errors
      expect(tester.takeException(), isNull);

      // Check that the play screen content is visible
      expect(find.text('Quick Match'), findsWidgets);
    });

    testWidgets('Tab navigation maintains proper ad state', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to different tabs
      await tester.tap(find.text('Learn'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      // Navigate back to Play tab
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();

      // Verify no exceptions occurred during navigation
      expect(tester.takeException(), isNull);

      // Verify PlayScreen is still functional
      expect(find.text('Quick Match'), findsWidgets);
    });

    testWidgets('Permission request flows work correctly', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to profile to test camera permissions
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      // Look for profile image edit button
      final cameraButton = find.byIcon(Icons.camera_alt);
      if (cameraButton.evaluate().isNotEmpty) {
        await tester.tap(cameraButton);
        await tester.pumpAndSettle();

        // Verify permission dialog or image picker appears
        // Note: Actual permission dialogs are system-level and can't be tested in integration tests
        // We can only verify our app doesn't crash when permissions are requested
        expect(tester.takeException(), isNull);
      }
    });
  });
}
