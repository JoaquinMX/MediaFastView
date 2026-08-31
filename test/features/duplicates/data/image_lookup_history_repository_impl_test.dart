import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/duplicates/data/data_sources/image_lookup_history_data_source.dart';
import 'package:media_fast_view/features/duplicates/data/isar/image_lookup_history_collection.dart';
import 'package:media_fast_view/features/duplicates/data/repositories/image_lookup_history_repository_impl.dart';
import 'package:media_fast_view/features/duplicates/data/services/image_lookup_session_serializer.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_candidate.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_sensitivity.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_match.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_query.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_result.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_session.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_source.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

class _FakeHistoryDataSource implements ImageLookupHistoryDataSource {
  final Map<String, ImageLookupHistoryCollection> rows =
      <String, ImageLookupHistoryCollection>{};

  @override
  Future<void> clearProfile(String profileId) async {
    rows.removeWhere((_, row) => row.profileId == profileId);
  }

  @override
  Future<void> delete(String sessionId) async {
    rows.remove(sessionId);
  }

  @override
  Future<List<ImageLookupHistoryCollection>> getForProfile(
    String profileId,
  ) async {
    final scoped = rows.values
        .where((row) => row.profileId == profileId)
        .toList(growable: false);
    scoped.sort((first, second) => second.createdAt.compareTo(first.createdAt));
    return scoped;
  }

  @override
  Future<void> put(ImageLookupHistoryCollection session) async {
    rows[session.sessionId] = session;
  }
}

ImageLookupSession _session(
  String id, {
  String profileId = 'profile-a',
  int day = 1,
  MediaType mediaType = MediaType.image,
}) {
  final extension = mediaType == MediaType.video ? 'mov' : 'jpg';
  final source = ImageLookupSource(
    path: '/queries/$id.$extension',
    name: '$id.$extension',
    size: 123,
    lastModified: DateTime(2024, 1, day),
    mediaType: mediaType,
    bookmarkData: 'bookmark-$id',
  );
  final media = MediaEntity(
    id: 'media-$id',
    path: '/library/$id.$extension',
    name: '$id.$extension',
    type: mediaType,
    size: 456,
    lastModified: DateTime(2024, 1, day),
    tagIds: const <String>['tag'],
    directoryId: 'directory',
  );
  return ImageLookupSession(
    id: id,
    profileId: profileId,
    createdAt: DateTime(2024, 1, day),
    sensitivity: DuplicateSensitivity.balanced,
    hasPartialCoverage: true,
    searchedLibraryImages: 42,
    results: <ImageLookupResult>[
      ImageLookupResult(
        source: source,
        query: ImageLookupQuery(
          source: source,
          hash: 7,
          width: 800,
          height: 600,
        ),
        matches: <ImageLookupMatch>[
          ImageLookupMatch(
            candidate: DuplicateCandidate(
              media: media,
              width: 400,
              height: 300,
              hash: 3,
            ),
            distance: 1,
          ),
        ],
      ),
    ],
  );
}

void main() {
  test('serializer preserves the lookup snapshot and bookmark', () {
    const serializer = ImageLookupSessionSerializer();
    final original = _session('session', mediaType: MediaType.video);

    final decoded = serializer.decode(serializer.encode(original));

    expect(decoded.id, original.id);
    expect(decoded.profileId, original.profileId);
    expect(decoded.hasPartialCoverage, isTrue);
    expect(decoded.searchedLibraryImages, 42);
    expect(decoded.results.single.source.bookmarkData, 'bookmark-session');
    expect(decoded.results.single.source.mediaType, MediaType.video);
    expect(
      decoded.results.single.matches.single.candidate.media.type,
      MediaType.video,
    );
    expect(decoded.results.single.query!.hash, 7);
    expect(decoded.results.single.matches.single.distance, 1);
    expect(
      decoded.results.single.matches.single.candidate.media.tagIds,
      const <String>['tag'],
    );
  });

  test('repository retains only the newest ten sessions per profile', () async {
    final dataSource = _FakeHistoryDataSource();
    final repository = ImageLookupHistoryRepositoryImpl(dataSource);

    for (var day = 1; day <= 11; day++) {
      await repository.save(_session('session-$day', day: day));
    }
    await repository.save(
      _session('other-profile', profileId: 'profile-b', day: 1),
    );

    final profileA = await repository.load('profile-a');
    final profileB = await repository.load('profile-b');

    expect(profileA, hasLength(10));
    expect(profileA.first.id, 'session-11');
    expect(profileA.map((session) => session.id), isNot(contains('session-1')));
    expect(profileB.single.id, 'other-profile');
  });

  test('delete and clear affect only their intended history', () async {
    final dataSource = _FakeHistoryDataSource();
    final repository = ImageLookupHistoryRepositoryImpl(dataSource);
    await repository.save(_session('one'));
    await repository.save(_session('two'));
    await repository.save(_session('other', profileId: 'profile-b'));

    await repository.delete('one');
    expect((await repository.load('profile-a')).single.id, 'two');

    await repository.clear('profile-a');
    expect(await repository.load('profile-a'), isEmpty);
    expect((await repository.load('profile-b')).single.id, 'other');
  });
}
