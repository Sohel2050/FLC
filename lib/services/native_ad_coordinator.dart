/// Simple coordinator to prevent multiple screens from loading native ads simultaneously
class NativeAdCoordinator {
  static String? _currentLoadingScreen;
  static final Set<String> _loadingScreens = <String>{};

  /// Request permission to load native ad for a specific screen
  /// Returns true if permission granted, false if another screen is already loading
  static bool requestPermission(String screenName) {
    // If this screen is already loading, allow it to continue
    if (_loadingScreens.contains(screenName)) {
      return true;
    }

    // If no other screen is loading, grant permission
    if (_loadingScreens.isEmpty) {
      _loadingScreens.add(screenName);
      _currentLoadingScreen = screenName;
      return true;
    }

    // Another screen is already loading, deny permission
    return false;
  }

  /// Release native ad permission for a specific screen
  static void releasePermission(String screenName) {
    _loadingScreens.remove(screenName);
    if (_currentLoadingScreen == screenName) {
      _currentLoadingScreen = null;
    }
  }

  /// Check if a specific screen has permission to load native ads
  static bool hasPermission(String screenName) {
    return _loadingScreens.contains(screenName);
  }

  /// Get the current screen that has native ad permission
  static String? get currentLoadingScreen => _currentLoadingScreen;

  /// Clear all permissions (useful for cleanup)
  static void clearAll() {
    _loadingScreens.clear();
    _currentLoadingScreen = null;
  }
}
