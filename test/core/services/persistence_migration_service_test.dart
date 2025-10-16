import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/persistence_migration_service.dart';
import 'package:media_fast_view/features/favorites/data/data_sources/shared_preferences_data_source.dart';
import 'package:media_fast_view/features/favorites/data/isar/isar_favorites_data_source.dart';
import 'package:media_fast_view/features/favorites/data/models/favorite_model.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:media_fast_view/features/media_library/data/data_sources/local_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/data_sources/shared_preferences_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/directory_model.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';
import 'package:media_fast_view/features/media_library/data/models/tag_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/tagging/data/data_sources/shared_preferences_data_source.dart';
import 'package:media_fast_view/features/tagging/data/isar/isar_tag_data_source.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _MockLegacyDirectoryDataSource extends Mock
    implements SharedPreferencesDirectoryDataSource {}

class _MockLegacyMediaDataSource extends Mock
    implements SharedPreferencesMediaDataSource {}

class _MockLegacyTagDataSource extends Mock
    implements SharedPreferencesTagDataSource {}

class _MockLegacyFavoritesDataSource extends Mock
    implements SharedPreferencesFavoritesDataSource {}

class _MockIsarDirectoryDataSource extends Mock
    implements IsarDirectoryDataSource {}

class _MockIsarMediaDataSource extends Mock implements IsarMediaDataSource {}

class _MockIsarTagDataSource extends Mock implements IsarTagDataSource {}

class _MockIsarFavoritesDataSource extends Mock
    implements IsarFavoritesDataSource {}

