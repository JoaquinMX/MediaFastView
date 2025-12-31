import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/media_library/domain/entities/media_entity.dart';
import '../../features/tagging/domain/entities/tag_entity.dart';
import '../../features/tagging/domain/use_cases/assign_tag_use_case.dart';
import '../../core/services/logging_service.dart';
import '../providers/repository_providers.dart';
import 'tag_cache_refresher.dart';
import 'tag_lookup.dart';

/// Outcome of a tag toggle operation.
enum TagMutationOutcome { added, removed, unchanged }

/// Result describing the outcome of a single tag toggle.
class TagMutationResult {
  const TagMutationResult({
    required this.outcome,
    this.updatedMedia,
    this.resolvedTags = const <TagEntity>[],
  });

  final TagMutationOutcome outcome;
  final MediaEntity? updatedMedia;
  final List<TagEntity> resolvedTags;
}

/// Coordinates tag assignment mutations for media entities.
class TagMutationService {
  const TagMutationService({
    required AssignTagUseCase assignTagUseCase,
    required TagLookup tagLookup,
    required TagCacheRefresher tagCacheRefresher,
  })  : _assignTagUseCase = assignTagUseCase,
        _tagLookup = tagLookup,
        _tagCacheRefresher = tagCacheRefresher;

  final AssignTagUseCase _assignTagUseCase;
  final TagLookup _tagLookup;
  final TagCacheRefresher _tagCacheRefresher;

  /// Toggle a [tag] on the provided [media] and return the mutation result
  /// alongside the updated media snapshot.
  Future<TagMutationResult> toggleTagForMedia(
    MediaEntity media,
    TagEntity tag,
  ) async {
    final hasTag = media.tagIds.contains(tag.id);

    if (hasTag) {
      await _assignTagUseCase.removeTagFromMedia(media.id, tag);
    } else {
      await _assignTagUseCase.assignTagToMedia(media.id, tag);
    }

    final updatedTagIds = hasTag
        ? media.tagIds.where((id) => id != tag.id).toList(growable: false)
        : [...media.tagIds, tag.id];

    final updatedMedia = media.copyWith(
      tagIds: List<String>.unmodifiable(updatedTagIds),
    );
    final resolvedTags = await _tagLookup.getTagsByIds(updatedTagIds);

    _refreshCaches();

    return TagMutationResult(
      outcome:
          hasTag ? TagMutationOutcome.removed : TagMutationOutcome.added,
      updatedMedia: updatedMedia,
      resolvedTags: resolvedTags,
    );
  }

  void _refreshCaches() {
    unawaited(Future.wait(<Future<void>>[
      _tagLookup.refresh(),
      _tagCacheRefresher.refresh(),
    ], eagerError: false).catchError((error, stackTrace) {
      LoggingService.instance
          .error('Tag cache refresh failed: $error');
      LoggingService.instance
          .debug('Tag cache refresh stack trace: $stackTrace');
    }));
  }
}

/// Provider exposing the tag mutation service.
final tagMutationServiceProvider = Provider<TagMutationService>((ref) {
  return TagMutationService(
    assignTagUseCase: ref.watch(assignTagUseCaseProvider),
    tagLookup: ref.watch(tagLookupProvider),
    tagCacheRefresher: ref.watch(tagCacheRefresherProvider),
  );
});
