import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/favorites/domain/use_cases/get_favorites_use_case.dart';

class _MockFavoritesRepository extends Mock implements FavoritesRepository {}

void main() {
  late _MockFavoritesRepository repository;
  late GetFavoritesUseCase useCase;

  setUp(() {
    repository = _MockFavoritesRepository();
    useCase = GetFavoritesUseCase(repository);
  });

  test('returns ids from repository', () async {
    when(repository.getFavoriteMediaIds())
        .thenAnswer((_) async => ['one', 'two']);

    final result = await useCase.execute();

    expect(result, ['one', 'two']);
    verify(repository.getFavoriteMediaIds()).called(1);
  });
}
