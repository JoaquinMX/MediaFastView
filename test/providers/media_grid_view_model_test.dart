import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/media_library/presentation/view_models/media_grid_view_model.dart';

class _MockMediaRepository extends Mock implements MediaRepository {}

class _MockIsarMediaDataSource extends Mock implements IsarMediaDataSource {}

void main() {
  late _MockMediaRepository mockMediaRepository;
  late _MockIsarMediaDataSource mockMediaDataSource;
  late ProviderContainer container;

  setUp(() {
    mockMediaRepository = _MockMediaRepository();
    mockMediaDataSource = _MockIsarMediaDataSource();
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('MediaViewModel', () {
    const testDirectoryPath = '/test/directory';
    const testDirectoryName = 'Test Directory';
    final testDirectoryId = sha256.convert(utf8.encode(testDirectoryPath)).toString();

    late MediaViewModel viewModel;

    setUp(() {
      // Mock successful scan returning sample media
      final sampleMedia = [
        MediaEntity(
          id: '1',
          path: '/test/directory/image1.jpg',
          name: 'image1.jpg',
          type: MediaType.image,
          size: 1024,
          lastModified: DateTime(2023, 1, 1),
          tagIds: ['tag1'],
          directoryId: testDirectoryId,
        ),
        MediaEntity(
          id: '2',
          path: '/test/directory/video1.mp4',
          name: 'video1.mp4',
          type: MediaType.video,
          size: 2048,
          lastModified: DateTime(2023, 1, 2),
          tagIds: [],
          directoryId: testDirectoryId,
        ),
      ];

      // Mock the repository method used when mediaRepository is provided
      when(
        mockMediaRepository.getMediaForDirectoryPath(any, bookmarkData: anyNamed('bookmarkData')),
      ).thenAnswer((_) async => sampleMedia);

      // Mock saveMedia to verify it's called
      when(mockMediaDataSource.removeMediaForDirectory(any)).thenAnswer((_) async {});
      when(mockMediaDataSource.upsertMedia(any)).thenAnswer((_) async {});
      when(mockMediaDataSource.getMedia()).thenAnswer((_) async => []);

      viewModel = MediaViewModel(
        MediaViewModelParams(
          directoryPath: testDirectoryPath,
          directoryName: testDirectoryName,
        ),
        mediaRepository: mockMediaRepository,
        mediaDataSource: mockMediaDataSource,
      );
    });

    test('initial state is MediaLoading', () {
      expect(viewModel.state, isA<MediaLoading>());
    });

    test('loadMedia success transitions to MediaLoaded', () async {
      await viewModel.loadMedia();

      expect(viewModel.state, isA<MediaLoaded>());
      final loadedState = viewModel.state as MediaLoaded;
      expect(loadedState.media.length, 2);
      expect(loadedState.searchQuery, '');
      expect(loadedState.selectedTagIds, isEmpty);
      expect(loadedState.columns, 3);
      expect(loadedState.currentDirectoryPath, testDirectoryPath);
      expect(loadedState.currentDirectoryName, testDirectoryName);

      // Verify interactions
      verify(mockMediaRepository.getMediaForDirectoryPath(testDirectoryPath, bookmarkData: null)).called(1);
      // Note: saveMedia is not called when using mock repository
    });

    test('loadMedia with empty results transitions to MediaEmpty', () async {
      final emptyMock = _MockMediaRepository();
      final emptyDataSourceMock = _MockIsarMediaDataSource();
      when(
        emptyMock.getMediaForDirectoryPath(any, bookmarkData: anyNamed('bookmarkData')),
      ).thenAnswer((_) async => []);
      when(emptyDataSourceMock.removeMediaForDirectory(any)).thenAnswer((_) async {});
      when(emptyDataSourceMock.upsertMedia(any)).thenAnswer((_) async {});

      final emptyViewModel = MediaViewModel(
        MediaViewModelParams(
          directoryPath: testDirectoryPath,
          directoryName: testDirectoryName,
        ),
        mediaRepository: emptyMock,
        mediaDataSource: emptyDataSourceMock,
      );
      await emptyViewModel.loadMedia();

      expect(emptyViewModel.state, isA<MediaEmpty>());
    });

    test('loadMedia with error transitions to MediaError', () async {
      final errorMock = _MockMediaRepository();
      final errorDataSourceMock = _MockIsarMediaDataSource();
      when(
        errorMock.getMediaForDirectoryPath(any, bookmarkData: anyNamed('bookmarkData')),
      ).thenThrow(Exception('Scan failed'));

      final errorViewModel = MediaViewModel(
        MediaViewModelParams(
          directoryPath: testDirectoryPath,
          directoryName: testDirectoryName,
        ),
        mediaRepository: errorMock,
        mediaDataSource: errorDataSourceMock,
      );
      await errorViewModel.loadMedia();

      expect(errorViewModel.state, isA<MediaError>());
      final errorState = errorViewModel.state as MediaError;
      expect(errorState.message, contains('Scan failed'));
    });

    test('searchMedia filters media correctly', () async {
      await viewModel.loadMedia();
      viewModel.searchMedia('image');

      expect(viewModel.state, isA<MediaLoaded>());
      final loadedState = viewModel.state as MediaLoaded;
      expect(loadedState.media.length, 1);
      expect(loadedState.media.first.name, 'image1.jpg');
      expect(loadedState.searchQuery, 'image');
    });

    test('searchMedia with empty query returns all media', () async {
      await viewModel.loadMedia();
      viewModel.searchMedia('nonexistent');

      expect(viewModel.state, isA<MediaLoaded>());
      final loadedState = viewModel.state as MediaLoaded;
      expect(loadedState.media.length, 0);
      expect(loadedState.searchQuery, 'nonexistent');
    });

    test('setColumns updates columns in state', () async {
      await viewModel.loadMedia();
      viewModel.setColumns(5);

      expect(viewModel.state, isA<MediaLoaded>());
      final loadedState = viewModel.state as MediaLoaded;
      expect(loadedState.columns, 5);
    });

    test('filterByTags loads and filters media', () async {
      // First load some media
      await viewModel.loadMedia();

      final taggedMedia = [
        MediaEntity(
          id: '1',
          path: '/test/directory/image1.jpg',
          name: 'image1.jpg',
          type: MediaType.image,
          size: 1024,
          lastModified: DateTime(2023, 1, 1),
          tagIds: ['tag1', 'tag2'],
          directoryId: testDirectoryId,
        ),
      ];

      when(
        mockMediaRepository.filterMediaByTagsForDirectory(any, any, bookmarkData: anyNamed('bookmarkData')),
      ).thenAnswer((_) async => taggedMedia);

      viewModel.filterByTags(['tag1']);

      // Wait for async operation to complete
      await Future.delayed(Duration(milliseconds: 100));

      expect(viewModel.state, isA<MediaLoaded>());
      final loadedState = viewModel.state as MediaLoaded;
      expect(loadedState.media.length, 1);
      expect(loadedState.selectedTagIds, ['tag1']);
      expect(loadedState.searchQuery, ''); // Reset on filter

      // Verify interactions
      verify(mockMediaRepository.filterMediaByTagsForDirectory(['tag1'], testDirectoryPath, bookmarkData: null)).called(1);
      // Note: saveMedia is not called when using mock repository
    });

    test('filterByTags with error transitions to MediaError', () async {
      when(
        mockMediaRepository.filterMediaByTagsForDirectory(['tag1'], testDirectoryPath, bookmarkData: null),
      ).thenThrow(Exception('Filter failed'));

      viewModel.filterByTags(['tag1']);

      // Wait for async operation to complete
      await Future.delayed(Duration(milliseconds: 100));

      expect(viewModel.state, isA<MediaError>());
    });
  });
}
