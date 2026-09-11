import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:media_fast_view/core/services/isar_database.dart';
import 'package:media_fast_view/core/models/media_lookup_mode.dart';
import 'package:media_fast_view/core/models/video_frame_lookup_precision.dart';
import 'package:media_fast_view/features/duplicates/data/data_sources/video_maximum_frame_index_data_source.dart';
import 'package:media_fast_view/features/duplicates/data/isar/maximum_video_frame_descriptor_codec.dart';
import 'package:media_fast_view/features/duplicates/data/isar/video_maximum_frame_index_chunk_collection.dart';
import 'package:media_fast_view/features/duplicates/data/isar/video_maximum_frame_index_status_collection.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/maximum_video_frame_descriptor.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/perceptual_hash.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/video_frame_presentation_time.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/video_maximum_frame_index_chunk.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/video_maximum_frame_index_status.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_query.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_source.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_sensitivity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

import '../../../helpers/legacy_maximum_chunk_schema.dart';
import '../../../helpers/maximum_lookup_benchmark_fakes.dart';

/// Uses the bundled native core, without downloads or the live app database.
const _corePath =
    'macos/Flutter/ephemeral/.symlinks/plugins/'
    'isar_flutter_libs/macos/libisar.dylib';

void main() {
  final canRun = Platform.isMacOS && File(_corePath).existsSync();
  final fullScale =
      const bool.fromEnvironment('MAXIMUM_FRAME_BENCHMARK') ||
      Platform.environment['MAXIMUM_FRAME_BENCHMARK'] == 'true';

  test(
    'a copied pre-metadata database opens without rebuilding descriptors',
    () async {
      await Isar.initializeIsarCore(
        libraries: <Abi, String>{
          Abi.macosArm64: File(_corePath).absolute.path,
          Abi.macosX64: File(_corePath).absolute.path,
        },
      );
      final root = await Directory.systemTemp.createTemp('maximum-migration-');
      final originalDirectory = await Directory(
        '${root.path}/original',
      ).create();
      final copiedDirectory = await Directory('${root.path}/copied').create();
      final original = await Isar.open(
        <CollectionSchema<dynamic>>[
          legacyMaximumChunkSchema(),
          VideoMaximumFrameIndexStatusCollectionSchema,
        ],
        directory: originalDirectory.path,
        name: 'legacy_metadata',
        inspector: false,
      );
      final bytes = const MaximumVideoFrameDescriptorCodec()
          .encode(<MaximumVideoFrameDescriptor>[
            const MaximumVideoFrameDescriptor(
              mediaId: 'legacy',
              frameIndex: 0,
              timestamp: Duration.zero,
              fullFrameHash: -1,
              centerCropHash: 4,
              width: 1920,
              height: 1080,
            ),
          ]);
      final row = VideoMaximumFrameIndexChunkCollection(
        mediaId: 'legacy',
        chunkIndex: 0,
        fingerprint: 'unchanged',
        descriptorBytes: bytes,
        computedAt: DateTime.utc(2024),
      );
      final upgraded = IsarDatabase(
        schemas: const <CollectionSchema<dynamic>>[
          VideoMaximumFrameIndexChunkCollectionSchema,
          VideoMaximumFrameIndexStatusCollectionSchema,
        ],
        name: 'legacy_metadata',
        directoryResolver: () async => copiedDirectory,
      );
      addTearDown(() async {
        if (original.isOpen) {
          await original.close();
        }
        await upgraded.close();
        await root.delete(recursive: true);
      });
      await original.writeTxn(
        () => original.collection<VideoMaximumFrameIndexChunkCollection>().put(
          row,
        ),
      );
      await original.copyToFile('${copiedDirectory.path}/legacy_metadata.isar');
      await original.close();
      final opened = await upgraded.open();
      final collection = opened
          .collection<VideoMaximumFrameIndexChunkCollection>();
      expect((await collection.get(row.id))!.encodedByteCount, isNull);
      final source = IsarVideoMaximumFrameIndexDataSource(upgraded);
      expect(await source.getCacheSize(), bytes.length);
      final preserved = (await collection.get(row.id))!;
      expect(preserved.descriptorBytes, bytes);
      expect(preserved.fingerprint, 'unchanged');
      expect(preserved.toDomain().descriptors.single.fullFrameHash, -1);
    },
    skip: canRun ? false : 'Requires the bundled macOS Isar core.',
  );

  test(
    'real Isar maximum-frame scan benchmark',
    () async {
      await Isar.initializeIsarCore(
        libraries: <Abi, String>{
          Abi.macosArm64: File(_corePath).absolute.path,
          Abi.macosX64: File(_corePath).absolute.path,
        },
      );
      final directory = await Directory.systemTemp.createTemp('maximum-scan-');
      final database = IsarDatabase(
        schemas: const <CollectionSchema<dynamic>>[
          VideoMaximumFrameIndexChunkCollectionSchema,
          VideoMaximumFrameIndexStatusCollectionSchema,
        ],
        name: 'maximum_benchmark',
        directoryResolver: () async => directory,
      );
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });
      final isar = await database.open();
      final rows = isar.collection<VideoMaximumFrameIndexChunkCollection>();
      final chunkCount = fullScale ? 37188 : 256;
      final videoCount = fullScale ? 2688 : 8;
      const framesPerChunk = 128;
      final computedAt = DateTime.utc(2024);
      final chunksPerVideo = List<int>.filled(videoCount, 0);
      var pending = <VideoMaximumFrameIndexChunkCollection>[];
      for (var index = 0; index < chunkCount; index++) {
        final videoIndex = index % videoCount;
        final chunkIndex = chunksPerVideo[videoIndex]++;
        final mediaId = 'video-$videoIndex';
        final chunk = VideoMaximumFrameIndexChunk(
          mediaId: mediaId,
          chunkIndex: chunkIndex,
          fingerprint: maximumVideoFrameLookupFingerprint(
            size: 1000,
            lastModified: computedAt,
          ),
          computedAt: computedAt,
          descriptors: <MaximumVideoFrameDescriptor>[
            for (var localIndex = 0; localIndex < framesPerChunk; localIndex++)
              MaximumVideoFrameDescriptor(
                mediaId: mediaId,
                frameIndex: chunkIndex * framesPerChunk + localIndex,
                timestamp: Duration(
                  microseconds:
                      (chunkIndex * framesPerChunk + localIndex) *
                      1000000 ~/
                      30,
                ),
                fullFrameHash:
                    (index * 7919 + localIndex) ^ -6148914691236517206,
                centerCropHash:
                    (index * 1543 + localIndex) ^ 3689348814741910323,
                width: 1920,
                height: 1080,
                presentationTime: VideoFramePresentationTime(
                  value: chunkIndex * framesPerChunk + localIndex,
                  timescale: 30,
                ),
              ),
          ],
        );
        pending.add(chunk.toCollection());
        if (pending.length == 128 || index == chunkCount - 1) {
          final batch = pending;
          await isar.writeTxn(() => rows.putAll(batch));
          pending = <VideoMaximumFrameIndexChunkCollection>[];
        }
      }
      final source = IsarVideoMaximumFrameIndexDataSource(database);
      final stopwatch = Stopwatch()..start();
      var frameCount = 0;
      var checksum = 0;
      for (var videoIndex = 0; videoIndex < videoCount; videoIndex++) {
        await for (final chunk in source.streamChunks('video-$videoIndex')) {
          for (final descriptor in chunk.descriptors) {
            checksum += hammingDistance(0, descriptor.fullFrameHash);
            checksum += hammingDistance(0, descriptor.centerCropHash);
            frameCount++;
          }
        }
      }
      stopwatch.stop();
      expect(frameCount, chunkCount * framesPerChunk);
      expect(checksum, greaterThan(0));
      final packedStopwatch = Stopwatch()..start();
      var packedFrameCount = 0;
      var packedChecksum = 0;
      for (var videoIndex = 0; videoIndex < videoCount; videoIndex++) {
        var expectedChunkIndex = 0;
        var expectedFrameIndex = 0;
        await for (final chunk in source.streamEncodedChunks(
          'video-$videoIndex',
        )) {
          expect(chunk.chunkIndex, expectedChunkIndex++);
          final records = const MaximumVideoFrameDescriptorCodec().readPacked(
            mediaId: chunk.mediaId,
            bytes: chunk.descriptorBytes,
          );
          for (var index = 0; index < records.count; index++) {
            if (records.frameIndexAt(index) != expectedFrameIndex++) {
              fail('Composite index pagination lost frame order.');
            }
            packedChecksum += hammingDistance(
              0,
              records.fullFrameHashAt(index),
            );
            packedChecksum += hammingDistance(
              0,
              records.centerCropHashAt(index),
            );
            packedFrameCount++;
          }
        }
      }
      packedStopwatch.stop();
      expect(packedFrameCount, frameCount);
      expect(packedChecksum, checksum);
      final videos = <MediaEntity>[
        for (var index = 0; index < videoCount; index++)
          MediaEntity(
            id: 'video-$index',
            path: '/benchmark/video-$index.mov',
            name: 'video-$index',
            type: MediaType.video,
            size: 1000,
            lastModified: computedAt,
            tagIds: const <String>[],
            directoryId: 'benchmark',
          ),
      ];
      await isar.writeTxn(
        () => isar.collection<VideoMaximumFrameIndexStatusCollection>().putAll([
          for (var index = 0; index < videoCount; index++)
            VideoMaximumFrameIndexStatus(
              mediaId: videos[index].id,
              fingerprint: maximumVideoFrameLookupFingerprint(
                size: 1000,
                lastModified: computedAt,
              ),
              sourceSize: 1000,
              sourceLastModified: computedAt,
              descriptorVersion: maximumVideoFrameDescriptorVersion,
              visionRevision: maximumVideoFrameVisionRevision,
              frameCount: chunksPerVideo[index] * framesPerChunk,
              chunkCount: chunksPerVideo[index],
              state: MaximumVideoFrameIndexState.complete,
              computedAt: computedAt,
            ).toCollection(),
        ]),
      );
      final repository = storageBenchmarkRepository(
        videos: videos,
        dataSource: source,
      );
      final pipelineWatch = Stopwatch()..start();
      int? firstResultMilliseconds;
      final result = await repository.rematchImageQueries(
        queries: <ImageLookupQuery>[
          ImageLookupQuery(
            source: ImageLookupSource(
              path: '/benchmark/query.png',
              name: 'query.png',
              size: 1,
              lastModified: computedAt,
            ),
            hash: 0,
            width: 128,
            height: 96,
          ),
        ],
        sensitivity: DuplicateSensitivity.strict,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
        onUpdate: (update) {
          if (update.results.any((result) => result.matches.isNotEmpty)) {
            firstResultMilliseconds ??= pipelineWatch.elapsedMilliseconds;
          }
        },
      );
      pipelineWatch.stop();
      expect(result.verificationSummary!.eligibleVideoCount, videoCount);
      expect(result.verificationSummary!.invalidIndexVideoCount, 0);
      expect(result.verificationSummary!.failedVideoCount, 0);
      expect(result.verificationSummary!.verifiedVideoCount, videoCount);
      expect(result.results.single.matches, hasLength(videoCount));
      final expectedBytes = chunkCount * (12 + framesPerChunk * 48);
      expect(await source.getCacheSize(), expectedBytes);
      // Simulate old rows with no persisted length metadata. Exercise several
      // backfill batches without replacing any descriptors or completion data.
      final legacyRows = await rows.where().limit(70).findAll();
      final originalBytes = List<int>.from(legacyRows.first.descriptorBytes);
      await isar.writeTxn(() async {
        for (final row in legacyRows) {
          row.encodedByteCount = null;
        }
        await rows.putAll(legacyRows);
      });
      expect(await rows.where().encodedByteCountIsNull().count(), 70);
      final cacheSizes = await Future.wait(<Future<int>>[
        source.getCacheSize(),
        source.getCacheSize(),
      ]);
      expect(cacheSizes, <int>[expectedBytes, expectedBytes]);
      expect(await rows.where().encodedByteCountIsNull().count(), 0);
      expect(
        (await rows.get(legacyRows.first.id))!.descriptorBytes,
        originalBytes,
      );
      final metadataStopwatch = Stopwatch()..start();
      expect(await source.getCacheSize(), expectedBytes);
      metadataStopwatch.stop();
      // Kept as a benchmark report, not a flaky hardware-specific speed gate.
      // ignore: avoid_print
      print(
        'Maximum index real-Isar baseline: frames=$frameCount '
        'videos=$videoCount decodeAndHashMs=${stopwatch.elapsedMilliseconds} '
        'packedAndHashMs=${packedStopwatch.elapsedMilliseconds} '
        'metadataSizeMs=${metadataStopwatch.elapsedMilliseconds} '
        'repositoryWithFakeVisionMs=${pipelineWatch.elapsedMilliseconds} '
        'firstResultWithFakeVisionMs=$firstResultMilliseconds '
        'checksum=$checksum peakRssBytes=${ProcessInfo.maxRss}',
      );
      await isar.writeTxn(() async {
        for (final row in legacyRows) {
          row.encodedByteCount = null;
        }
        await rows.putAll(legacyRows);
      });
      final pendingBackfill = source.getCacheSize();
      await source.clear();
      await pendingBackfill;
      expect(await rows.count(), 0);
      expect(await source.getCacheSize(), 0);
    },
    skip: canRun ? false : 'Requires the bundled macOS Isar core.',
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
