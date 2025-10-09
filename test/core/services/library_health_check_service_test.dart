import 'dart:async';

import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'package:media_fast_view/core/services/library_health_check_service.dart';
import 'package:media_fast_view/core/services/permission_service.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/data/data_sources/local_directory_data_source.dart';
import 'package:media_fast_view/shared/utils/directory_id_utils.dart';

import '../../mocks.mocks.dart';

class FakeDirectoryRepository implements DirectoryRepository {
  FakeDirectoryRepository(this._directories);

  final List<DirectoryEntity> _directories;

  @override
  Future<void> addDirectory(DirectoryEntity directory, {bool silent = false}) async {
    _directories.add(directory);
  }

  @override
  Future<void> clearAllDirectories() async {
    _directories.clear();
  }

  @override
  Future<List<DirectoryEntity>> filterDirectoriesByTags(List<String> tagIds) async {
    return _directories;
  }

  @override
  Future<List<DirectoryEntity>> getDirectories() async {
    return List<DirectoryEntity>.from(_directories);
  }

  @override
  Future<DirectoryEntity?> getDirectoryById(String id) async {
    return _directories.firstWhere((dir) => dir.id == id);
  }

  @override
  Future<void> removeDirectory(String id) async {
    _directories.removeWhere((dir) => dir.id == id);
  }

  @override
  Future<List<DirectoryEntity>> searchDirectories(String query) async {
    return _directories;
  }

  @override
  Future<void> updateDirectoryBookmark(String directoryId, String? bookmarkData) async {
    final index = _directories.indexWhere((dir) => dir.id == directoryId);
    if (index == -1) {
      return;
    }
    _directories[index] = _directories[index].copyWith(bookmarkData: bookmarkData);
  }

  @override
  Future<void> updateDirectoryTags(String directoryId, List<String> tagIds) async {}

  @override
  Future<DirectoryEntity?> updateDirectoryPathAndId(String directoryId, String newPath) async {
    final index = _directories.indexWhere((dir) => dir.id == directoryId);
    if (index == -1) {
      return null;
    }

    final updated = _directories[index].copyWith(
      id: generateDirectoryId(newPath),
      path: newPath,
      name: newPath.split('/').last,
    );
    _directories[index] = updated;
    return updated;
  }
}

class _TestLocalDirectoryDataSource extends LocalDirectoryDataSource {
  _TestLocalDirectoryDataSource(this._access, this._bookmarkStates)
      : super(bookmarkService: MockBookmarkService());

  final Map<String, bool> _access;
  final Map<String, bool> _bookmarkStates;

  @override
  Future<bool> validateDirectory(DirectoryEntity directory) async {
    if (directory.bookmarkData != null) {
      _bookmarkStates[directory.bookmarkData!] = true;
    }
    return _access[directory.id] ?? true;
  }
}

void main() {
  group('LibraryHealthCheckScheduler', () {
    late FakeDirectoryRepository repository;
    late MockPermissionService permissionService;
    late _TestLocalDirectoryDataSource localDirectoryDataSource;
    late LibraryHealthCheckScheduler scheduler;
    late Map<String, bool> bookmarkStates;

    setUp(() {
      bookmarkStates = <String, bool>{};
      repository = FakeDirectoryRepository([
        DirectoryEntity(
          id: generateDirectoryId('/media/photos'),
          path: '/media/photos',
          name: 'photos',
          thumbnailPath: null,
          tagIds: const [],
          lastModified: DateTime(2024, 1, 1),
          bookmarkData: null,
        ),
      ]);
      permissionService = MockPermissionService();
      localDirectoryDataSource = _TestLocalDirectoryDataSource(<String, bool>{}, bookmarkStates);
      scheduler = LibraryHealthCheckScheduler(
        directoryRepository: repository,
        localDirectoryDataSource: localDirectoryDataSource,
        permissionService: permissionService,
        interval: const Duration(days: 1),
      );
    });

    tearDown(() {
      scheduler.dispose();
    });

    test('emits in-progress and completed reports with accessible directories', () async {
      when(permissionService.validateAndRenewBookmark(any, any)).thenAnswer(
        (_) async => const BookmarkValidationResult(isValid: true),
      );
      when(permissionService.checkDirectoryAccess(any)).thenAnswer(
        (_) async => PermissionStatus.granted,
      );

      final reports = <LibraryHealthCheckReport>[];
      final subscription = scheduler.reports.listen(reports.add);

      await scheduler.runHealthCheckNow();

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await subscription.cancel();

      expect(reports.length, 2);
      expect(reports.first.inProgress, isTrue);
      expect(reports.last.inProgress, isFalse);
      expect(reports.last.accessibleDirectories, hasLength(1));
      expect(reports.last.summary.accessibleCount, 1);
      expect(reports.last.summary.permissionIssueCount, 0);
      expect(reports.last.summary.bookmarkIssueCount, 0);
      expect(reports.last.summary.idMismatchCount, 0);
    });

    test('auto-renews bookmarks and reconciles metadata', () async {
      final originalId = generateDirectoryId('/media/old');
      final directory = DirectoryEntity(
        id: originalId,
        path: '/media/old',
        name: 'old',
        thumbnailPath: null,
        tagIds: const [],
        lastModified: DateTime(2024, 1, 2),
        bookmarkData: 'bookmark-old',
      );
      repository = FakeDirectoryRepository([directory]);
      scheduler = LibraryHealthCheckScheduler(
        directoryRepository: repository,
        localDirectoryDataSource: _TestLocalDirectoryDataSource(<String, bool>{}, bookmarkStates),
        permissionService: permissionService,
        interval: const Duration(days: 1),
      );

      when(permissionService.validateAndRenewBookmark('bookmark-old', '/media/old')).thenAnswer(
        (_) async => const BookmarkValidationResult(
          isValid: true,
          renewedBookmarkData: 'bookmark-new',
          resolvedPath: '/media/new',
        ),
      );
      when(permissionService.checkDirectoryAccess(any)).thenAnswer(
        (_) async => PermissionStatus.granted,
      );

      final reports = <LibraryHealthCheckReport>[];
      final subscription = scheduler.reports.listen(reports.add);

      await scheduler.runHealthCheckNow();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await subscription.cancel();

      expect(reports.last.summary.repairedCount, 1);
      expect(reports.last.summary.idMismatchCount, 1);
      expect(repository.getDirectories(), completion(isNotEmpty));
      final updated = repository._directories.first;
      expect(updated.path, '/media/new');
      expect(updated.bookmarkData, 'bookmark-new');
      expect(updated.id, generateDirectoryId('/media/new'));
    });
  });
}