void main() {
  group('PersistenceMigrationService', () {
    late _MockSharedPreferences sharedPreferences;
    late _MockLegacyDirectoryDataSource legacyDirectoryDataSource;
    late _MockLegacyMediaDataSource legacyMediaDataSource;
    late _MockLegacyTagDataSource legacyTagDataSource;
    late _MockLegacyFavoritesDataSource legacyFavoritesDataSource;
    late _MockIsarDirectoryDataSource isarDirectoryDataSource;
    late _MockIsarMediaDataSource isarMediaDataSource;
    late _MockIsarTagDataSource isarTagDataSource;
    late _MockIsarFavoritesDataSource isarFavoritesDataSource;
    late PersistenceMigrationService migrationService;

    setUp(() {
      sharedPreferences = _MockSharedPreferences();
      legacyDirectoryDataSource = _MockLegacyDirectoryDataSource();
      legacyMediaDataSource = _MockLegacyMediaDataSource();
      legacyTagDataSource = _MockLegacyTagDataSource();
      legacyFavoritesDataSource = _MockLegacyFavoritesDataSource();
      isarDirectoryDataSource = _MockIsarDirectoryDataSource();
      isarMediaDataSource = _MockIsarMediaDataSource();
      isarTagDataSource = _MockIsarTagDataSource();
      isarFavoritesDataSource = _MockIsarFavoritesDataSource();

      migrationService = PersistenceMigrationService(
        sharedPreferences: sharedPreferences,
        legacyDirectoryDataSource: legacyDirectoryDataSource,
        legacyMediaDataSource: legacyMediaDataSource,
        legacyTagDataSource: legacyTagDataSource,
        legacyFavoritesDataSource: legacyFavoritesDataSource,
        isarDirectoryDataSource: isarDirectoryDataSource,
        isarMediaDataSource: isarMediaDataSource,
        isarTagDataSource: isarTagDataSource,
        isarFavoritesDataSource: isarFavoritesDataSource,
      );
    });

    test('short-circuits when migration already completed', () async {
      when(
        sharedPreferences.getBool(
          PersistenceMigrationService.migrationCompletedKey,
        ),
      ).thenReturn(true);

      await migrationService.migrateToIsar();

      verify(
        sharedPreferences.getBool(
          PersistenceMigrationService.migrationCompletedKey,
        ),
      ).called(1);
      verifyNever(legacyDirectoryDataSource.getDirectories());
      verifyNever(legacyMediaDataSource.getMedia());
      verifyNever(legacyTagDataSource.getTags());
      verifyNever(legacyFavoritesDataSource.getFavorites());
      verifyNever(isarDirectoryDataSource.saveDirectories(any));
      verifyNever(isarMediaDataSource.saveMedia(any));
      verifyNever(isarTagDataSource.saveTags(any));
      verifyNever(isarFavoritesDataSource.saveFavorites(any));
      verifyNever(sharedPreferences.setBool(any, any));
    });

    test('migrates payloads and marks migration as complete', () async {
      var migrationCompleted = false;
      when(
        sharedPreferences.getBool(
          PersistenceMigrationService.migrationCompletedKey,
        ),
      ).thenAnswer((_) => migrationCompleted);
      when(
        sharedPreferences.setBool(
          PersistenceMigrationService.migrationCompletedKey,
          true,
        ),
      ).thenAnswer((_) async {
        migrationCompleted = true;
        return true;
      });

      final directory = DirectoryModel(
        id: 'dir-1',
        path: '/test/path',
        name: 'Test',
        lastModified: DateTime(2023, 1, 1),
      );
      final media = MediaModel(
        id: 'media-1',
        path: '/test/path/file.jpg',
        name: 'file.jpg',
        type: MediaType.image,
        size: 1024,
        lastModified: DateTime(2023, 1, 2),
        directoryId: 'dir-1',
      );
      final tag = TagModel(
        id: 'tag-1',
        name: 'Tag',
        color: 0xFF0000,
        createdAt: DateTime(2023, 1, 3),
      );
      final favorite = FavoriteModel(
        itemId: 'media-1',
        itemType: FavoriteItemType.media,
        addedAt: DateTime(2023, 1, 4),
      );

      when(legacyDirectoryDataSource.getDirectories())
          .thenAnswer((_) async => <DirectoryModel>[directory]);
      when(legacyMediaDataSource.getMedia())
          .thenAnswer((_) async => <MediaModel>[media]);
      when(legacyTagDataSource.getTags())
          .thenAnswer((_) async => <TagModel>[tag]);
      when(legacyFavoritesDataSource.getFavorites())
          .thenAnswer((_) async => <FavoriteModel>[favorite]);

      when(isarDirectoryDataSource.saveDirectories(any))
          .thenAnswer((_) async {});
      when(isarMediaDataSource.saveMedia(any)).thenAnswer((_) async {});
      when(isarTagDataSource.saveTags(any)).thenAnswer((_) async {});
      when(isarFavoritesDataSource.saveFavorites(any))
          .thenAnswer((_) async {});

      await migrationService.migrateToIsar();

      verify(legacyDirectoryDataSource.getDirectories()).called(1);
      verify(legacyMediaDataSource.getMedia()).called(1);
      verify(legacyTagDataSource.getTags()).called(1);
      verify(legacyFavoritesDataSource.getFavorites()).called(1);

      verify(isarDirectoryDataSource.saveDirectories(<DirectoryModel>[directory]))
          .called(1);
      verify(isarMediaDataSource.saveMedia(<MediaModel>[media])).called(1);
      verify(isarTagDataSource.saveTags(<TagModel>[tag])).called(1);
      verify(isarFavoritesDataSource.saveFavorites(<FavoriteModel>[favorite]))
          .called(1);

      verify(
        sharedPreferences.setBool(
          PersistenceMigrationService.migrationCompletedKey,
          true,
        ),
      ).called(1);
      expect(migrationService.hasCompletedMigration, isTrue);
    });

    test('skips writing empty payloads but still marks completion', () async {
      when(
        sharedPreferences.getBool(
          PersistenceMigrationService.migrationCompletedKey,
        ),
      ).thenReturn(false);
      when(
        sharedPreferences.setBool(
          PersistenceMigrationService.migrationCompletedKey,
          true,
        ),
      ).thenAnswer((_) async => true);

      when(legacyDirectoryDataSource.getDirectories())
          .thenAnswer((_) async => const <DirectoryModel>[]);
      when(legacyMediaDataSource.getMedia())
          .thenAnswer((_) async => const <MediaModel>[]);
      when(legacyTagDataSource.getTags())
          .thenAnswer((_) async => const <TagModel>[]);
      when(legacyFavoritesDataSource.getFavorites())
          .thenAnswer((_) async => const <FavoriteModel>[]);

      await migrationService.migrateToIsar();

      verifyNever(isarDirectoryDataSource.saveDirectories(any));
      verifyNever(isarMediaDataSource.saveMedia(any));
      verifyNever(isarTagDataSource.saveTags(any));
      verifyNever(isarFavoritesDataSource.saveFavorites(any));
      verify(
        sharedPreferences.setBool(
          PersistenceMigrationService.migrationCompletedKey,
          true,
        ),
      ).called(1);
    });
  });
}
