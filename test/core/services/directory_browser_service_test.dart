import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/directory_access_grant.dart';
import 'package:media_fast_view/core/services/directory_browser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bookmarkChannel = MethodChannel(
    'com.joaquinmx.media_fast_view/bookmarks',
  );

  test('lists visible child directories in name order', () async {
    final root = await Directory.systemTemp.createTemp(
      'directory_browser_service_test_',
    );
    addTearDown(() => root.delete(recursive: true));
    await Directory('${root.path}/beta').create();
    await Directory('${root.path}/Alpha').create();
    await Directory('${root.path}/.hidden').create();
    await File('${root.path}/not_a_directory.txt').writeAsString('test');
    final service = DirectoryBrowserService(supportsBookmarks: false);

    final children = await service.listChildren(
      DirectoryAccessGrant(path: root.path),
      root.path,
    );

    expect(children.map((child) => child.name), <String>['Alpha', 'beta']);
  });

  test('rejects browsing outside the granted parent', () async {
    final service = DirectoryBrowserService(supportsBookmarks: false);

    expect(
      () => service.listChildren(
        const DirectoryAccessGrant(path: '/granted'),
        '/outside',
      ),
      throwsArgumentError,
    );
  });

  test(
    'creates independent child bookmarks inside balanced parent access',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'directory_browser_bookmark_test_',
      );
      addTearDown(() => root.delete(recursive: true));
      final child = await Directory('${root.path}/child').create();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bookmarkChannel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'startAccessingBookmark' => root.path,
              'createBookmark' => 'child-bookmark',
              'stopAccessingBookmark' => null,
              _ => throw MissingPluginException(call.method),
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(bookmarkChannel, null),
      );
      final service = DirectoryBrowserService(supportsBookmarks: true);
      const rootBookmark = 'root-bookmark';

      final grants = await service.createGrants(
        DirectoryAccessGrant(path: root.path, bookmarkData: rootBookmark),
        <String>[root.path, child.path],
      );

      expect(grants, hasLength(2));
      expect(grants[0].bookmarkData, rootBookmark);
      expect(grants[1].path, child.path);
      expect(grants[1].bookmarkData, 'child-bookmark');
      expect(calls.map((call) => call.method), <String>[
        'startAccessingBookmark',
        'createBookmark',
        'stopAccessingBookmark',
      ]);
    },
  );
}
