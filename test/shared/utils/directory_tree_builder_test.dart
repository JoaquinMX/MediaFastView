import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_tree_node.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/shared/utils/directory_tree_builder.dart';

DirectoryEntity _root(String path, String name) {
  return DirectoryEntity(
    id: 'id-$name',
    path: path,
    name: name,
    thumbnailPath: null,
    tagIds: const [],
    lastModified: DateTime(2024),
  );
}

MediaEntity _media(String path) {
  return MediaEntity(
    id: 'media-$path',
    path: path,
    name: path.split('/').last,
    type: MediaType.image,
    size: 1,
    lastModified: DateTime(2024),
    tagIds: const [],
    // Deliberately the root's id, mirroring production: the scanner stamps the
    // library root on every file, so it can never identify the folder a file is
    // actually in. The builder must go by `path` alone.
    directoryId: 'id-Photos',
  );
}

DirectoryTreeNode _child(DirectoryTreeNode node, String name) {
  return node.children.firstWhere((child) => child.name == name);
}

void main() {
  group('buildDirectoryTree', () {
    test('returns nothing when there are no roots', () {
      expect(
        buildDirectoryTree(
          roots: const [],
          media: [_media('/Photos/a.jpg')],
        ),
        isEmpty,
      );
    });

    test('keeps a root with no matching media, so the filter stays stable', () {
      final tree = buildDirectoryTree(
        roots: [_root('/Photos', 'Photos'), _root('/Downloads', 'Downloads')],
        media: [_media('/Photos/a.jpg')],
      );

      expect(tree.map((node) => node.name), ['Downloads', 'Photos']);
      final downloads = tree.first;
      expect(downloads.totalMediaCount, 0);
      expect(downloads.children, isEmpty);
    });

    test('nests sub-directories and rolls counts up to the root', () {
      final tree = buildDirectoryTree(
        roots: [_root('/Photos', 'Photos')],
        media: [
          _media('/Photos/loose.jpg'),
          _media('/Photos/2024/a.jpg'),
          _media('/Photos/2024/b.jpg'),
          _media('/Photos/2024/Trips/c.jpg'),
        ],
      );

      expect(tree, hasLength(1));
      final photos = tree.single;
      expect(photos.directMediaCount, 1);
      expect(photos.totalMediaCount, 4);

      final year = _child(photos, '2024');
      expect(year.directMediaCount, 2);
      expect(year.totalMediaCount, 3);

      final trips = _child(year, 'Trips');
      expect(trips.directMediaCount, 1);
      expect(trips.totalMediaCount, 1);
      expect(trips.hasChildren, isFalse);
    });

    test('materialises intermediate directories that hold no media of their own',
        () {
      final tree = buildDirectoryTree(
        roots: [_root('/Photos', 'Photos')],
        media: [_media('/Photos/2024/Trips/c.jpg')],
      );

      final photos = tree.single;
      expect(photos.directMediaCount, 0);
      expect(photos.totalMediaCount, 1);

      // /Photos/2024 holds nothing directly but must still exist as a step on
      // the way down to Trips.
      final year = _child(photos, '2024');
      expect(year.directMediaCount, 0);
      expect(year.totalMediaCount, 1);
      expect(_child(year, 'Trips').directMediaCount, 1);
    });

    test('ignores media that lies outside every root', () {
      final tree = buildDirectoryTree(
        roots: [_root('/Photos', 'Photos')],
        media: [_media('/Photos/a.jpg'), _media('/Elsewhere/b.jpg')],
      );

      expect(tree.single.totalMediaCount, 1);
      expect(tree.single.children, isEmpty);
    });

    test('sorts children by name, case insensitively', () {
      final tree = buildDirectoryTree(
        roots: [_root('/Photos', 'Photos')],
        media: [
          _media('/Photos/zebra/a.jpg'),
          _media('/Photos/Apple/b.jpg'),
          _media('/Photos/mango/c.jpg'),
        ],
      );

      expect(
        tree.single.children.map((child) => child.name),
        ['Apple', 'mango', 'zebra'],
      );
    });

    test('normalizes paths before comparing them', () {
      final tree = buildDirectoryTree(
        roots: [_root('/Photos/', 'Photos')],
        media: [_media('/Photos/2024/./a.jpg')],
      );

      expect(tree.single.path, '/Photos');
      expect(_child(tree.single, '2024').path, '/Photos/2024');
    });

    test('subtree yields the node and every descendant', () {
      final tree = buildDirectoryTree(
        roots: [_root('/Photos', 'Photos')],
        media: [
          _media('/Photos/2024/a.jpg'),
          _media('/Photos/2024/Trips/b.jpg'),
        ],
      );

      expect(
        tree.single.subtree.map((node) => node.path),
        containsAll(<String>['/Photos', '/Photos/2024', '/Photos/2024/Trips']),
      );
      expect(tree.single.subtree, hasLength(3));
    });
  });

  group('collectDirectoryPaths', () {
    test('includes roots even when they hold no media', () {
      expect(
        collectDirectoryPaths(
          roots: [_root('/Photos', 'Photos')],
          media: const [],
        ),
        {'/Photos'},
      );
    });

    test('includes every parent and its ancestors up to the root', () {
      expect(
        collectDirectoryPaths(
          roots: [_root('/Photos', 'Photos')],
          media: [
            _media('/Photos/a.jpg'),
            _media('/Photos/2024/Trips/b.jpg'),
          ],
        ),
        {'/Photos', '/Photos/2024', '/Photos/2024/Trips'},
      );
    });

    test('ignores media outside every root', () {
      expect(
        collectDirectoryPaths(
          roots: [_root('/Photos', 'Photos')],
          media: [_media('/Elsewhere/b.jpg')],
        ),
        {'/Photos'},
      );
    });
  });

  group('findContainingRootPath', () {
    const roots = ['/Photos', '/Downloads'];

    test('matches the root itself', () {
      expect(findContainingRootPath('/Photos', roots), '/Photos');
    });

    test('matches a nested path', () {
      expect(
        findContainingRootPath('/Photos/2024/Trips', roots),
        '/Photos',
      );
    });

    test('returns null outside every root', () {
      expect(findContainingRootPath('/Elsewhere', roots), isNull);
    });

    test('does not match a sibling that merely shares a prefix', () {
      expect(findContainingRootPath('/PhotosArchive/a.jpg', roots), isNull);
    });
  });
}
