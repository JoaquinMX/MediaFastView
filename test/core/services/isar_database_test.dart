import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:media_fast_view/core/services/isar_database.dart';
import 'package:mockito/mockito.dart';

class _MockIsar extends Mock implements Isar {}

void main() {
  group('IsarDatabase', () {
    late Directory tempDirectory;
    late _MockIsar mockIsar;
    late int openInvocations;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp('isar_database_test');
      mockIsar = _MockIsar();
      openInvocations = 0;
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('opens database once and caches the instance', () async {
      var isOpen = true;
      when(mockIsar.isOpen).thenAnswer((_) => isOpen);
      when(mockIsar.close()).thenAnswer((_) async {
        isOpen = false;
        return true;
      });

      final database = IsarDatabase(
        schemas: const <CollectionSchema<dynamic>>[],
        name: 'test_db',
        directoryResolver: () async => tempDirectory,
        openIsar: (
          schemas, {
          String? directory,
          String? name,
        }) async {
          openInvocations++;
          expect(directory, tempDirectory.path);
          expect(name, 'test_db');
          expect(schemas, isEmpty);
          return mockIsar;
        },
      );

      expect(database.isOpen, isFalse);
      expect(() => database.instance, throwsStateError);

      final instance = await database.open();

      expect(instance, same(mockIsar));
      expect(database.instance, same(mockIsar));
      expect(database.isOpen, isTrue);
      expect(await database.open(), same(mockIsar));
      expect(openInvocations, 1);

      await database.close();
      expect(database.isOpen, isFalse);
      expect(() => database.instance, throwsStateError);
    });

    test('close is safe when database was never opened', () async {
      final database = IsarDatabase(
        schemas: const <CollectionSchema<dynamic>>[],
        directoryResolver: () async => tempDirectory,
      );

      await database.close();

      expect(database.isOpen, isFalse);
    });
  });
}
