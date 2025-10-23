import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/favorites/presentation/view_models/favorites_view_model.dart';
import 'package:media_fast_view/features/full_screen/domain/use_cases/load_media_for_viewing_use_case.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/assign_tag_use_case.dart';
import 'package:media_fast_view/shared/utils/tag_cache_refresher.dart';
import 'package:media_fast_view/shared/utils/tag_lookup.dart';

class MockLoadMediaForViewingUseCase extends Mock
    implements LoadMediaForViewingUseCase {}

class MockFavoritesViewModel extends Mock implements FavoritesViewModel {}

class MockFavoritesRepository extends Mock implements FavoritesRepository {}

class MockAssignTagUseCase extends Mock implements AssignTagUseCase {}

class MockTagLookup extends Mock implements TagLookup {}

class MockTagCacheRefresher extends Mock implements TagCacheRefresher {}
