import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/create_tag_use_case.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/update_tag_use_case.dart';
import 'package:media_fast_view/features/tagging/presentation/states/tag_state.dart';
import 'package:media_fast_view/features/tagging/presentation/view_models/tag_management_view_model.dart';

import '../tag_view_model_fakes.dart';

TagEntity _tag(String id, String name) => TagEntity(
      id: id,
      name: name,
      color: 0xFF2196F3,
      createdAt: DateTime(2024),
    );

void main() {
  late FakeTagRepository repository;
  late TagViewModel viewModel;

  TagViewModel build([List<TagEntity> tags = const []]) {
    repository = FakeTagRepository(tags);
    return TagViewModel(
      repository,
      CreateTagUseCase(repository),
      UpdateTagUseCase(repository),
    );
  }

  /// Waits for the loadTags() the constructor kicks off.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('TagViewModel.createTag', () {
    test('persists a validated tag and patches the state', () async {
      viewModel = build();
      await settle();

      final tag = await viewModel.createTag('  Beach  ', 0xFF4CAF50);

      expect(tag.name, 'Beach', reason: 'the domain trims the name');
      expect(tag.color, 0xFF4CAF50);
      expect(repository.tags.single.name, 'Beach');

      final state = viewModel.state as TagLoaded;
      expect(state.tags.single.id, tag.id);
    });

    // The point of the change. Creation used to build the entity in the view
    // model and skip every rule, so these were caught only by the create
    // dialog's form validator — and by nothing at all for any other caller.
    group('now enforces the domain rules', () {
      test('rejects a duplicate name, case-insensitively', () async {
        viewModel = build([_tag('tag-beach', 'Beach')]);
        await settle();

        await expectLater(
          () => viewModel.createTag('bEaCh', 0xFF2196F3),
          throwsA(isA<TagValidationException>()),
        );

        expect(repository.tags, hasLength(1), reason: 'nothing was persisted');
      });

      test('rejects a name that is too short', () async {
        viewModel = build();
        await settle();

        await expectLater(
          () => viewModel.createTag('a', 0xFF2196F3),
          throwsA(isA<TagValidationException>()),
        );
        expect(repository.tags, isEmpty);
      });

      test('rejects invalid characters', () async {
        viewModel = build();
        await settle();

        await expectLater(
          () => viewModel.createTag('bad/name', 0xFF2196F3),
          throwsA(isA<TagValidationException>()),
        );
        expect(repository.tags, isEmpty);
      });

      test('rejects an out-of-range colour', () async {
        viewModel = build();
        await settle();

        await expectLater(
          () => viewModel.createTag('Beach', -1),
          throwsA(isA<TagValidationException>()),
        );
        expect(repository.tags, isEmpty);
      });
    });

    test('does not error the view model when validation fails', () async {
      // The tag list behind the dialog must survive a rejected name — the
      // exception is for the dialog to show inline.
      viewModel = build([_tag('tag-beach', 'Beach')]);
      await settle();

      await expectLater(
        () => viewModel.createTag('Beach', 0xFF2196F3),
        throwsA(isA<TagValidationException>()),
      );

      expect(viewModel.state, isA<TagLoaded>());
      expect((viewModel.state as TagLoaded).tags, hasLength(1));
    });

    test('mints a uuid, matching the tags already in the database', () async {
      viewModel = build();
      await settle();

      final tag = await viewModel.createTag('Beach', 0xFF2196F3);

      expect(tag.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
    });
  });

  group('TagViewModel.tagNameExists', () {
    test('ignores the tag being edited, so a colour-only save is allowed',
        () async {
      viewModel = build([_tag('tag-beach', 'Beach')]);
      await settle();

      expect(viewModel.tagNameExists('Beach'), isTrue);
      expect(
        viewModel.tagNameExists('Beach', excludingId: 'tag-beach'),
        isFalse,
      );
    });
  });
}
