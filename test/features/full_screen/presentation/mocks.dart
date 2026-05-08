// ignore_for_file: unused_import

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/favorites/presentation/view_models/favorites_view_model.dart';
import 'package:media_fast_view/features/full_screen/domain/use_cases/load_media_for_viewing_use_case.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/assign_tag_use_case.dart';
import 'package:media_fast_view/shared/utils/tag_cache_refresher.dart';
import 'package:media_fast_view/shared/utils/tag_lookup.dart';

// Re-export the generated mocks so test files importing this module get
// MockX symbols transitively without each one needing to know the .mocks.dart path.
export 'mocks.mocks.dart';

@GenerateMocks([
  LoadMediaForViewingUseCase,
  FavoritesViewModel,
  FavoritesRepository,
  AssignTagUseCase,
  TagLookup,
  TagCacheRefresher,
])
// Annotation must attach to a declaration; this no-op gives Mockito codegen
// something to anchor on.
void _generatedMocksAnchor() {}
