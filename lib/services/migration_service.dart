import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/admob_config_model.dart';
import '../utils/constants.dart';

/// Service to handle database migrations and initial setup
///
/// Example usage:
/// ```dart
/// // In main.dart during app initialization
/// await MigrationService.runMigrations();
///
/// // To update to production AdMob IDs (admin function)
/// await MigrationService.updateToProductionConfig(
///   androidBannerAdId: 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
///   iosBannerAdId: 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
///   // ... other production IDs
/// );
/// ```
class MigrationService {
  static final Logger _logger = Logger();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Run all necessary migrations
  static Future<void> runMigrations() async {
    try {
      _logger.i('Starting migration process...');

      // Run AdMob config migration
      await _migrateAdMobConfig();

      _logger.i('All migrations completed successfully');
    } catch (e) {
      _logger.e('Migration process failed: $e');
      // Don't throw - app should continue working even if migrations fail
    }
  }

  /// Migration to create initial AdMob configuration in Firestore
  static Future<void> _migrateAdMobConfig() async {
    try {
      _logger.i('Checking AdMob configuration migration...');

      final configDoc =
          await _firestore
              .collection(Constants.admobConfigCollection)
              .doc('config')
              .get();

      if (!configDoc.exists) {
        _logger.i('AdMob config not found. Creating default configuration...');

        final defaultConfig = AdMobConfig.defaultTestConfig();

        await _firestore
            .collection(Constants.admobConfigCollection)
            .doc('config')
            .set(defaultConfig.toMap());

        _logger.i('✅ AdMob configuration created successfully');

        // Log the created configuration for verification
        _logger.i('Created AdMob config with the following test IDs:');
        _logger.i('Android Banner: ${defaultConfig.androidBannerAdId}');
        _logger.i('iOS Banner: ${defaultConfig.iosBannerAdId}');
        _logger.i(
          'Android Interstitial: ${defaultConfig.androidInterstitialAdId}',
        );
        _logger.i('iOS Interstitial: ${defaultConfig.iosInterstitialAdId}');
        _logger.i('Enabled: ${defaultConfig.enabled}');
      } else {
        _logger.i('✅ AdMob configuration already exists, skipping migration');

        // Optionally verify the existing configuration
        final existingConfig = AdMobConfig.fromMap(
          configDoc.data() as Map<String, dynamic>,
        );
        _logger.i('Existing config enabled status: ${existingConfig.enabled}');
      }
    } catch (e) {
      _logger.e('Failed to migrate AdMob configuration: $e');
      throw Exception('AdMob migration failed: $e');
    }
  }

  /// Force recreate AdMob configuration (useful for testing or updates)
  static Future<void> resetAdMobConfig() async {
    try {
      _logger.w('Force resetting AdMob configuration...');

      final defaultConfig = AdMobConfig.defaultTestConfig();

      await _firestore
          .collection(Constants.admobConfigCollection)
          .doc('config')
          .set(defaultConfig.toMap());

      _logger.i('✅ AdMob configuration reset successfully');
    } catch (e) {
      _logger.e('Failed to reset AdMob configuration: $e');
      throw Exception('AdMob reset failed: $e');
    }
  }

  /// Update AdMob configuration with production IDs (admin function)
  static Future<void> updateToProductionConfig({
    required String androidBannerAdId,
    required String iosBannerAdId,
    required String androidInterstitialAdId,
    required String iosInterstitialAdId,
    required String androidRewardedAdId,
    required String iosRewardedAdId,
    required String androidNativeAdId,
    required String iosNativeAdId,
    required String appOpenId,
    bool enabled = true,
  }) async {
    try {
      _logger.i('Updating to production AdMob configuration...');

      final productionConfig = AdMobConfig(
        appOpenAdId: appOpenId,
        androidBannerAdId: androidBannerAdId,
        iosBannerAdId: iosBannerAdId,
        androidInterstitialAdId: androidInterstitialAdId,
        iosInterstitialAdId: iosInterstitialAdId,
        androidRewardedAdId: androidRewardedAdId,
        iosRewardedAdId: iosRewardedAdId,
        androidNativeAdId: androidNativeAdId,
        iosNativeAdId: iosNativeAdId,
        enabled: enabled,
      );

      await _firestore
          .collection(Constants.admobConfigCollection)
          .doc('config')
          .set(productionConfig.toMap());

      _logger.i('✅ Production AdMob configuration updated successfully');
    } catch (e) {
      _logger.e('Failed to update production AdMob configuration: $e');
      throw Exception('Production config update failed: $e');
    }
  }

  /// Check if migrations are needed
  static Future<bool> isMigrationNeeded() async {
    try {
      final configDoc =
          await _firestore
              .collection(Constants.admobConfigCollection)
              .doc('config')
              .get();

      return !configDoc.exists;
    } catch (e) {
      _logger.e('Failed to check migration status: $e');
      return true; // Assume migration is needed if check fails
    }
  }

  /// Get migration status for debugging
  static Future<Map<String, dynamic>> getMigrationStatus() async {
    try {
      final admobExists = await _firestore
          .collection(Constants.admobConfigCollection)
          .doc('config')
          .get()
          .then((doc) => doc.exists);

      return {
        'admobConfigExists': admobExists,
        'migrationsNeeded': !admobExists,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e('Failed to get migration status: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
