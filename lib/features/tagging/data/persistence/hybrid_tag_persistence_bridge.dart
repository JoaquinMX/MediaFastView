import '../../../media_library/data/models/tag_model.dart';
import '../data_sources/shared_preferences_data_source.dart';
import '../isar/isar_tag_data_source.dart';

/// Bridge that keeps tag persistence in sync between Isar and the legacy
/// SharedPreferences implementation while repositories migrate to the new
/// storage engine.
class TagPersistenceBridge {
  const TagPersistenceBridge({
    required IsarTagDataSource isarTagDataSource,
    required SharedPreferencesTagDataSource legacyTagDataSource,
  })  : _isarTagDataSource = isarTagDataSource,
        _legacyTagDataSource = legacyTagDataSource;

  final IsarTagDataSource _isarTagDataSource;
  final SharedPreferencesTagDataSource _legacyTagDataSource;

  /// Loads tags from Isar falling back to the legacy store and seeding Isar when
  /// necessary.
  Future<List<TagModel>> loadTags() async {
    final isarTags = await _isarTagDataSource.getTags();
    if (isarTags.isNotEmpty) {
      return isarTags;
    }

    final legacyTags = await _legacyTagDataSource.getTags();
    if (legacyTags.isNotEmpty) {
      await _isarTagDataSource.saveTags(legacyTags);
    }
    return legacyTags;
  }

  Future<void> addTag(TagModel tag) async {
    await _isarTagDataSource.addTag(tag);
    await _legacyTagDataSource.addTag(tag);
  }

  Future<void> updateTag(TagModel tag) async {
    await _isarTagDataSource.updateTag(tag);
    await _legacyTagDataSource.updateTag(tag);
  }

  Future<void> removeTag(String tagId) async {
    await _isarTagDataSource.removeTag(tagId);
    await _legacyTagDataSource.removeTag(tagId);
  }
}

