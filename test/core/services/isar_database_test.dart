import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:media_fast_view/core/services/isar_database.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'isar_database_test.mocks.dart';

@GenerateMocks([Isar])
void main() {
  group('IsarDatabase', () {
    late Directory tempDirectory;
    late MockIsar mockIsar;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp('isar_database_test');
      mockIsar = MockIsar();
      when(mockIsar.isOpen).thenReturn(true);
      when(mockIsar.close(deleteFromDisk: anyNamed('deleteFromDisk'))).thenAnswer((_) async => true);
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('isOpen returns false before database is opened', () {
      final database = IsarDatabase(
        schemas: const <CollectionSchema<dynamic>>[],
        directoryResolver: () async => tempDirectory,
      );

      expect(database.isOpen, isFalse);
    });

    test('instance getter throws StateError when database not opened', () {
      final database = IsarDatabase(
        schemas: const <CollectionSchema<dynamic>>[],
        directoryResolver: () async => tempDirectory,
      );

      expect(() => database.instance, throwsStateError);
    });

    test('open returns isar instance and caches it', () async {
      // Arrange
      var openCallCount = 0;

      final database = IsarDatabase(
        schemas: const <CollectionSchema<dynamic>>[],
        name: 'test_db',
        directoryResolver: () async => tempDirectory,
        openIsar: (schemas, {required String directory, String? name}) async {
          openCallCount++;
          expect(directory, tempDirectory.path);
          expect(name, 'test_db');
          expect(schemas, isEmpty);
          return mockIsar;
        },
      );

      // Act
      final instance = await database.open();

      // Assert
      expect(instance, same(mockIsar));
      expect(openCallCount, 1);
      expect(database.isOpen, isTrue);
    });

    test('open returns cached instance on subsequent calls', () async {
      // Arrange
      var openCallCount = 0;

      final database = IsarDatabase(
        schemas: const <CollectionSchema<dynamic>>[],
        directoryResolver: () async => tempDirectory,
        openIsar: (schemas, {required String directory, String? name}) async {
          openCallCount++;
          return mockIsar;
        },
      );

      // Act
      final instance1 = await database.open();
      final instance2 = await database.open();

      // Assert
      expect(instance1, same(mockIsar));
      expect(instance2, same(mockIsar));
      expect(openCallCount, 1); // Only opened once
    });

    test('instance getter returns cached instance after open', () async {
      // Arrange
      final database = IsarDatabase(
        schemas: const <CollectionSchema<dynamic>>[],
        directoryResolver: () async => tempDirectory,
        openIsar: (schemas, {required String directory, String? name}) async => mockIsar,
      );

      // Act
      final openedInstance = await database.open();
      final instanceGetter = database.instance;

      // Assert
      expect(openedInstance, same(mockIsar));
      expect(instanceGetter, same(mockIsar));
    });

    test('close closes the isar instance', () async {
      // Arrange
      final database = IsarDatabase(
        schemas: const <CollectionSchema<dynamic>>[],
        directoryResolver: () async => tempDirectory,
        openIsar: (schemas, {required String directory, String? name}) async => mockIsar,
      );

      // Act
      await database.open();
      await database.close();

      // Assert
      verify(mockIsar.close()).called(1);
    });

    test('isOpen returns false after close', () async {
      // Arrange
      final database = IsarDatabase(
        schemas: const <CollectionSchema<dynamic>>[],
        directoryResolver: () async => tempDirectory,
        openIsar: (schemas, {required String directory, String? name}) async => mockIsar,
      );

      // Act
      await database.open();
      expect(database.isOpen, isTrue);
      await database.close();

      // Assert
      expect(database.isOpen, isFalse);
    });

    test('close is safe when database was never opened', () async {
      // Arrange
      final database = IsarDatabase(
        schemas: const <CollectionSchema<dynamic>>[],
        directoryResolver: () async => tempDirectory,
      );

      // Act
      await database.close();

      // Assert
      expect(database.isOpen, isFalse);
    });

    test('open accepts custom directory parameter', () async {
      // Arrange
      final customDirectory = await Directory.systemTemp.createTemp('custom_isar');
      addTearDown(() => customDirectory.delete(recursive: true));

      var capturedDirectory = '';

      final database = IsarDatabase(
        schemas: const <CollectionSchema<dynamic>>[],
        directoryResolver: () async => tempDirectory,
        openIsar: (schemas, {required String directory, String? name}) async {
          capturedDirectory = directory;
          return mockIsar;
        },
      );

      // Act
      await database.open(directory: customDirectory);

      // Assert
      expect(capturedDirectory, customDirectory.path);
    });
  });
}
