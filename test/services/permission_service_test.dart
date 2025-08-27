import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_app/services/permission_service.dart';

void main() {
  group('PermissionService', () {
    late PermissionService permissionService;

    setUp(() {
      permissionService = PermissionService();
    });

    test('should be a singleton', () {
      final instance1 = PermissionService();
      final instance2 = PermissionService();
      expect(instance1, equals(instance2));
    });

    test('should have all required methods', () {
      expect(permissionService.isMicrophonePermissionGranted, isA<Function>());
      expect(permissionService.isCameraPermissionGranted, isA<Function>());
      expect(permissionService.isStoragePermissionGranted, isA<Function>());
      expect(permissionService.requestMicrophonePermission, isA<Function>());
      expect(permissionService.requestCameraPermission, isA<Function>());
      expect(permissionService.requestStoragePermission, isA<Function>());
      expect(
        permissionService.handlePermanentlyDeniedPermission,
        isA<Function>(),
      );
      expect(permissionService.checkMultiplePermissions, isA<Function>());
      expect(permissionService.requestMultiplePermissions, isA<Function>());
    });

    test(
      'checkMultiplePermissions should return empty map when no permissions requested',
      () async {
        final results = await permissionService.checkMultiplePermissions();
        expect(results, isEmpty);
      },
    );
  });

  group('PermissionResult', () {
    test('should have all required values', () {
      expect(PermissionResult.values, hasLength(3));
      expect(PermissionResult.values, contains(PermissionResult.granted));
      expect(PermissionResult.values, contains(PermissionResult.denied));
      expect(
        PermissionResult.values,
        contains(PermissionResult.permanentlyDenied),
      );
    });
  });
}
