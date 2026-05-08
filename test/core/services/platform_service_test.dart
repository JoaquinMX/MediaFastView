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

      test('platformName returns macOS on macOS platform', () {
        if (Platform.isMacOS) {
          expect(platformService.platformName, 'macOS');
        }
      });

      test('platformName returns iOS on iOS platform', () {
        if (Platform.isIOS) {
          expect(platformService.platformName, 'iOS');
        }
      });

      test('platformName returns Unknown for unsupported platforms', () {
        if (!Platform.isMacOS && !Platform.isIOS) {
          expect(platformService.platformName, 'Unknown');
        }
      });
    });

    group('Directory paths', () {
      test('homeDirectory returns environment HOME variable', () {
        expect(platformService.homeDirectory, Platform.environment['HOME']);
      });

      test('getDocumentsDirectory returns non-null path for macOS', () async {
        if (Platform.isMacOS) {
          final docsDir = await platformService.getDocumentsDirectory();
          expect(docsDir, isNotNull);
          expect(docsDir, contains('Documents'));
        }
      });

      test('getDocumentsDirectory returns non-null path for iOS', () async {
        if (Platform.isIOS) {
          final docsDir = await platformService.getDocumentsDirectory();
          expect(docsDir, isNotNull);
        }
      });

      test('getDocumentsDirectory returns null when platform not supported', () async {
        if (!Platform.isMacOS && !Platform.isIOS) {
          final docsDir = await platformService.getDocumentsDirectory();
          expect(docsDir, isNull);
        }
      });

      test('getTemporaryDirectory returns valid non-empty path', () async {
        final tempDir = await platformService.getTemporaryDirectory();
        expect(tempDir, isNotNull);
        expect(tempDir, isNotEmpty);
      });
    });

    group('Platform features', () {
      test('supportsContextMenus returns true only for macOS', () {
        if (Platform.isMacOS) {
          expect(platformService.supportsContextMenus, isTrue);
        } else {
          expect(platformService.supportsContextMenus, isFalse);
        }
      });

      test('supportsDragAndDrop returns true only for macOS', () {
        if (Platform.isMacOS) {
          expect(platformService.supportsDragAndDrop, isTrue);
        } else {
          expect(platformService.supportsDragAndDrop, isFalse);
        }
      });

      test('pathSeparator returns correct platform separator', () {
        expect(platformService.pathSeparator, Platform.pathSeparator);
      });

      test('isCaseSensitiveFileSystem returns false for Windows only', () {
        expect(platformService.isCaseSensitiveFileSystem, !Platform.isWindows);
      });
    });

    group('Path operations', () {
      test('joinPaths joins two parts correctly', () {
        final result = platformService.joinPaths('part1', 'part2');
        expect(result, 'part1${Platform.pathSeparator}part2');
      });

      test('joinPaths joins multiple parts correctly', () {
        final result = platformService.joinPaths('part1', 'part2', 'part3');
        expect(
          result,
          'part1${Platform.pathSeparator}part2${Platform.pathSeparator}part3',
        );
      });

      test('joinPaths joins four parts correctly', () {
        final result = platformService.joinPaths('part1', 'part2', 'part3', 'part4');
        expect(
          result,
          'part1${Platform.pathSeparator}part2${Platform.pathSeparator}part3${Platform.pathSeparator}part4',
        );
      });

      test('joinPaths skips null optional parts', () {
        final result = platformService.joinPaths('part1', 'part2', null, 'part4');
        expect(
          result,
          'part1${Platform.pathSeparator}part2${Platform.pathSeparator}part4',
        );
      });

      test('normalizePath converts forward slashes to platform separator', () {
        final path = 'path/with/forward/slashes';
        final normalized = platformService.normalizePath(path);
        final expected = path.replaceAll('/', Platform.pathSeparator);
        expect(normalized, expected);
      });

      test('normalizePath converts backslashes to platform separator', () {
        final path = 'path\\with\\backslashes';
        final normalized = platformService.normalizePath(path);
        final expected = path.replaceAll('\\', Platform.pathSeparator);
        expect(normalized, expected);
      });

      test('normalizePath converts mixed separators', () {
        final path = 'path/with/mixed\\separators/and\\more';
        final normalized = platformService.normalizePath(path);
        final expected = path
            .replaceAll('/', Platform.pathSeparator)
            .replaceAll('\\', Platform.pathSeparator);
        expect(normalized, expected);
      });
    });
  });
}