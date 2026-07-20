import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/sidecar/data/sidecar_serializer.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_file_entry.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_manifest.dart';

void main() {
  group('SidecarManifest JSON', () {
    test('round-trips through toJson/fromJson', () {
      final manifest = SidecarManifest(
        generatedAt: DateTime.utc(2026, 7, 18, 10),
        folderTags: const <String>['Family'],
        folderFavorite: true,
        tags: const <String, SidecarTagDef>{
          'Family': SidecarTagDef(color: 0xFFFF0000),
          '2024': SidecarTagDef(color: 0xFF00FF00),
        },
        files: const <String, SidecarFileEntry>{
          'IMG_001.jpg': SidecarFileEntry(
            size: 100,
            mtimeMs: 1699999999000,
            tags: <String>['Family'],
            favorite: true,
          ),
          'IMG_002.jpg': SidecarFileEntry(
            size: 200,
            mtimeMs: 1699999999000,
            tags: <String>['Family', '2024'],
          ),
        },
      );

      final restored = SidecarManifest.fromJson(manifest.toJson());

      expect(restored, isNotNull);
      expect(restored!.folderTags, <String>['Family']);
      expect(restored.folderFavorite, isTrue);
      expect(restored.tags.keys, containsAll(<String>['Family', '2024']));
      expect(restored.tags['Family']!.color, 0xFFFF0000);
      expect(restored.files['IMG_001.jpg']!.tags, <String>['Family']);
      expect(restored.files['IMG_001.jpg']!.favorite, isTrue);
      expect(restored.files['IMG_002.jpg']!.favorite, isFalse);
      expect(restored.files['IMG_002.jpg']!.size, 200);
    });

    test('rejects JSON without the manifest schema', () {
      final foreign = <String, dynamic>{'hello': 'world'};
      expect(SidecarManifest.fromJson(foreign), isNull);
    });

    test('isEmpty is true only when nothing is carried', () {
      expect(SidecarManifest(generatedAt: DateTime(2026)).isEmpty, isTrue);
      expect(
        SidecarManifest(
          generatedAt: DateTime(2026),
          folderTags: const <String>['x'],
        ).isEmpty,
        isFalse,
      );
    });
  });

  group('SidecarSerializer', () {
    const serializer = SidecarSerializer();

    test('encode then decode preserves the manifest', () {
      final manifest = SidecarManifest(
        generatedAt: DateTime.utc(2026, 7, 18),
        files: const <String, SidecarFileEntry>{
          'a.jpg': SidecarFileEntry(size: 1, mtimeMs: 2, tags: <String>['T']),
        },
        tags: const <String, SidecarTagDef>{'T': SidecarTagDef(color: 1)},
      );

      final decoded = serializer.decode(serializer.encode(manifest));

      expect(decoded, isNotNull);
      expect(decoded!.files['a.jpg']!.tags, <String>['T']);
    });

    test('decode returns null for non-JSON and for foreign JSON', () {
      expect(serializer.decode('not json {'), isNull);
      expect(serializer.decode('[]'), isNull);
      expect(serializer.decode('{"schema":"other"}'), isNull);
    });
  });
}
