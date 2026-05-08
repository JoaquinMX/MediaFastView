import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/favorites/domain/use_cases/get_favorites_use_case.dart';

import 'get_favorites_use_case_test.mocks.dart';

@GenerateMocks([FavoritesRepository])

void main() {
  late MockFavoritesRepository repository;
  late GetFavoritesUseCase useCase;

  setUp(() {
    repository = MockFavoritesRepository();
    useCase = GetFavoritesUseCase(repository);
  });

  group('GetFavoritesUseCase', () {
    test('returns ids from repository', () async {
      when(repository.getFavoriteMediaIds())
          .thenAnswer((_) async => ['one', 'two']);

      final result = await useCase.execute();

      expect(result, equals(['one', 'two']));
      verify(repository.getFavoriteMediaIds()).called(1);
    });
  });
}
