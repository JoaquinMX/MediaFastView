import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';

import '../../core/services/logging_service.dart';
import '../../features/media_library/presentation/view_models/directory_grid_view_model.dart';
import '../../features/tagging/presentation/view_models/tag_management_view_model.dart';
import '../../features/tagging/presentation/view_models/tags_view_model.dart';

/// Coordinates refreshing of tag-related view models after mutations.
class TagCacheRefresher {
  TagCacheRefresher(this._ref);

  final Ref _ref;

  /// Refreshes the tag selection and tagging dashboards to reflect new data.
  Future<void> refresh() async {
    final futures = <Future<void>>[];
    _ref.invalidate(directoryMediaCountsProvider);

    // TagLookup is an app-lifetime cache of tag name + colour, and it is what
    // the full-screen and slideshow overlays resolve media.tagIds through. Miss
    // it and a renamed tag keeps its old name and colour there until an
    // unrelated tag assignment happens or the app restarts.
    try {
      futures.add(_ref.read(tagLookupProvider).refresh());
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to refresh TagLookup cache: $error');
      LoggingService.instance
          .debug('TagLookup refresh stack trace: $stackTrace');
    }

    try {
      final tagsViewModel = _ref.read(tagsViewModelProvider.notifier);
      futures.add(tagsViewModel.refreshTags());
    } catch (error, stackTrace) {
      LoggingService.instance
          .error('Failed to refresh TagsViewModel cache: $error');
      LoggingService.instance
          .debug('TagsViewModel refresh stack trace: $stackTrace');
    }

    try {
      final tagManagementViewModel = _ref.read(tagViewModelProvider.notifier);
      futures.add(tagManagementViewModel.loadTags());
    } catch (error, stackTrace) {
      LoggingService.instance
          .error('Failed to refresh TagViewModel cache: $error');
      LoggingService.instance
          .debug('TagViewModel refresh stack trace: $stackTrace');
    }

    try {
      final directoryViewModel = _ref.read(directoryViewModelProvider.notifier);
      futures.add(directoryViewModel.loadDirectories());
    } catch (error, stackTrace) {
      LoggingService.instance
          .error('Failed to refresh DirectoryViewModel cache: $error');
      LoggingService.instance
          .debug('DirectoryViewModel refresh stack trace: $stackTrace');
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures, eagerError: false);
    }
  }
}

/// Provider exposing the cache refresher utility.
final tagCacheRefresherProvider = Provider<TagCacheRefresher>(TagCacheRefresher.new);
