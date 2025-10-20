import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:media_fast_view/core/services/isar_database.dart';
import 'package:media_fast_view/features/media_library/data/isar/directory_collection.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/directory_model.dart';

class _FakeIsarDatabase extends IsarDatabase {
  _FakeIsarDatabase()
      : super(
          schemas: const [],
          openIsar: _throwingOpen,
        );

  static Future<Isar> _throwingOpen(
    List<CollectionSchema<dynamic>> schemas, {
    String? directory,
    String? name,
  }) async {
    throw UnimplementedError();
  }

  @override
  bool get isOpen => true;

  @override
  Isar get instance => throw UnimplementedError();
}

class _InMemoryDirectoryCollectionStore implements DirectoryCollectionStore {
  final Map<Id, DirectoryCollection> _data = <Id, DirectoryCollection>{};

  @override
  Future<void> clear() async {
    _data.clear();
  }

  @override
  Future<void> deleteById(Id id) async {
    _data.remove(id);
  }

  @override
  Future<List<DirectoryCollection>> getAll() async {
    return _data.values.map(_clone).toList(growable: false);
  }

  @override
  Future<DirectoryCollection?> getByDirectoryId(String directoryId) async {
    final directory = _data[Isar.fastHash(directoryId)];
    return directory != null ? _clone(directory) : null;
  }

  @override
  Future<void> put(DirectoryCollection directory) async {
    _data[Isar.fastHash(directory.directoryId)] = _clone(directory);
  }

  @override
  Future<void> putAll(List<DirectoryCollection> directories) async {
    for (final directory in directories) {
      await put(directory);
    }
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) {
    return action();
  }

  DirectoryCollection _clone(DirectoryCollection directory) {
    return directory.toModel().toCollection();
  }
}

void main() {
  group('IsarDirectoryDataSource', () {
    late _FakeIsarDatabase database;
    late _InMemoryDirectoryCollectionStore store;
    late IsarDirectoryDataSource dataSource;

    setUp(() {
      database = _FakeIsarDatabase();
      store = _InMemoryDirectoryCollectionStore();
      dataSource = IsarDirectoryDataSource(
        database,
        directoryStoreBuilder: (_) => store,
      );
    });

    DirectoryModel _buildDirectory({
      required String id,
      String? name,
    }) {
      return DirectoryModel(
        id: id,
        path: '/path/$id',
        name: name ?? 'Directory $id',
        tagIds: <String>['tag-$id'],
        lastModified: DateTime.utc(2024, 1, 1),
        bookmarkData: 'bookmark-$id',
      );
    }

    test('returns empty list when no directories persisted', () async {
      final directories = await dataSource.getDirectories();

      expect(directories, isEmpty);
    });

    test('addDirectory stores directory data', () async {
      final model = _buildDirectory(id: 'dir-1');

      await dataSource.addDirectory(model);

      final directories = await dataSource.getDirectories();
      expect(directories, equals(<DirectoryModel>[model]));
    });

    test('getDirectoryById retrieves a stored directory', () async {
      final model = _buildDirectory(id: 'dir-1');
      await dataSource.addDirectory(model);

      final result = await dataSource.getDirectoryById('dir-1');

      expect(result, equals(model));
    });

    test('getDirectoryById returns null when directory missing', () async {
      final result = await dataSource.getDirectoryById('unknown');

      expect(result, isNull);
    });

    test('saveDirectories replaces existing entries', () async {
      final original = _buildDirectory(id: 'dir-1', name: 'Original');
      await dataSource.addDirectory(original);
      final replacement = _buildDirectory(id: 'dir-2', name: 'Replacement');

      await dataSource.saveDirectories(<DirectoryModel>[replacement]);

      final directories = await dataSource.getDirectories();
      expect(directories, equals(<DirectoryModel>[replacement]));
    });

    test('removeDirectory deletes the specified directory', () async {
      final modelA = _buildDirectory(id: 'dir-1');
      final modelB = _buildDirectory(id: 'dir-2');
      await dataSource.saveDirectories(<DirectoryModel>[modelA, modelB]);

      await dataSource.removeDirectory(modelA.id);

      final directories = await dataSource.getDirectories();
      expect(directories, equals(<DirectoryModel>[modelB]));
    });

    test('updateDirectory overwrites persisted values', () async {
      final original = _buildDirectory(id: 'dir-1', name: 'Original');
      await dataSource.addDirectory(original);

      final updated = original.copyWith(name: 'Updated');
      await dataSource.updateDirectory(updated);

      final directories = await dataSource.getDirectories();
      expect(directories, equals(<DirectoryModel>[updated]));
    });

    test('clearDirectories removes all entries', () async {
      await dataSource.saveDirectories(
        <DirectoryModel>[
          _buildDirectory(id: 'dir-1'),
          _buildDirectory(id: 'dir-2'),
        ],
      );

      await dataSource.clearDirectories();

      final directories = await dataSource.getDirectories();
      expect(directories, isEmpty);
    });
  });
}
