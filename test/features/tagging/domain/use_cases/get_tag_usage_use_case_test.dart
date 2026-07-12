import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/tag_repository.dart';
import 'package:media_fast_view/features/tagging/domain/entities/tag_usage.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/get_tag_usage_use_case.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'get_tag_usage_use_case_test.mocks.dart';

@GenerateMocks([TagRepository, MediaRepository, DirectoryRepository])
void main() {
  late MockTagRepository tagRepository;
  late MockMediaRepository mediaRepository;
  late MockDirectoryRepository directoryRepository;
  late GetTagUsageUseCase useCase;

  TagEntity tag(String id) => TagEntity(
        id: id,
        name: id,
        color: 0xFF2196F3,
        createdAt: DateTime(2024),
      );

  MediaEntity media(String id, List<String> tagIds) => MediaEntity(
        id: id,
        path: '/Photos/$id.jpg',
        name: '$id.jpg',
        type: MediaType.image,
        size: 1,
        lastModified: DateTime(2024),
        tagIds: tagIds,
        directoryId: 'dir',
      );

  DirectoryEntity directory(String id, List<String> tagIds) => DirectoryEntity(
        id: id,
        path: '/Photos/$id',
        name: id,
        thumbnailPath: null,
        tagIds: tagIds,
        lastModified: DateTime(2024),
      );

  void seed({
    List<TagEntity> tags = const [],
    List<MediaEntity> mediaItems = const [],
    List<DirectoryEntity> directories = const [],
  }) {
    when(tagRepository.getTags()).thenAnswer((_) async => tags);
    when(mediaRepository.getAllMedia()).thenAnswer((_) async => mediaItems);
    when(directoryRepository.getDirectories())
        .thenAnswer((_) async => directories);
  }

  setUp(() {
    tagRepository = MockTagRepository();
    mediaRepository = MockMediaRepository();
    directoryRepository = MockDirectoryRepository();
    useCase = GetTagUsageUseCase(
      tagRepository: tagRepository,
      mediaRepository: mediaRepository,
      directoryRepository: directoryRepository,
    );
  });

  group('GetTagUsageUseCase', () {
    test('counts files and folders separately', () async {
      // A single total would under-report, and the delete dialog would then
      // understate what it is about to detach.
      seed(
        tags: [tag('beach')],
        mediaItems: [
          media('m1', ['beach']),
          media('m2', ['beach']),
        ],
        directories: [directory('d1', ['beach'])],
      );

      final usage = await useCase();

      expect(usage['beach'], const TagUsage(mediaCount: 2, directoryCount: 1));
      expect(usage['beach']!.total, 3);
      expect(usage['beach']!.describe(), '2 files · 1 folder');
    });

    test('reports an unused tag as zero rather than omitting it', () async {
      seed(tags: [tag('beach'), tag('unused')], mediaItems: [
        media('m1', ['beach']),
      ]);

      final usage = await useCase();

      expect(usage.containsKey('unused'), isTrue);
      expect(usage['unused'], TagUsage.none);
      expect(usage['unused']!.isUnused, isTrue);
    });

    test('counts every tag in one pass', () async {
      seed(
        tags: [tag('a'), tag('b'), tag('c')],
        mediaItems: [
          media('m1', ['a', 'b']),
          media('m2', ['b']),
        ],
        directories: [directory('d1', ['c'])],
      );

      final usage = await useCase();

      expect(usage['a']!.mediaCount, 1);
      expect(usage['b']!.mediaCount, 2);
      expect(usage['c']!.directoryCount, 1);

      // One read of each repository, not one per tag.
      verify(mediaRepository.getAllMedia()).called(1);
      verify(directoryRepository.getDirectories()).called(1);
    });

    test('ignores tag ids left behind by a tag that no longer exists', () async {
      // Media can outlive a deleted tag's id. Counting it would invent a row the
      // UI cannot act on.
      seed(
        tags: [tag('beach')],
        mediaItems: [
          media('m1', ['beach', 'tag-that-was-deleted']),
        ],
      );

      final usage = await useCase();

      expect(usage.keys, ['beach']);
      expect(usage['beach']!.mediaCount, 1);
    });

    test('is empty when there are no tags', () async {
      seed(mediaItems: [media('m1', ['orphan'])]);

      expect(await useCase(), isEmpty);
    });
  });

  group('TagUsage.describe', () {
    test('drops whichever half is zero', () {
      expect(const TagUsage(mediaCount: 5).describe(), '5 files');
      expect(const TagUsage(directoryCount: 2).describe(), '2 folders');
      expect(TagUsage.none.describe(), isEmpty);
    });

    test('singularises', () {
      expect(
        const TagUsage(mediaCount: 1, directoryCount: 1).describe(),
        '1 file · 1 folder',
      );
    });
  });
}
