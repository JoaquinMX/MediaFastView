import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../isar/isar_profile_data_source.dart';
import '../models/profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._dataSource);

  final IsarProfileDataSource _dataSource;

  @override
  Future<List<ProfileEntity>> getProfiles() async {
    final models = await _dataSource.getProfiles();
    return models.map(_toEntity).toList(growable: false);
  }

  @override
  Future<void> saveProfile(ProfileEntity profile) {
    return _dataSource.saveProfile(_toModel(profile));
  }

  @override
  Future<void> removeProfile(String id) => _dataSource.removeProfile(id);

  ProfileEntity _toEntity(ProfileModel model) => ProfileEntity(
        id: model.id,
        name: model.name,
        sortOrder: model.sortOrder,
        createdAt: model.createdAt,
      );

  ProfileModel _toModel(ProfileEntity entity) => ProfileModel(
        id: entity.id,
        name: entity.name,
        sortOrder: entity.sortOrder,
        createdAt: entity.createdAt,
      );
}
