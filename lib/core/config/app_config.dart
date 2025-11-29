/// Configuration values for the app, providing customizable defaults
/// for grid columns, aspect ratios, animation settings, monitoring intervals,
/// file naming patterns, and cache settings.
class AppConfig {
  // Default values
  static const int defaultGridColumns = 3;
  static const double defaultAspectRatio = 1.0;
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration defaultMonitoringInterval = Duration(seconds: 5);
  static const String defaultFileNamingPattern = '{name}_{date}';
  static const int defaultCacheMaxSize = 100 * 1024 * 1024; // 100 MB
  static const Duration defaultCacheExpiration = Duration(days: 1);
  static const Duration defaultSlideshowMinDuration = Duration(seconds: 2);
  static const Duration defaultSlideshowMaxDuration = Duration(seconds: 15);

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
}
