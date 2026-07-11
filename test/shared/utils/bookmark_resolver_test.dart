import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/shared/utils/bookmark_resolver.dart';

DirectoryEntity _directory(String path, {String? bookmark}) {
  return DirectoryEntity(
    id: 'id-$path',
    path: path,
    name: path.split('/').last,
    thumbnailPath: null,
    tagIds: const [],
    lastModified: DateTime(2024),
    bookmarkData: bookmark,
  );
}

void main() {
  group('resolveBookmarkForPath', () {
    test('returns the bookmark of the root that contains the path', () {
      final directories = [
        _directory('/Photos', bookmark: 'photos-bookmark'),
        _directory('/Downloads', bookmark: 'downloads-bookmark'),
      ];

      expect(
        resolveBookmarkForPath('/Photos/2024/Trips', directories),
        'photos-bookmark',
      );
    });

    test('matches the root itself, not just paths beneath it', () {
      final directories = [_directory('/Photos', bookmark: 'photos-bookmark')];

      expect(
        resolveBookmarkForPath('/Photos', directories),
        'photos-bookmark',
      );
    });

    test('prefers the deepest root when roots are nested', () {
      // The user added both. The more specific bookmark is the one that
      // reliably covers the path.
      final directories = [
        _directory('/Photos', bookmark: 'shallow'),
        _directory('/Photos/2024', bookmark: 'deep'),
      ];

      expect(
        resolveBookmarkForPath('/Photos/2024/Trips', directories),
        'deep',
      );
    });

    test('is not sensitive to the order the roots come in', () {
      final directories = [
        _directory('/Photos/2024', bookmark: 'deep'),
        _directory('/Photos', bookmark: 'shallow'),
      ];

      expect(
        resolveBookmarkForPath('/Photos/2024/Trips', directories),
        'deep',
      );
    });

    test('skips roots that have no bookmark', () {
      // The deeper root would win on path, but it grants no access, so the
      // shallower one that actually carries a bookmark must be used.
      final directories = [
        _directory('/Photos', bookmark: 'photos-bookmark'),
        _directory('/Photos/2024'),
      ];

      expect(
        resolveBookmarkForPath('/Photos/2024/Trips', directories),
        'photos-bookmark',
      );
    });

    test('ignores a sibling that merely shares a path prefix', () {
      final directories = [
        _directory('/Photos', bookmark: 'photos-bookmark'),
      ];

      expect(
        resolveBookmarkForPath('/PhotosArchive/a.jpg', directories),
        isNull,
      );
    });

    test('returns null when no root covers the path', () {
      final directories = [_directory('/Photos', bookmark: 'photos-bookmark')];

      expect(resolveBookmarkForPath('/Elsewhere/a.jpg', directories), isNull);
    });

    test('returns null when there are no directories at all', () {
      expect(resolveBookmarkForPath('/Photos/a.jpg', const []), isNull);
    });
  });

  group('resolveScanTarget', () {
    test('scans the directory itself when the bookmark is its own', () {
      // The tracked library root: bookmark and target are the same place.
      expect(resolveScanTarget('/Photos', '/Photos'), '/Photos');
    });

    test('scans the sub-directory, not the root whose bookmark it borrowed', () {
      // The regression. A sub-directory has no bookmark of its own, so it rides
      // on the enclosing root's — but the root's bookmark resolves to the root,
      // and scanning that showed the root's media under the sub-directory's
      // name.
      expect(
        resolveScanTarget('/Photos/2024/Trips', '/Photos'),
        '/Photos/2024/Trips',
      );
    });

    test('falls back to the bookmark when the directory has moved', () {
      // The case the old behaviour existed for: the stored path is stale and
      // the bookmark knows where the directory actually went. The target is not
      // inside the scope, so it cannot be a sub-directory of it.
      expect(
        resolveScanTarget('/old/Photos', '/new/Photos'),
        '/new/Photos',
      );
    });

    test('does not mistake a prefix-sharing sibling for a child', () {
      expect(
        resolveScanTarget('/PhotosArchive', '/Photos'),
        '/Photos',
      );
    });

    test('normalizes before comparing', () {
      expect(resolveScanTarget('/Photos/', '/Photos'), '/Photos/');
      expect(
        resolveScanTarget('/Photos/2024/../2024/Trips', '/Photos'),
        '/Photos/2024/../2024/Trips',
      );
    });
  });
}
