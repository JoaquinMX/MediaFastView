import 'package:media_fast_view/core/services/bookmark_service.dart';
import 'package:media_fast_view/core/services/file_service.dart';
import 'package:media_fast_view/core/services/permission_service.dart';
import 'package:media_fast_view/core/services/platform_service.dart';
import 'package:media_fast_view/features/favorites/data/isar/isar_favorites_data_source.dart';
import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/media_library/data/data_sources/filesystem_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/tagging/data/isar/isar_tag_data_source.dart';
import 'package:media_fast_view/features/tagging/domain/repositories/tag_repository.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockMediaRepository extends Mock implements MediaRepository {}

class MockDirectoryRepository extends Mock implements DirectoryRepository {}

class MockTagRepository extends Mock implements TagRepository {}

class MockFavoritesRepository extends Mock implements FavoritesRepository {}

class MockFilesystemMediaDataSource extends Mock
    implements FilesystemMediaDataSource {}

class MockIsarMediaDataSource extends Mock implements IsarMediaDataSource {}

class MockIsarDirectoryDataSource extends Mock
    implements IsarDirectoryDataSource {}

class MockIsarTagDataSource extends Mock implements IsarTagDataSource {}

class MockIsarFavoritesDataSource extends Mock
    implements IsarFavoritesDataSource {}

class MockFileService extends Mock implements FileService {}

class MockPermissionService extends Mock implements PermissionService {}

class MockPlatformService extends Mock implements PlatformService {}

class MockBookmarkService extends Mock implements BookmarkService {}

class MockSharedPreferences extends Mock implements SharedPreferences {}
