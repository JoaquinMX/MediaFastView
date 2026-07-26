import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_directory_cover_data_source.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_cover_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

import '../../../../helpers/in_memory_isar_stores.dart';

void main() {
  late FakeIsarDatabase database;
  late InMemoryDirectoryCoverCollectionStore store;
  late IsarDirectoryCoverDataSource firstProfile;
  late IsarDirectoryCoverDataSource secondProfile;

  DirectoryCoverEntity cover(
    String directoryPath,
    String fileName, {
    MediaType mediaType = MediaType.image,
  }) {
    return DirectoryCoverEntity.media(
      directoryPath: directoryPath,
      sourceFileName: fileName,
      mediaType: mediaType,
      updatedAt: DateTime(2025, 1, 1),
    );
  }

  setUp(() {
    database = FakeIsarDatabase();
    store = InMemoryDirectoryCoverCollectionStore();
    firstProfile = IsarDirectoryCoverDataSource(
      database,
      profileId: 'profile-one',
      storeBuilder: (_) => store,
    );
    secondProfile = IsarDirectoryCoverDataSource(
      database,
      profileId: 'profile-two',
      storeBuilder: (_) => store,
    );
  });

  test('keeps covers isolated between profiles', () async {
    await firstProfile.saveCover(cover('/library/photos', 'one.jpg'));
    await secondProfile.saveCover(cover('/library/photos', 'two.jpg'));

    expect(
      (await firstProfile.getCover('/library/photos'))?.sourceFileName,
      'one.jpg',
    );
    expect(
      (await secondProfile.getCover('/library/photos'))?.sourceFileName,
      'two.jpg',
    );

    await firstProfile.clearCovers();
    expect(await firstProfile.getCover('/library/photos'), isNull);
    expect(await secondProfile.getCover('/library/photos'), isNotNull);
  });

  test('persists an explicit no-cover choice', () async {
    await firstProfile.saveCover(
      DirectoryCoverEntity.none(
        directoryPath: '/library/photos',
        updatedAt: DateTime(2025, 1, 1),
      ),
    );

    final saved = await firstProfile.getCover('/library/photos');

    expect(saved?.mode, DirectoryCoverMode.none);
    expect(saved?.sourceFileName, isNull);
    expect(saved?.mediaType, isNull);
  });

  test('renames a selected file and clears it when moved away', () async {
    await firstProfile.saveCover(cover('/library/photos', 'old.jpg'));

    await firstProfile.reconcileMediaMove(
      oldPath: '/library/photos/old.jpg',
      newPath: '/library/photos/new.jpg',
    );
    expect(
      (await firstProfile.getCover('/library/photos'))?.sourceFileName,
      'new.jpg',
    );

    await firstProfile.reconcileMediaMove(
      oldPath: '/library/photos/new.jpg',
      newPath: '/library/archive/new.jpg',
    );
    expect(await firstProfile.getCover('/library/photos'), isNull);
  });

  test('rebases covers for a moved directory tree', () async {
    await firstProfile.saveCover(cover('/library/trip', 'cover.jpg'));
    await firstProfile.saveCover(cover('/library/trip/day-one', 'morning.mov'));
    await firstProfile.saveCover(cover('/library/other', 'other.jpg'));

    await firstProfile.rebaseDirectoryTree(
      oldRootPath: '/library/trip',
      newRootPath: '/archive/trip',
    );

    expect(await firstProfile.getCover('/library/trip'), isNull);
    expect(
      (await firstProfile.getCover('/archive/trip'))?.sourceFileName,
      'cover.jpg',
    );
    expect(
      (await firstProfile.getCover('/archive/trip/day-one'))?.sourceFileName,
      'morning.mov',
    );
    expect(await firstProfile.getCover('/library/other'), isNotNull);
  });

  test('removes a deleted source and directory subtree', () async {
    await firstProfile.saveCover(cover('/library/trip', 'cover.jpg'));
    await firstProfile.saveCover(cover('/library/trip/day-one', 'morning.jpg'));

    await firstProfile.removeCoverForSource('/library/trip/cover.jpg');
    expect(await firstProfile.getCover('/library/trip'), isNull);

    await firstProfile.removeCoversUnder('/library/trip');
    expect(await firstProfile.getCover('/library/trip/day-one'), isNull);
  });
}
