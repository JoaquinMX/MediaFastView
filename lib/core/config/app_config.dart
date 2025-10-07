import 'package:shared_preferences/shared_preferences.dart';

/// Configuration system for the app, providing customizable values
/// for grid columns, aspect ratios, animation settings, monitoring intervals,
/// file naming patterns, and cache settings. Integrates with SharedPreferences
/// for persistence with default values and user customization options.
class AppConfig {
  // Keys for SharedPreferences
  static const String _gridColumnsKey = 'gridColumns';
  static const String _aspectRatioKey = 'aspectRatio';
  static const String _animationDurationKey = 'animationDuration';
  static const String _monitoringIntervalKey = 'monitoringInterval';
  static const String _fileNamingPatternKey = 'fileNamingPattern';
  static const String _cacheMaxSizeKey = 'cacheMaxSize';
  static const String _cacheExpirationKey = 'cacheExpiration';

  // Default values
  static const int defaultGridColumns = 3;
  static const double defaultAspectRatio = 1.0;
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration defaultMonitoringInterval = Duration(seconds: 5);
  static const String defaultFileNamingPattern = '{name}_{date}';
  static const int defaultCacheMaxSize = 100 * 1024 * 1024; // 100 MB
  static const Duration defaultCacheExpiration = Duration(days: 1);

  // File size formatting constants
  static const int kbBytes = 1024;
  static const int mbBytes = kbBytes * 1024;
  static const int gbBytes = mbBytes * 1024;
  static const int fileSizeDecimalPlaces = 1;
  static const String byteSuffix = 'B';
  static const String kbSuffix = 'KB';
  static const String mbSuffix = 'MB';
  static const String gbSuffix = 'GB';

  // Test file naming constants
  static const String permissionTestFileName = '.media_fast_view_test';
  static const String writeTestFileName = '.media_fast_view_write_test';

  static SharedPreferences? _prefs;

  /// Initialize the configuration system with SharedPreferences.
  /// Must be called before accessing any configuration values.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get the number of grid columns.
  static int get gridColumns =>
      _prefs?.getInt(_gridColumnsKey) ?? defaultGridColumns;

  /// Set the number of grid columns.
  static set gridColumns(int value) {
    _prefs?.setInt(_gridColumnsKey, value);
  }

  /// Get the aspect ratio for media items.
  static double get aspectRatio =>
      _prefs?.getDouble(_aspectRatioKey) ?? defaultAspectRatio;

  /// Set the aspect ratio for media items.
  static set aspectRatio(double value) {
    _prefs?.setDouble(_aspectRatioKey, value);
  }

  /// Get the animation duration.
  static Duration get animationDuration {
    final ms = _prefs?.getInt(_animationDurationKey) ??
        defaultAnimationDuration.inMilliseconds;
    return Duration(milliseconds: ms);
  }

  /// Set the animation duration.
  static set animationDuration(Duration value) {
    _prefs?.setInt(_animationDurationKey, value.inMilliseconds);
  }

  /// Get the monitoring interval.
  static Duration get monitoringInterval {
    final ms = _prefs?.getInt(_monitoringIntervalKey) ??
        defaultMonitoringInterval.inMilliseconds;
    return Duration(milliseconds: ms);
  }

  /// Set the monitoring interval.
  static set monitoringInterval(Duration value) {
    _prefs?.setInt(_monitoringIntervalKey, value.inMilliseconds);
  }

  /// Get the file naming pattern.
  static String get fileNamingPattern =>
      _prefs?.getString(_fileNamingPatternKey) ?? defaultFileNamingPattern;

  /// Set the file naming pattern.
  static set fileNamingPattern(String value) {
    _prefs?.setString(_fileNamingPatternKey, value);
  }

  /// Get the maximum cache size in bytes.
  static int get cacheMaxSize =>
      _prefs?.getInt(_cacheMaxSizeKey) ?? defaultCacheMaxSize;

  /// Set the maximum cache size in bytes.
  static set cacheMaxSize(int value) {
    _prefs?.setInt(_cacheMaxSizeKey, value);
  }

  /// Get the cache expiration duration.
  static Duration get cacheExpiration {
    final ms = _prefs?.getInt(_cacheExpirationKey) ??
        defaultCacheExpiration.inMilliseconds;
    return Duration(milliseconds: ms);
  }

  /// Set the cache expiration duration.
  static set cacheExpiration(Duration value) {
    _prefs?.setInt(_cacheExpirationKey, value.inMilliseconds);
  }

  /// Reset all configuration values to defaults.
  static void resetToDefaults() {
    gridColumns = defaultGridColumns;
    aspectRatio = defaultAspectRatio;
    animationDuration = defaultAnimationDuration;
    monitoringInterval = defaultMonitoringInterval;
    fileNamingPattern = defaultFileNamingPattern;
    cacheMaxSize = defaultCacheMaxSize;
    cacheExpiration = defaultCacheExpiration;
  }
}