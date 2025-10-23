import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/logging_service.dart';
import '../../features/tagging/presentation/view_models/tag_management_view_model.dart';
import '../../features/tagging/presentation/view_models/tags_view_model.dart';

/// Coordinates refreshing of tag-related view models after mutations.
class TagCacheRefresher {
  TagCacheRefresher(this._ref);

  final Ref _ref;

  /// Refreshes the tag selection and tagging dashboards to reflect new data.
  Future<void> refresh() async {
    final futures = <Future<void>>[];

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

    if (futures.isNotEmpty) {
      await Future.wait(futures, eagerError: false);
    }
  }
}

/// Provider exposing the cache refresher utility.
final tagCacheRefresherProvider = Provider<TagCacheRefresher>(TagCacheRefresher.new);
