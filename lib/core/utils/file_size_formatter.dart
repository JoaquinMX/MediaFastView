import '../config/app_config.dart';

/// Formats a byte count as a human-readable size (e.g. `4.2 MB`).
///
/// Shared so the media grid, the full-screen viewer, and the duplicate review
/// all render sizes identically. Driven by the [AppConfig] size constants.
String formatFileSize(int bytes) {
  if (bytes < AppConfig.kbBytes) {
    return '$bytes ${AppConfig.byteSuffix}';
  }
  if (bytes < AppConfig.mbBytes) {
    return '${(bytes / AppConfig.kbBytes).toStringAsFixed(AppConfig.fileSizeDecimalPlaces)} ${AppConfig.kbSuffix}';
  }
  if (bytes < AppConfig.gbBytes) {
    return '${(bytes / AppConfig.mbBytes).toStringAsFixed(AppConfig.fileSizeDecimalPlaces)} ${AppConfig.mbSuffix}';
  }
  return '${(bytes / AppConfig.gbBytes).toStringAsFixed(AppConfig.fileSizeDecimalPlaces)} ${AppConfig.gbSuffix}';
}
