import '../../domain/entities/tag_entity.dart';
import '../../domain/repositories/tag_repository.dart';
import '../../../media_library/data/models/tag_model.dart';
import '../data_sources/shared_preferences_data_source.dart';
import '../isar/isar_tag_data_source.dart';
import '../persistence/hybrid_tag_persistence_bridge.dart';

/// Implementation of TagRepository using SharedPreferences.
class TagRepositoryImpl implements TagRepository {
  TagRepositoryImpl(
    IsarTagDataSource isarTagDataSource,
    SharedPreferencesTagDataSource legacyTagDataSource,
  ) : _tags = TagPersistenceBridge(
          isarTagDataSource: isarTagDataSource,
          legacyTagDataSource: legacyTagDataSource,
        );

  final TagPersistenceBridge _tags;

  @override
  Future<List<TagEntity>> getTags() async {
    final models = await _tags.loadTags();
    return models.map(_modelToEntity).toList();
  }

  @override
  Future<TagEntity?> getTagById(String id) async {
    final tags = await getTags();
    return tags.where((tag) => tag.id == id).firstOrNull;
  }

  @override
  Future<void> createTag(TagEntity tag) async {
    final model = _entityToModel(tag);
    await _tags.addTag(model);
  }

  @override
  Future<void> updateTag(TagEntity tag) async {
    final model = _entityToModel(tag);
    await _tags.updateTag(model);
  }

  @override
  Future<void> deleteTag(String id) async {
    await _tags.removeTag(id);
  }

  /// Converts TagModel to TagEntity.
  TagEntity _modelToEntity(TagModel model) {
    return TagEntity(
      id: model.id,
      name: model.name,
      color: model.color,
      createdAt: model.createdAt,
    );
  }

  /// Converts TagEntity to TagModel.
  TagModel _entityToModel(TagEntity entity) {
    return TagModel(
      id: entity.id,
      name: entity.name,
      color: entity.color,
      createdAt: entity.createdAt,
    );
  }
}
