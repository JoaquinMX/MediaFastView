import '../entities/tag_entity.dart';

/// Repository interface for tag operations.
/// Provides methods for managing tags in the application.
abstract class TagRepository {
  /// Retrieves all tags.
  Future<List<TagEntity>> getTags();

  /// Retrieves a tag by its ID.
  Future<TagEntity?> getTagById(String id);

  /// Creates a new tag.
  Future<void> createTag(TagEntity tag);

  /// Updates an existing tag.
  Future<void> updateTag(TagEntity tag);

  /// Deletes a tag by its ID.
  Future<void> deleteTag(String id);
}
