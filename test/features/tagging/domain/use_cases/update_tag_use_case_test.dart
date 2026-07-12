import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/tag_repository.dart';
import 'package:media_fast_view/features/tagging/domain/tag_validation.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/update_tag_use_case.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'update_tag_use_case_test.mocks.dart';

@GenerateMocks([TagRepository])
void main() {
  late MockTagRepository tagRepository;
  late UpdateTagUseCase useCase;

  final beach = TagEntity(
    id: 'tag-beach',
    name: 'Beach',
    color: 0xFF2196F3,
    createdAt: DateTime(2024, 1, 1),
  );
  final family = TagEntity(
    id: 'tag-family',
    name: 'Family',
    color: 0xFF4CAF50,
    createdAt: DateTime(2024, 2, 2),
  );

  setUp(() {
    tagRepository = MockTagRepository();
    useCase = UpdateTagUseCase(tagRepository);

    when(tagRepository.getTags()).thenAnswer((_) async => [beach, family]);
    when(tagRepository.updateTag(any)).thenAnswer((_) async {});
  });

  TagEntity captureUpdated() {
    return verify(tagRepository.updateTag(captureAny)).captured.single
        as TagEntity;
  }

  group('UpdateTagUseCase', () {
    test('renames a tag and persists it', () async {
      final updated = await useCase(
        tag: beach,
        name: 'Seaside',
        color: beach.color,
      );

      expect(updated.name, 'Seaside');
      expect(captureUpdated().name, 'Seaside');
    });

    test('trims the new name', () async {
      await useCase(tag: beach, name: '  Seaside  ', color: beach.color);

      expect(captureUpdated().name, 'Seaside');
    });

    test('changes the colour', () async {
      final updated = await useCase(
        tag: beach,
        name: beach.name,
        color: 0xFFE91E63,
      );

      expect(updated.color, 0xFFE91E63);
      expect(captureUpdated().color, 0xFFE91E63);
    });

    test('keeps the id and createdAt, so assignments survive', () async {
      // Media reference tags by id. If an edit minted a new id, every media item
      // would silently lose the tag.
      final updated = await useCase(
        tag: beach,
        name: 'Seaside',
        color: 0xFFE91E63,
      );

      expect(updated.id, beach.id);
      expect(updated.createdAt, beach.createdAt);

      final captured = captureUpdated();
      expect(captured.id, beach.id);
      expect(captured.createdAt, beach.createdAt);
    });

    group('the tag does not collide with itself', () {
      test('a colour-only change keeps the same name and succeeds', () async {
        // The whole reason the duplicate check excludes the edited tag. Without
        // it, "Beach" collides with its own row and this throws.
        final updated = await useCase(
          tag: beach,
          name: 'Beach',
          color: 0xFFE91E63,
        );

        expect(updated.name, 'Beach');
        expect(updated.color, 0xFFE91E63);
        expect(captureUpdated().color, 0xFFE91E63);
      });

      test('a case-only rename succeeds', () async {
        final updated = await useCase(
          tag: beach,
          name: 'BEACH',
          color: beach.color,
        );

        expect(updated.name, 'BEACH');
        expect(captureUpdated().name, 'BEACH');
      });
    });

    group('rejects a name taken by another tag', () {
      test('exactly', () {
        expect(
          () => useCase(tag: beach, name: 'Family', color: beach.color),
          throwsA(isA<TagValidationException>()),
        );
      });

      test('ignoring case', () {
        expect(
          () => useCase(tag: beach, name: 'fAmIlY', color: beach.color),
          throwsA(isA<TagValidationException>()),
        );
      });

      test('and does not persist anything', () async {
        await expectLater(
          () => useCase(tag: beach, name: 'Family', color: beach.color),
          throwsA(isA<TagValidationException>()),
        );

        verifyNever(tagRepository.updateTag(any));
      });
    });

    group('applies the shared name rules', () {
      test('rejects an empty name', () {
        expect(
          () => useCase(tag: beach, name: '   ', color: beach.color),
          throwsA(isA<TagValidationException>()),
        );
      });

      test('rejects a name that is too short', () {
        expect(
          () => useCase(tag: beach, name: 'a', color: beach.color),
          throwsA(isA<TagValidationException>()),
        );
      });

      test('rejects a name that is too long', () {
        expect(
          () => useCase(tag: beach, name: 'a' * 51, color: beach.color),
          throwsA(isA<TagValidationException>()),
        );
      });

      test('rejects invalid characters', () {
        expect(
          () => useCase(tag: beach, name: 'bad/name', color: beach.color),
          throwsA(isA<TagValidationException>()),
        );
      });

      test('rejects an out-of-range colour', () {
        expect(
          () => useCase(tag: beach, name: 'Seaside', color: -1),
          throwsA(isA<TagValidationException>()),
        );
      });
    });
  });
}
