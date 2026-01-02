import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/tag_repository.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/create_tag_use_case.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class _MockTagRepository extends Mock implements TagRepository {}

void main() {
  late _MockTagRepository tagRepository;
  late CreateTagUseCase useCase;

  setUp(() {
    tagRepository = _MockTagRepository();
    useCase = CreateTagUseCase(tagRepository);
  });

  group('createTag', () {
    test('trims name, generates id, and persists new tag', () async {
      when(tagRepository.getTags()).thenAnswer((_) async => const []);
      when(tagRepository.createTag(any)).thenAnswer((_) async {});

      final tag = await useCase.createTag(
        name: '  New Tag  ',
        color: 0xFF00FF00,
      );

      expect(tag.name, equals('New Tag'));
      expect(tag.id, startsWith('tag_'));
      expect(tag.id.split('_'), hasLength(greaterThanOrEqualTo(3)));

      verify(tagRepository.getTags()).called(1);
      final captured =
          verify(tagRepository.createTag(captureAny)).captured.single as TagEntity;
      expect(captured.id, equals(tag.id));
      expect(captured.name, equals('New Tag'));
      expect(captured.color, equals(0xFF00FF00));
    });

    test('rejects duplicate names regardless of case or whitespace', () async {
      when(tagRepository.getTags()).thenAnswer(
        (_) async => [
          TagEntity(
            id: 'existing',
            name: 'Existing Tag',
            color: 0xFF112233,
            createdAt: DateTime(2024, 1, 1),
          ),
        ],
      );

      expect(
        () => useCase.createTag(name: ' existing tag ', color: 0xFF112233),
        throwsA(isA<TagValidationException>()),
      );

      verify(tagRepository.getTags()).called(1);
      verifyNever(tagRepository.createTag(any));
    });

    test('validates name length and characters', () async {
      when(tagRepository.getTags()).thenAnswer((_) async => const []);

      expect(
        () => useCase.createTag(name: ' ', color: 0xFF123456),
        throwsA(isA<TagValidationException>()),
      );

      expect(
        () => useCase.createTag(name: 'a', color: 0xFF123456),
        throwsA(isA<TagValidationException>()),
      );

      expect(
        () => useCase.createTag(name: '<invalid>', color: 0xFF123456),
        throwsA(isA<TagValidationException>()),
      );

      verifyNever(tagRepository.createTag(any));
    });

    test('validates color boundaries', () async {
      when(tagRepository.getTags()).thenAnswer((_) async => const []);

      expect(
        () => useCase.createTag(name: 'Tag', color: -1),
        throwsA(isA<TagValidationException>()),
      );

      expect(
        () => useCase.createTag(name: 'Tag', color: 0x1FFFFFFFF),
        throwsA(isA<TagValidationException>()),
      );

      verifyNever(tagRepository.createTag(any));
    });
  });
}
