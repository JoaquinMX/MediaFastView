import 'package:media_fast_view/features/favorites/domain/entities/favorite_entity.dart';
import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/tag_repository.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_backup.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_folder_data.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_read_report.dart';
import 'package:media_fast_view/features/sidecar/domain/repositories/sidecar_repository.dart';

/// In-memory [MediaRepository] recording upserts. Only the methods the sidecar
/// use cases touch are implemented; anything else routes to [noSuchMethod] and
/// throws, flagging an unexpected call.
class FakeMediaRepository implements MediaRepository {
  FakeMediaRepository([List<MediaEntity> all = const []])
    : _all = List<MediaEntity>.from(all);

  final List<MediaEntity> _all;
  final List<MediaEntity> upserted = <MediaEntity>[];

  @override
  Future<List<MediaEntity>> getAllMedia() async => List<MediaEntity>.of(_all);

  @override
  Future<void> upsertMedia(List<MediaEntity> media) async =>
      upserted.addAll(media);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDirectoryRepository implements DirectoryRepository {
  FakeDirectoryRepository([List<DirectoryEntity> dirs = const []])
    : _dirs = List<DirectoryEntity>.from(dirs);

  final List<DirectoryEntity> _dirs;
  final Map<String, List<String>> updatedTags = <String, List<String>>{};

  @override
  Future<List<DirectoryEntity>> getDirectories() async =>
      List<DirectoryEntity>.of(_dirs);

  @override
  Future<DirectoryEntity?> getDirectoryById(String id) async {
    for (final directory in _dirs) {
      if (directory.id == id) {
        return directory;
      }
    }
    return null;
  }

  @override
  Future<void> updateDirectoryTags(String id, List<String> tagIds) async {
    updatedTags[id] = tagIds;
    final index = _dirs.indexWhere((directory) => directory.id == id);
    if (index >= 0) {
      _dirs[index] = _dirs[index].copyWith(tagIds: tagIds);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFavoritesRepository implements FavoritesRepository {
  FakeFavoritesRepository([List<FavoriteEntity> initial = const []])
    : _favorites = List<FavoriteEntity>.from(initial);

  final List<FavoriteEntity> _favorites;
  final List<FavoriteEntity> added = <FavoriteEntity>[];

  @override
  Future<List<FavoriteEntity>> getFavorites() async =>
      List<FavoriteEntity>.of(_favorites);

  @override
  Future<void> addFavorites(List<FavoriteEntity> favorites) async {
    added.addAll(favorites);
    _favorites.addAll(favorites);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTagRepository implements TagRepository {
  FakeTagRepository([List<TagEntity> initial = const []])
    : _tags = List<TagEntity>.from(initial);

  final List<TagEntity> _tags;

  List<TagEntity> get tags => List<TagEntity>.unmodifiable(_tags);

  @override
  Future<List<TagEntity>> getTags() async => List<TagEntity>.of(_tags);

  @override
  Future<void> createTag(TagEntity tag) async => _tags.add(tag);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory [SidecarRepository] that replays resolved folder data.
class FakeSidecarRepository implements SidecarRepository {
  FakeSidecarRepository({
    Map<String, List<SidecarFolderData>>? readData,
    Map<String, List<String>>? failures,
  }) : readData = readData ?? const <String, List<SidecarFolderData>>{},
       failures = failures ?? const <String, List<String>>{};

  /// Current tracked-root id to resolved folder data.
  final Map<String, List<SidecarFolderData>> readData;

  final Map<String, List<String>> failures;

  @override
  Future<SidecarReadReport> resolveBackupRoot(
    SidecarBackupRoot backupRoot,
    DirectoryEntity currentRoot, {
    void Function()? onFolderProcessed,
  }) async {
    for (final _ in backupRoot.manifestsByRelativeFolder.values) {
      onFolderProcessed?.call();
    }
    return SidecarReadReport(
      folders: readData[currentRoot.id] ?? const <SidecarFolderData>[],
      failures: failures[currentRoot.id] ?? const <String>[],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
