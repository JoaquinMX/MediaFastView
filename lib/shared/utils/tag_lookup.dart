import 'dart:collection';

import '../../core/services/logging_service.dart';
import '../../features/tagging/domain/entities/tag_entity.dart';
import '../../features/tagging/domain/repositories/tag_repository.dart';

/// Lightweight cache for resolving [TagEntity] instances by identifier.
class TagLookup {
  TagLookup(this._tagRepository);

  final TagRepository _tagRepository;

  List<TagEntity>? _cachedTags;
  Map<String, TagEntity>? _tagsById;

  /// Retrieves tags for the provided [ids], preserving the incoming order and
  /// skipping any identifiers that cannot be resolved.
  Future<List<TagEntity>> getTagsByIds(Iterable<String> ids) async {
    await _ensureCache();

    final tagsById = _tagsById;
    if (tagsById == null || tagsById.isEmpty) {
      return const <TagEntity>[];
    }

    final uniqueIds = LinkedHashSet<String>.from(ids);
    return [
      for (final id in uniqueIds)
        if (tagsById.containsKey(id)) tagsById[id]!,
    ];
  }

  /// Forces the cache to reload from the repository.
  Future<void> refresh() async {
    _cachedTags = null;
    _tagsById = null;
    await _ensureCache();
  }

  /// Returns all available tags, loading them into the cache if necessary.
  Future<List<TagEntity>> getAllTags() async {
    await _ensureCache();
    return _cachedTags ?? const <TagEntity>[];
  }

  Future<void> _ensureCache() async {
    if (_cachedTags != null && _tagsById != null) {
      return;
    }

    try {
      final tags = await _tagRepository.getTags();
      _cachedTags = List<TagEntity>.unmodifiable(tags);
      _tagsById = {
        for (final tag in _cachedTags!) tag.id: tag,
      };
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to load tag cache: $error');
      LoggingService.instance.debug('Tag cache load stack trace: $stackTrace');
      rethrow;
    }
  }
}

