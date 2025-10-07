import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing thumbnail caching preference.
final thumbnailCachingProvider = StateNotifierProvider<ThumbnailCachingNotifier, bool>((ref) {
  return ThumbnailCachingNotifier();
});

/// Notifier for managing thumbnail caching state.
class ThumbnailCachingNotifier extends StateNotifier<bool> {
  ThumbnailCachingNotifier() : super(true) { // Default to enabled
    _loadThumbnailCaching();
  }

  static const String _thumbnailCachingKey = 'thumbnail_caching_enabled';

  Future<void> _loadThumbnailCaching() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_thumbnailCachingKey) ?? true;
  }

  Future<void> setThumbnailCaching(bool enabled) async {
    debugPrint('ThumbnailCachingProvider: Setting thumbnail caching from $state to $enabled');
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_thumbnailCachingKey, enabled);
    debugPrint('ThumbnailCachingProvider: Thumbnail caching set to $enabled');
  }
}