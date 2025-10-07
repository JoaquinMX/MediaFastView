import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Repositories
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/tagging/domain/repositories/tag_repository.dart';
import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';

// Data Sources
import 'package:media_fast_view/features/media_library/data/data_sources/filesystem_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/data_sources/local_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/data_sources/shared_preferences_data_source.dart';
import 'package:media_fast_view/features/tagging/data/data_sources/shared_preferences_data_source.dart';
import 'package:media_fast_view/features/favorites/data/data_sources/shared_preferences_data_source.dart';

// Services
import 'package:media_fast_view/core/services/file_service.dart';
import 'package:media_fast_view/core/services/permission_service.dart';
import 'package:media_fast_view/core/services/platform_service.dart';
import 'package:media_fast_view/core/services/bookmark_service.dart';

@GenerateMocks([
  // Repositories
  MediaRepository,
  TagRepository,
  FavoritesRepository,

  // Data Sources
  FilesystemMediaDataSource,
  SharedPreferencesMediaDataSource,
  SharedPreferencesDirectoryDataSource,
  SharedPreferencesTagDataSource,
  SharedPreferencesFavoritesDataSource,

  // Services
  FileService,
  PermissionService,
  PlatformService,
  BookmarkService,

  // External dependencies
  SharedPreferences,
])
void main() {}
