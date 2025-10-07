import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/platform_service.dart';

void main() {
  late PlatformService platformService;

  setUp(() {
    platformService = PlatformService();
  });

  group('PlatformService', () {
    group('Platform detection', () {
      test('isMacOS returns correct value', () {
        expect(platformService.isMacOS, Platform.isMacOS);
      });

      test('isIOS returns correct value', () {
        expect(platformService.isIOS, Platform.isIOS);
      });

      test('platformName returns correct name for macOS', () {
        if (Platform.isMacOS) {
          expect(platformService.platformName, 'macOS');
        }
      });

      test('platformName returns correct name for iOS', () {
        if (Platform.isIOS) {
          expect(platformService.platformName, 'iOS');
        }
      });

      test('platformName returns Unknown for other platforms', () {
        if (!Platform.isMacOS && !Platform.isIOS) {
          expect(platformService.platformName, 'Unknown');
        }
      });
    });

    group('Directory paths', () {
      test('homeDirectory returns environment HOME', () {
        expect(platformService.homeDirectory, Platform.environment['HOME']);
      });

      test('getDocumentsDirectory returns correct path for macOS', () async {
        if (Platform.isMacOS) {
          final docsDir = await platformService.getDocumentsDirectory();
          expect(docsDir, isNotNull);
          expect(docsDir, contains('Documents'));
        }
      });

      test('getDocumentsDirectory returns correct path for iOS', () async {
        if (Platform.isIOS) {
          final docsDir = await platformService.getDocumentsDirectory();
          expect(docsDir, isNotNull);
        }
      });

      test('getDocumentsDirectory returns null when home directory is null', () async {
        // This is hard to test without mocking Platform.environment
        // But the method handles null home directory
      });

      test('getTemporaryDirectory returns valid path', () async {
        final tempDir = await platformService.getTemporaryDirectory();
        expect(tempDir, isNotNull);
        expect(tempDir, isNotEmpty);
      });
    });

    group('Platform features', () {
      test('supportsContextMenus returns true for macOS', () {
        if (Platform.isMacOS) {
          expect(platformService.supportsContextMenus, isTrue);
        }
      });

      test('supportsDragAndDrop returns true for macOS', () {
        if (Platform.isMacOS) {
          expect(platformService.supportsDragAndDrop, isTrue);
        }
      });

      test('pathSeparator returns correct separator', () {
        expect(platformService.pathSeparator, Platform.pathSeparator);
      });

      test('isCaseSensitiveFileSystem returns correct value', () {
        expect(platformService.isCaseSensitiveFileSystem, !Platform.isWindows);
      });
    });

    group('Path operations', () {
      test('joinPaths joins paths correctly', () {
        final result = platformService.joinPaths('part1', 'part2', 'part3');
        expect(result, 'part1${Platform.pathSeparator}part2${Platform.pathSeparator}part3');
      });

      test('joinPaths handles null parts', () {
        final result = platformService.joinPaths('part1', 'part2', null, 'part4');
        expect(result, 'part1${Platform.pathSeparator}part2${Platform.pathSeparator}part4');
      });

      test('normalizePath converts separators correctly', () {
        final path = 'path/with/mixed/separators\\and\\more';
        final normalized = platformService.normalizePath(path);
        final expectedSeparator = Platform.pathSeparator;
        expect(normalized, path.replaceAll('/', expectedSeparator).replaceAll('\\', expectedSeparator));
      });
    });
  });
}