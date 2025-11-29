import '../entities/tag_entity.dart';

/// Repository interface for managing tag definitions used by the media library.
abstract interface class TagRepository {
  /// Retrieves all available tags.
  Future<List<TagEntity>> getTags();

  /// Loads a single tag by its identifier.
  Future<TagEntity?> getTagById(String id);

  /// Persists a newly created [tag].
  Future<void> createTag(TagEntity tag);

  /// Persists the latest state of an existing [tag].
  Future<void> updateTag(TagEntity tag);

  /// Deletes the tag identified by [id].
  Future<void> deleteTag(String id);

  /// Removes all persisted tags.
  Future<void> clearTags();
}
