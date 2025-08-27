import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'dart:io';

void main() {
  group('ProfileImageWidget Camera Permission Tests', () {
    testWidgets('should show camera option when editable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileImageWidget(
              isEditable: true,
              onImageSelected: (File? file) {},
              onAvatarSelected: (String? avatar) {},
            ),
          ),
        ),
      );

      // Tap the camera button
      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();

      // Verify camera option is shown
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Choose Avatar'), findsOneWidget);
    });

    testWidgets('should show remove photo option when image exists', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileImageWidget(
              isEditable: true,
              imageUrl: 'test_image.jpg',
              onImageSelected: (File? file) {},
              onAvatarSelected: (String? avatar) {},
            ),
          ),
        ),
      );

      // Tap the camera button
      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();

      // Verify remove photo option is shown
      expect(find.text('Remove Photo'), findsOneWidget);
    });

    testWidgets('should not show camera button when not editable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileImageWidget(
              isEditable: false,
              onImageSelected: (File? file) {},
              onAvatarSelected: (String? avatar) {},
            ),
          ),
        ),
      );

      // Verify camera button is not shown
      expect(find.byIcon(Icons.camera_alt), findsNothing);
    });
  });
}
