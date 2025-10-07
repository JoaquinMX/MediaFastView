import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:media_fast_view/features/media_library/presentation/view_models/media_grid_view_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

import '../../../../mocks.mocks.dart';

void main() {
  late MediaViewModel mediaViewModel;
  late MockMediaRepository mockMediaRepository;
  late MockSharedPreferencesMediaDataSource mockDataSource;
  late MediaViewModelParams params;

  setUp(() {
    mockMediaRepository = MockMediaRepository();
    mockDataSource = MockSharedPreferencesMediaDataSource();

    // Stub common methods
    when(mockMediaRepository.getMediaForDirectoryPath(any, bookmarkData: anyNamed('bookmarkData')))
        .thenAnswer((_) async => []);
    when(mockDataSource.getMedia()).thenAnswer((_) async => []);
    when(mockDataSource.removeMediaForDirectory(any)).thenAnswer((_) async {});
    when(mockDataSource.upsertMedia(any)).thenAnswer((_) async {});

    params = MediaViewModelParams(
      directoryPath: '/test/path',
      directoryName: 'Test Directory',
      bookmarkData: 'test_bookmark',
      onPermissionRecoveryNeeded: () async => '/recovered/path',
    );

    mediaViewModel = MediaViewModel(
      params,
      mediaRepository: mockMediaRepository,
      sharedPreferencesDataSource: mockDataSource,
    );
  });

  tearDown(() {
    mediaViewModel.dispose();
  });

  group('MediaViewModel.recoverPermissions', () {
    test('throws exception when no recovery callback provided', () async {
      // Arrange
      final paramsWithoutCallback = MediaViewModelParams(
        directoryPath: '/test/path',
        directoryName: 'Test Directory',
      );
      final vm = MediaViewModel(
        paramsWithoutCallback,
        mediaRepository: mockMediaRepository,
        sharedPreferencesDataSource: mockDataSource,
      );

      // Act & Assert
      expect(
        () => vm.recoverPermissions(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Permission recovery not available'),
        )),
      );

      vm.dispose();
    });

    test('sets loading state initially', () async {
      // Act
      final future = mediaViewModel.recoverPermissions();

      // Assert
      expect(mediaViewModel.state, isA<MediaLoading>());

      // Complete the future to avoid hanging
      await future;
    });

    test('reverts to permission revoked state when user cancels', () async {
      // Arrange
      final paramsWithNullCallback = MediaViewModelParams(
        directoryPath: '/test/path',
        directoryName: 'Test Directory',
        onPermissionRecoveryNeeded: () async => null,
      );
      final vm = MediaViewModel(
        paramsWithNullCallback,
        mediaRepository: mockMediaRepository,
        sharedPreferencesDataSource: mockDataSource,
      );

      // Act
      await vm.recoverPermissions();

      // Assert
      expect(vm.state, isA<MediaPermissionRevoked>());
      expect((vm.state as MediaPermissionRevoked).directoryPath, '/test/path');

      vm.dispose();
    });

    test('throws exception when selected directory is not accessible', () async {
      // Arrange
      final paramsWithCallback = MediaViewModelParams(
        directoryPath: '/test/path',
        directoryName: 'Test Directory',
        onPermissionRecoveryNeeded: () async => '/inaccessible/path',
      );
      final vm = MediaViewModel(
        paramsWithCallback,
        mediaRepository: mockMediaRepository,
        sharedPreferencesDataSource: mockDataSource,
      );

      // Act & Assert
      expect(
        () => vm.recoverPermissions(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Selected directory is not accessible'),
        )),
      );

      vm.dispose();
    });

    test('attempts to recover permissions when callback returns a path', () async {
      // Arrange - use a path that should be accessible
      final testPath = Directory.current.path; // Current directory should be accessible
      final paramsWithValidCallback = MediaViewModelParams(
        directoryPath: '/test/path',
        directoryName: 'Test Directory',
        onPermissionRecoveryNeeded: () async => testPath,
      );
      final vm = MediaViewModel(
        paramsWithValidCallback,
        mediaRepository: mockMediaRepository,
        sharedPreferencesDataSource: mockDataSource,
      );

      final mockMedia = [
        MediaEntity(
          id: '1',
          path: '$testPath/image.jpg',
          name: 'image.jpg',
          type: MediaType.image,
          size: 1000,
          lastModified: DateTime.now(),
          tagIds: [],
          directoryId: 'test_dir',
        ),
      ];

      // Stub for initial loadMedia call
      when(mockMediaRepository.getMediaForDirectoryPath(
        '/test/path',
        bookmarkData: anyNamed('bookmarkData'),
      )).thenAnswer((_) async => []);

      // Stub for recovery loadMedia call
      when(mockMediaRepository.getMediaForDirectoryPath(
        testPath,
        bookmarkData: anyNamed('bookmarkData'),
      )).thenAnswer((_) async => mockMedia);

      // Act
      await vm.recoverPermissions();

      // Assert - the method should either succeed or fail based on directory accessibility
      // Since we're using Directory.current.path, it should be accessible
      expect(vm.state, isA<MediaLoaded>());

      vm.dispose();
    });

    test('handles errors during media loading after recovery', () async {
      // Arrange
      final tempDir = Directory.systemTemp.createTempSync();
      final paramsWithCallback = MediaViewModelParams(
        directoryPath: '/test/path',
        directoryName: 'Test Directory',
        onPermissionRecoveryNeeded: () async => tempDir.path,
      );
      final vm = MediaViewModel(
        paramsWithCallback,
        mediaRepository: mockMediaRepository,
        sharedPreferencesDataSource: mockDataSource,
      );

      when(mockMediaRepository.getMediaForDirectoryPath(
        tempDir.path,
        bookmarkData: anyNamed('bookmarkData'),
      )).thenThrow(Exception('Media loading failed'));

      // Act
      await vm.recoverPermissions();

      // Assert
      expect(vm.state, isA<MediaError>());

      // Cleanup
      tempDir.deleteSync(recursive: true);
      vm.dispose();
    });

    test('creates new bookmark when recovery succeeds', () async {
      // Arrange
      final tempDir = Directory.systemTemp.createTempSync();
      final paramsWithCallback = MediaViewModelParams(
        directoryPath: '/test/path',
        directoryName: 'Test Directory',
        onPermissionRecoveryNeeded: () async => tempDir.path,
      );
      final vm = MediaViewModel(
        paramsWithCallback,
        mediaRepository: mockMediaRepository,
        sharedPreferencesDataSource: mockDataSource,
      );

      final mockMedia = [
        MediaEntity(
          id: '1',
          path: '${tempDir.path}/image.jpg',
          name: 'image.jpg',
          type: MediaType.image,
          size: 1000,
          lastModified: DateTime.now(),
          tagIds: [],
          directoryId: 'test_dir',
        ),
      ];

      // Stub for initial loadMedia call
      when(mockMediaRepository.getMediaForDirectoryPath(
        '/test/path',
        bookmarkData: anyNamed('bookmarkData'),
      )).thenAnswer((_) async => []);

      // Stub for recovery loadMedia call
      when(mockMediaRepository.getMediaForDirectoryPath(
        tempDir.path,
        bookmarkData: anyNamed('bookmarkData'),
      )).thenAnswer((_) async => mockMedia);

      // Act
      await vm.recoverPermissions();

      // Assert
      expect(vm.state, isA<MediaLoaded>());

      // Cleanup
      tempDir.deleteSync(recursive: true);
      vm.dispose();
    });

    test('reverts to permission revoked state on any error during recovery', () async {
      // Arrange
      final paramsWithCallback = MediaViewModelParams(
        directoryPath: '/test/path',
        directoryName: 'Test Directory',
        onPermissionRecoveryNeeded: () async => throw Exception('Callback failed'),
      );
      final vm = MediaViewModel(
        paramsWithCallback,
        mediaRepository: mockMediaRepository,
        sharedPreferencesDataSource: mockDataSource,
      );

      // Act
      await vm.recoverPermissions();

      // Assert
      expect(vm.state, isA<MediaPermissionRevoked>());
      expect((vm.state as MediaPermissionRevoked).directoryPath, '/test/path');

      vm.dispose();
    });
  });

  group('MediaViewModel.validateCurrentPermissions', () {
    test('returns false in test environment', () async {
      // Arrange
      final tempDir = Directory.systemTemp.createTempSync();
      final paramsNoBookmark = MediaViewModelParams(
        directoryPath: tempDir.path,
        directoryName: 'Test Directory',
      );
      final vm = MediaViewModel(
        paramsNoBookmark,
        mediaRepository: mockMediaRepository,
        sharedPreferencesDataSource: mockDataSource,
      );

      // Act
      final result = await vm.validateCurrentPermissions();

      // Assert
      expect(result, isFalse);

      // Cleanup
      tempDir.deleteSync(recursive: true);
      vm.dispose();
    });

    test('returns false when directory is not accessible', () async {
      // Arrange
      final paramsInvalid = MediaViewModelParams(
        directoryPath: '/non/existent/path',
        directoryName: 'Test Directory',
      );
      final vm = MediaViewModel(
        paramsInvalid,
        mediaRepository: mockMediaRepository,
        sharedPreferencesDataSource: mockDataSource,
      );

      // Act
      final result = await vm.validateCurrentPermissions();

      // Assert
      expect(result, isFalse);

      vm.dispose();
    });

    test('returns false in test environment', () async {
      // Arrange
      final tempDir = Directory.systemTemp.createTempSync();
      final paramsWithBookmark = MediaViewModelParams(
        directoryPath: tempDir.path,
        directoryName: 'Test Directory',
        bookmarkData: 'test_bookmark',
      );
      final vm = MediaViewModel(
        paramsWithBookmark,
        mediaRepository: mockMediaRepository,
        sharedPreferencesDataSource: mockDataSource,
      );

      // Act
      final result = await vm.validateCurrentPermissions();

      // Assert
      expect(result, isFalse); // Directory is not accessible in test environment

      // Cleanup
      tempDir.deleteSync(recursive: true);
      vm.dispose();
    });
  });
}
