import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for managing thumbnail caching preference.
final thumbnailCachingProvider =
    StateNotifierProvider<ThumbnailCachingNotifier, bool>((ref) {
  return ThumbnailCachingNotifier();
});

/// Notifier for managing thumbnail caching state.
class ThumbnailCachingNotifier extends StateNotifier<bool> {
  ThumbnailCachingNotifier() : super(true); // Default to enabled

  void setThumbnailCaching(bool enabled) {
    debugPrint(
      'ThumbnailCachingProvider: Setting thumbnail caching from $state to $enabled',
    );
    state = enabled;
    debugPrint('ThumbnailCachingProvider: Thumbnail caching set to $enabled');
  }
}
