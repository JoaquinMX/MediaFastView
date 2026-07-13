import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/utils/batch_update_result.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/tag_repository.dart';
import 'package:media_fast_view/features/tagging/domain/entities/saved_filter_entity.dart';
import 'package:media_fast_view/features/tagging/domain/tag_validation.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/merge_tags_use_case.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../presentation/tag_view_model_fakes.dart';
import 'merge_tags_use_case_test.mocks.dart';

@GenerateMocks([TagRepository, MediaRepository, DirectoryRepository])
void main() {
  late MockTagRepository tagRepository;
  late MockMediaRepository mediaRepository;
  late MockDirectoryRepository directoryRepository;
  late FakeSavedFilterRepository savedFilters;
  late MergeTagsUseCase useCase;

  SavedFilterEntity savedFilter({
    Set<String> required = const {},
    Set<String> optional = const {},
    Set<String> excluded = const {},
  }) {
    return SavedFilterEntity(
      id: 'filter-1',
      name: 'Trips',
      definition: SavedFilterDefinition(
        requiredTagIds: required,
        optionalTagIds: optional,
        excludedTagIds: excluded,
      ),
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
  }

  final beach = TagEntity(
    id: 'tag-beach',
    name: 'Beach',
    color: 0xFF2196F3,
    createdAt: DateTime(2024),
  );
  final seaside = TagEntity(
    id: 'tag-seaside',
    name: 'Seaside',
    color: 0xFF4CAF50,
    createdAt: DateTime(2024),
  );

  MediaEntity media(String id, List<String> tagIds) {
    return MediaEntity(
      id: id,
      path: '/Photos/$id.jpg',
      name: '$id.jpg',
      type: MediaType.image,
      size: 1,
      lastModified: DateTime(2024),
      tagIds: tagIds,
      directoryId: 'dir',
    );
  }

  DirectoryEntity directory(String id, List<String> tagIds) {
    return DirectoryEntity(
      id: id,
      path: '/Photos/$id',
      name: id,
      thumbnailPath: null,
      tagIds: tagIds,
      lastModified: DateTime(2024),
    );
  }

  /// Whatever the merge asked the media repository to write, per item.
  Map<String, List<String>> capturedMediaPayload() {
    return verify(mediaRepository.updateMediaTagsBatch(captureAny))
        .captured
        .single as Map<String, List<String>>;
  }

  Map<String, List<String>> capturedDirectoryPayload() {
    return verify(directoryRepository.updateDirectoryTagsBatch(captureAny))
        .captured
        .single as Map<String, List<String>>;
  }

  void stubMedia(List<MediaEntity> items) {
    when(mediaRepository.filterMediaByTags(any))
        .thenAnswer((_) async => items);
    when(mediaRepository.updateMediaTagsBatch(any)).thenAnswer(
      (invocation) async => BatchUpdateResult(
        successfulIds: (invocation.positionalArguments.first
                as Map<String, List<String>>)
            .keys
            .toList(),
      ),
    );
  }

  void stubDirectories(List<DirectoryEntity> items) {
    when(directoryRepository.filterDirectoriesByTags(any))
        .thenAnswer((_) async => items);
    when(directoryRepository.updateDirectoryTagsBatch(any)).thenAnswer(
      (invocation) async => BatchUpdateResult(
        successfulIds: (invocation.positionalArguments.first
                as Map<String, List<String>>)
            .keys
            .toList(),
      ),
    );
  }

  setUp(() {
    tagRepository = MockTagRepository();
    mediaRepository = MockMediaRepository();
    directoryRepository = MockDirectoryRepository();
    // A real in-memory implementation, not a mock: the point is to assert the
    // filters actually come out rewritten, not that a method got called.
    savedFilters = FakeSavedFilterRepository();
    useCase = MergeTagsUseCase(
      tagRepository: tagRepository,
      mediaRepository: mediaRepository,
      directoryRepository: directoryRepository,
      savedFilterRepository: savedFilters,
    );

    when(tagRepository.deleteTag(any)).thenAnswer((_) async {});
    stubMedia(const []);
    stubDirectories(const []);
  });

  group('MergeTagsUseCase', () {
    test('moves media from the source tag to the target', () async {
      stubMedia([media('m1', ['tag-beach'])]);

      final result = await useCase(source: beach, target: seaside);

      expect(capturedMediaPayload(), {
        'm1': ['tag-seaside'],
      });
      expect(result.mediaMoved, 1);
    });

    test('keeps every other tag on a moved item', () async {
      // The AssignTagUseCase.setTagsForMedia trap: it applies one tag list to
      // every item, which would wipe 'tag-sunset' here. The merge must build a
      // payload per item.
      stubMedia([
        media('m1', ['tag-sunset', 'tag-beach', 'tag-holiday']),
      ]);

      await useCase(source: beach, target: seaside);

      // Captured once: verify() consumes the recorded call.
      final tagIds = capturedMediaPayload()['m1']!;

      expect(
        tagIds,
        containsAll(<String>['tag-sunset', 'tag-holiday', 'tag-seaside']),
      );
      expect(tagIds, isNot(contains('tag-beach')));
      expect(tagIds, hasLength(3));
    });

    test('an item carrying BOTH tags ends up with the target exactly once',
        () async {
      // The dedupe. Without a set this item would come out tagged 'tag-seaside'
      // twice.
      stubMedia([
        media('m1', ['tag-beach', 'tag-seaside']),
      ]);

      await useCase(source: beach, target: seaside);

      expect(capturedMediaPayload(), {
        'm1': ['tag-seaside'],
      });
    });

    test('moves tagged directories too, not just media', () async {
      stubDirectories([
        directory('d1', ['tag-beach', 'tag-trips']),
      ]);

      final result = await useCase(source: beach, target: seaside);

      final tagIds = capturedDirectoryPayload()['d1']!;

      expect(tagIds, containsAll(<String>['tag-trips', 'tag-seaside']));
      expect(tagIds, isNot(contains('tag-beach')));
      expect(result.directoriesMoved, 1);
    });

    test('deletes the source tag once everything has moved', () async {
      stubMedia([media('m1', ['tag-beach'])]);

      await useCase(source: beach, target: seaside);

      verify(tagRepository.deleteTag('tag-beach')).called(1);
      verifyNever(tagRepository.deleteTag('tag-seaside'));
    });

    test('deletes the source only AFTER the items are rewritten', () async {
      stubMedia([media('m1', ['tag-beach'])]);

      await useCase(source: beach, target: seaside);

      // Order matters: deleting first would strand assignments pointing at a tag
      // that no longer exists.
      verifyInOrder([
        mediaRepository.updateMediaTagsBatch(any),
        tagRepository.deleteTag('tag-beach'),
      ]);
    });

    test('keeps the source tag alive when an item could not be updated',
        () async {
      when(mediaRepository.filterMediaByTags(any))
          .thenAnswer((_) async => [media('m1', ['tag-beach'])]);
      when(mediaRepository.updateMediaTagsBatch(any)).thenAnswer(
        (_) async => const BatchUpdateResult(
          failureReasons: {'m1': 'disk on fire'},
        ),
      );

      final result = await useCase(source: beach, target: seaside);

      expect(result.hasFailures, isTrue);
      // Left alive on purpose: the merge can simply be run again.
      verifyNever(tagRepository.deleteTag(any));
    });

    // Saved filters are the THIRD holder of tag ids, after media and directories.
    // If a merge does not rewrite them, a filter that *required* the source keeps
    // an id that resolves to nothing — which the Tags tab silently drops on
    // apply. The filter then quietly stops requiring anything and broadens its
    // results, with no error anywhere. These are the guard for that.
    group('saved filters follow the merge', () {
      test('a required tag is repointed at the survivor', () async {
        await savedFilters.saveFilter(
          savedFilter(required: {'tag-beach', 'tag-sunset'}),
        );

        await useCase(source: beach, target: seaside);

        final definition = savedFilters.filters.single.definition;
        expect(definition.requiredTagIds, {'tag-seaside', 'tag-sunset'});
        expect(definition.requiredTagIds, isNot(contains('tag-beach')));
      });

      test('optional and excluded lists are repointed too', () async {
        await savedFilters.saveFilter(
          savedFilter(
            optional: {'tag-beach'},
            excluded: {'tag-beach'},
          ),
        );

        await useCase(source: beach, target: seaside);

        final definition = savedFilters.filters.single.definition;
        expect(definition.optionalTagIds, {'tag-seaside'});
        expect(definition.excludedTagIds, {'tag-seaside'});
      });

      test('a filter already naming the target keeps it exactly once', () async {
        await savedFilters.saveFilter(
          savedFilter(required: {'tag-beach', 'tag-seaside'}),
        );

        await useCase(source: beach, target: seaside);

        expect(
          savedFilters.filters.single.definition.requiredTagIds,
          {'tag-seaside'},
        );
      });

      test('the source id survives nowhere', () async {
        await savedFilters.saveFilter(
          savedFilter(
            required: {'tag-beach'},
            optional: {'tag-beach'},
            excluded: {'tag-beach'},
          ),
        );

        await useCase(source: beach, target: seaside);

        expect(
          savedFilters.filters.single.definition.allTagIds,
          isNot(contains('tag-beach')),
        );
      });

      test('a filter that never mentioned the source is untouched', () async {
        await savedFilters.saveFilter(savedFilter(required: {'tag-family'}));

        await useCase(source: beach, target: seaside);

        expect(
          savedFilters.filters.single.definition.requiredTagIds,
          {'tag-family'},
        );
      });

      test('filters are left alone when the merge fails', () async {
        await savedFilters.saveFilter(savedFilter(required: {'tag-beach'}));
        when(mediaRepository.filterMediaByTags(any))
            .thenAnswer((_) async => [media('m1', ['tag-beach'])]);
        when(mediaRepository.updateMediaTagsBatch(any)).thenAnswer(
          (_) async => const BatchUpdateResult(
            failureReasons: {'m1': 'disk on fire'},
          ),
        );

        await useCase(source: beach, target: seaside);

        // The source tag is still alive, so the filter must still point at it —
        // the merge can simply be run again.
        expect(
          savedFilters.filters.single.definition.requiredTagIds,
          {'tag-beach'},
        );
      });
    });

    test('merging a tag into itself is rejected', () async {
      expect(
        () => useCase(source: beach, target: beach),
        throwsA(isA<TagValidationException>()),
      );

      verifyNever(mediaRepository.updateMediaTagsBatch(any));
      verifyNever(tagRepository.deleteTag(any));
    });

    test('an unused source tag is still deleted, touching nothing', () async {
      final result = await useCase(source: beach, target: seaside);

      expect(result.itemsMoved, 0);
      verifyNever(mediaRepository.updateMediaTagsBatch(any));
      verifyNever(directoryRepository.updateDirectoryTagsBatch(any));
      verify(tagRepository.deleteTag('tag-beach')).called(1);
    });
  });
}
