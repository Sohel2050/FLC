import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admob_provider.dart';
import '../services/migration_service.dart';
import '../models/admob_config_model.dart';

/// Admin utility screen for managing AdMob configuration
/// This is useful for development and testing purposes
///
/// To access this screen, you can add a debug button in your app or
/// navigate to it directly during development:
///
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (context) => AdMobAdminScreen()),
/// );
/// ```
class AdMobAdminScreen extends StatefulWidget {
  const AdMobAdminScreen({super.key});

  @override
  State<AdMobAdminScreen> createState() => _AdMobAdminScreenState();
}

class _AdMobAdminScreenState extends State<AdMobAdminScreen> {
  Map<String, dynamic>? _migrationStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMigrationStatus();
  }

  Future<void> _loadMigrationStatus() async {
    setState(() => _isLoading = true);
    try {
      final status = await MigrationService.getMigrationStatus();
      setState(() => _migrationStatus = status);
    } catch (e) {
      _showSnackBar('Failed to load status: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _runMigrations() async {
    setState(() => _isLoading = true);
    try {
      await MigrationService.runMigrations();
      _showSnackBar('Migrations completed successfully');
      await _loadMigrationStatus();

      // Reload AdMob provider
      if (mounted) {
        await Provider.of<AdMobProvider>(
          context,
          listen: false,
        ).loadAdMobConfig();
      }
    } catch (e) {
      _showSnackBar('Migration failed: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _resetAdMobConfig() async {
    final confirmed = await _showConfirmDialog(
      'Reset AdMob Config',
      'This will reset the AdMob configuration to default test values. Continue?',
    );

    if (confirmed) {
      setState(() => _isLoading = true);
      try {
        await MigrationService.resetAdMobConfig();
        _showSnackBar('AdMob config reset successfully');
        await _loadMigrationStatus();

        // Reload AdMob provider
        if (mounted) {
          await Provider.of<AdMobProvider>(
            context,
            listen: false,
          ).loadAdMobConfig();
        }
      } catch (e) {
        _showSnackBar('Reset failed: $e', isError: true);
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAdsEnabled() async {
    final adMobProvider = Provider.of<AdMobProvider>(context, listen: false);
    final currentConfig = adMobProvider.adMobConfig;

    if (currentConfig != null) {
      setState(() => _isLoading = true);
      try {
        final updatedConfig = currentConfig.copyWith(
          enabled: !currentConfig.enabled,
        );
        await adMobProvider.updateAdMobConfig(updatedConfig);
        _showSnackBar(
          'Ads ${updatedConfig.enabled ? 'enabled' : 'disabled'} successfully',
        );
      } catch (e) {
        _showSnackBar('Failed to toggle ads: $e', isError: true);
      }
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(title),
                content: Text(content),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AdMob Admin'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Consumer<AdMobProvider>(
                builder: (context, adMobProvider, child) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Warning banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text(
                                    'ADMIN PANEL',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                'This screen is for development and testing only. Do not use in production.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Migration Status
                        _buildSection('Migration Status', Icons.storage, [
                          if (_migrationStatus != null) ...[
                            _buildStatusRow(
                              'AdMob Config Exists',
                              _migrationStatus!['admobConfigExists'],
                            ),
                            _buildStatusRow(
                              'Migrations Needed',
                              _migrationStatus!['migrationsNeeded'],
                            ),
                            if (_migrationStatus!['error'] != null)
                              _buildStatusRow(
                                'Error',
                                _migrationStatus!['error'],
                                isError: true,
                              ),
                          ] else
                            const Text('Loading...'),
                        ]),

                        const SizedBox(height: 16),

                        // AdMob Provider Status
                        _buildSection(
                          'AdMob Provider Status',
                          Icons.ads_click,
                          [
                            _buildStatusRow(
                              'Config Loaded',
                              adMobProvider.adMobConfig != null,
                            ),
                            _buildStatusRow(
                              'Ads Enabled',
                              adMobProvider.isAdsEnabled,
                            ),
                            _buildStatusRow(
                              'Is Loading',
                              adMobProvider.isLoading,
                            ),
                            if (adMobProvider.error != null)
                              _buildStatusRow(
                                'Error',
                                adMobProvider.error!,
                                isError: true,
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Current Configuration
                        if (adMobProvider.adMobConfig != null)
                          _buildSection(
                            'Current Configuration',
                            Icons.settings,
                            [
                              _buildConfigRow(
                                'Android Banner',
                                adMobProvider.adMobConfig!.androidBannerAdId,
                              ),
                              _buildConfigRow(
                                'iOS Banner',
                                adMobProvider.adMobConfig!.iosBannerAdId,
                              ),
                              _buildConfigRow(
                                'Android Interstitial',
                                adMobProvider
                                    .adMobConfig!
                                    .androidInterstitialAdId,
                              ),
                              _buildConfigRow(
                                'iOS Interstitial',
                                adMobProvider.adMobConfig!.iosInterstitialAdId,
                              ),
                              _buildStatusRow(
                                'Enabled',
                                adMobProvider.adMobConfig!.enabled,
                              ),
                              _buildConfigRow(
                                'Last Updated',
                                adMobProvider.adMobConfig!.lastUpdated
                                    .toString(),
                              ),
                            ],
                          ),

                        const SizedBox(height: 24),

                        // Actions
                        _buildSection('Actions', Icons.build, [
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _runMigrations,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Run Migrations'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _resetAdMobConfig,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset AdMob Config'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  adMobProvider.adMobConfig != null
                                      ? _toggleAdsEnabled
                                      : null,
                              icon: Icon(
                                adMobProvider.isAdsEnabled
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              label: Text(
                                adMobProvider.isAdsEnabled
                                    ? 'Disable Ads'
                                    : 'Enable Ads',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    adMobProvider.isAdsEnabled
                                        ? Colors.red
                                        : Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _loadMigrationStatus,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh Status'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, dynamic value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Icon(
            value == true
                ? Icons.check_circle
                : value == false
                ? Icons.cancel
                : Icons.info,
            color:
                isError
                    ? Colors.red
                    : value == true
                    ? Colors.green
                    : value == false
                    ? Colors.red
                    : Colors.blue,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            value.toString(),
            style: TextStyle(
              color: isError ? Colors.red : null,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
