import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/bookmark_service.dart';
import 'package:media_fast_view/core/services/directory_access_grant.dart';
import 'package:media_fast_view/core/services/directory_picker_service.dart';
import 'package:media_fast_view/core/services/permission_service.dart';
import 'package:media_fast_view/core/services/platform_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'permission_service_test.mocks.dart';

final class FakeApplePlatformService extends PlatformService {
  FakeApplePlatformService({required this.ios});

  final bool ios;

  @override
  bool get isIOS => ios;

  @override
  bool get isMacOS => !ios;
}

final class FakeDirectoryPicker implements DirectoryPicker {
  FakeDirectoryPicker(this.selection);

  final DirectoryAccessGrant? selection;

  @override
  Future<List<DirectoryAccessGrant>> pickDirectories({
    String? initialDirectoryPath,
    String? dialogTitle,
  }) async {
    return selection == null
        ? const <DirectoryAccessGrant>[]
        : <DirectoryAccessGrant>[selection!];
  }

  @override
  Future<DirectoryAccessGrant?> pickSingleDirectory({
    String? initialDirectoryPath,
    String? dialogTitle,
  }) async {
    return selection;
  }
}

@GenerateMocks(<Type>[BookmarkService])
void main() {
  late MockBookmarkService bookmarkService;

  setUp(() {
    bookmarkService = MockBookmarkService();
  });

  test('checks an empty directory inside balanced bookmark access', () async {
    final directory = await Directory.systemTemp.createTemp(
      'permission_service_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    when(
      bookmarkService.startAccessingBookmark('bookmark'),
    ).thenAnswer((_) async => directory.path);
    when(
      bookmarkService.stopAccessingBookmark('bookmark'),
    ).thenAnswer((_) async {});
    final service = PermissionService(
      bookmarkService,
      FakeDirectoryPicker(null),
      FakeApplePlatformService(ios: true),
    );

    final status = await service.checkDirectoryAccess(
      '/stale/stored/path',
      bookmarkData: 'bookmark',
    );

    expect(status, PermissionStatus.granted);
    verify(bookmarkService.startAccessingBookmark('bookmark')).called(1);
    verify(bookmarkService.stopAccessingBookmark('bookmark')).called(1);
  });

  test('treats an empty bookmark as no bookmark', () async {
    final directory = await Directory.systemTemp.createTemp(
      'permission_empty_bookmark_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final service = PermissionService(
      bookmarkService,
      FakeDirectoryPicker(null),
      FakeApplePlatformService(ios: true),
    );

    final status = await service.checkDirectoryAccess(
      directory.path,
      bookmarkData: '',
    );

    expect(status, PermissionStatus.granted);
    verifyNever(bookmarkService.startAccessingBookmark(any));
  });

  test('checks a requested child instead of its bookmark scope root', () async {
    final root = await Directory.systemTemp.createTemp(
      'permission_parent_scope_test_',
    );
    addTearDown(() => root.delete(recursive: true));
    when(
      bookmarkService.startAccessingBookmark('parent-bookmark'),
    ).thenAnswer((_) async => root.path);
    when(
      bookmarkService.stopAccessingBookmark('parent-bookmark'),
    ).thenAnswer((_) async {});
    final service = PermissionService(
      bookmarkService,
      FakeDirectoryPicker(null),
      FakeApplePlatformService(ios: true),
    );

    final status = await service.checkDirectoryAccess(
      '${root.path}/missing-child',
      bookmarkData: 'parent-bookmark',
    );

    expect(status, PermissionStatus.notFound);
    verify(bookmarkService.stopAccessingBookmark('parent-bookmark')).called(1);
  });

  test('iOS recovery returns the picker bookmark grant', () async {
    final directory = await Directory.systemTemp.createTemp(
      'permission_recovery_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final picker = FakeDirectoryPicker(
      DirectoryAccessGrant(path: directory.path, bookmarkData: 'fresh'),
    );
    when(
      bookmarkService.startAccessingBookmark('fresh'),
    ).thenAnswer((_) async => directory.path);
    when(
      bookmarkService.stopAccessingBookmark('fresh'),
    ).thenAnswer((_) async {});
    final service = PermissionService(
      bookmarkService,
      picker,
      FakeApplePlatformService(ios: true),
    );

    final result = await service.recoverDirectoryAccess('/legacy/path');

    expect(result?.directoryPath, directory.path);
    expect(result?.bookmarkData, 'fresh');
    verify(bookmarkService.stopAccessingBookmark('fresh')).called(1);
  });
}
