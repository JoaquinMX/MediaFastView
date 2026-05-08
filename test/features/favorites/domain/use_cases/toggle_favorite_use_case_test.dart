import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/favorites/domain/use_cases/toggle_favorite_use_case.dart';

import 'toggle_favorite_use_case_test.mocks.dart';

@GenerateMocks([FavoritesRepository])

void main() {
  late MockFavoritesRepository repository;
  late ToggleFavoriteUseCase useCase;

  const mediaId = 'media-123';

  setUp(() {
    repository = MockFavoritesRepository();
    useCase = ToggleFavoriteUseCase(repository);
  });

  group('ToggleFavoriteUseCase', () {
    test('adds media to favorites when currently not favorited', () async {
      when(repository.isFavorite(mediaId)).thenAnswer((_) async => false);
      when(repository.addFavorite(mediaId)).thenAnswer((_) async {});

      await useCase.execute(mediaId);

      verify(repository.isFavorite(mediaId)).called(1);
      verify(repository.addFavorite(mediaId)).called(1);
      verifyNever(repository.removeFavorite(any));
    });

    test('removes media from favorites when already favorited', () async {
      when(repository.isFavorite(mediaId)).thenAnswer((_) async => true);
      when(repository.removeFavorite(mediaId)).thenAnswer((_) async {});

      await useCase.execute(mediaId);

      verify(repository.isFavorite(mediaId)).called(1);
      verify(repository.removeFavorite(mediaId)).called(1);
      verifyNever(repository.addFavorite(any));
    });
  });
}
