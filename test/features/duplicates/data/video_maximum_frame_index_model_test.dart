import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/duplicates/data/isar/maximum_video_frame_descriptor_codec.dart';
import 'package:media_fast_view/features/duplicates/data/isar/video_maximum_frame_index_chunk_collection.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/maximum_video_frame_descriptor.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/video_frame_presentation_time.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/video_maximum_frame_index_chunk.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/video_maximum_frame_index_status.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_sensitivity.dart';

void main() {
  test(
    'packed views preserve signed hashes, timestamps, and frame metadata',
    () {
      const codec = MaximumVideoFrameDescriptorCodec();
      const hashes = <int>[0, -1, 1, -9223372036854775808, 9223372036854775807];
      final descriptors = <MaximumVideoFrameDescriptor>[
        for (var index = 0; index < hashes.length; index++)
          MaximumVideoFrameDescriptor(
            mediaId: 'signed-frames',
            frameIndex: index,
            timestamp: Duration(milliseconds: index * 33),
            fullFrameHash: hashes[index],
            centerCropHash: hashes[hashes.length - index - 1],
            width: 1920 + index,
            height: 1080,
            presentationTime: VideoFramePresentationTime(
              value: index * 1001,
              timescale: 30000,
            ),
          ),
      ];
      final bytes = codec.encode(descriptors);
      final packed = codec.readPacked(mediaId: 'signed-frames', bytes: bytes);
      final decoded = codec.decode(mediaId: 'signed-frames', bytes: bytes);
      expect(packed.count, hashes.length);
      for (var index = 0; index < packed.count; index++) {
        expect(packed.frameIndexAt(index), decoded[index].frameIndex);
        expect(packed.fullFrameHashAt(index), decoded[index].fullFrameHash);
        expect(packed.centerCropHashAt(index), decoded[index].centerCropHash);
        expect(
          packed.timestampMillisecondsAt(index),
          decoded[index].timestamp.inMilliseconds,
        );
        expect(packed.descriptorAt(index).toJson(), decoded[index].toJson());
      }
      expect(() => packed.fullFrameHashAt(-1), throwsRangeError);
      expect(() => packed.descriptorAt(packed.count), throwsRangeError);
      expect(
        () => codec.readPacked(
          mediaId: 'signed-frames',
          bytes: bytes.sublist(0, bytes.length - 1),
        ),
        throwsFormatException,
      );
    },
  );

  test('Vision thresholds are fixed and ordered by sensitivity', () {
    expect(
      DuplicateSensitivity.strict.visionThreshold,
      lessThan(DuplicateSensitivity.balanced.visionThreshold),
    );
    expect(
      DuplicateSensitivity.balanced.visionThreshold,
      lessThan(DuplicateSensitivity.loose.visionThreshold),
    );
    expect(
      DuplicateSensitivity.strict.coarseThreshold,
      lessThan(DuplicateSensitivity.balanced.coarseThreshold),
    );
    expect(
      DuplicateSensitivity.balanced.coarseThreshold,
      lessThan(DuplicateSensitivity.loose.coarseThreshold),
    );
  });

  test('fingerprint changes when source or descriptor revision changes', () {
    final original = maximumVideoFrameLookupFingerprint(
      size: 100,
      lastModified: DateTime(2024),
    );
    final modified = maximumVideoFrameLookupFingerprint(
      size: 101,
      lastModified: DateTime(2024),
    );
    final revised = maximumVideoFrameLookupFingerprint(
      size: 100,
      lastModified: DateTime(2024),
      descriptorVersion: maximumVideoFrameDescriptorVersion + 1,
    );
    final visionRevised = maximumVideoFrameLookupFingerprint(
      size: 100,
      lastModified: DateTime(2024),
      visionRevision: maximumVideoFrameVisionRevision + 1,
    );

    expect(modified, isNot(original));
    expect(revised, isNot(original));
    expect(visionRevised, isNot(original));
  });

  test('chunk serialization preserves descriptors and completion metadata', () {
    final chunk = VideoMaximumFrameIndexChunk(
      mediaId: 'video',
      chunkIndex: 3,
      fingerprint: 'fingerprint',
      computedAt: DateTime(2024, 1, 2, 3, 4, 5),
      descriptors: <MaximumVideoFrameDescriptor>[
        MaximumVideoFrameDescriptor(
          mediaId: 'video',
          frameIndex: 17,
          timestamp: const Duration(milliseconds: 1234),
          fullFrameHash: -1,
          centerCropHash: 2,
          width: 1920,
          height: 1080,
          presentationTime: const VideoFramePresentationTime(
            value: 3702,
            timescale: 3000,
          ),
        ),
      ],
    );

    final decoded = VideoMaximumFrameIndexChunk.fromJson(chunk.toJson());

    expect(decoded.mediaId, 'video');
    expect(decoded.chunkIndex, 3);
    expect(decoded.fingerprint, 'fingerprint');
    expect(decoded.computedAt, chunk.computedAt);
    expect(decoded.descriptors.single.frameIndex, 17);
    expect(
      decoded.descriptors.single.timestamp,
      const Duration(milliseconds: 1234),
    );
    expect(decoded.descriptors.single.fullFrameHash, -1);
    expect(
      decoded.descriptors.single.presentationTime,
      const VideoFramePresentationTime(value: 3702, timescale: 3000),
    );
  });

  test('packed chunk storage round-trips fixed-width descriptor records', () {
    final descriptors = <MaximumVideoFrameDescriptor>[
      MaximumVideoFrameDescriptor(
        mediaId: 'video',
        frameIndex: 17,
        timestamp: const Duration(milliseconds: 1234),
        fullFrameHash: -1,
        centerCropHash: 0x123456789,
        width: 3840,
        height: 2160,
        presentationTime: const VideoFramePresentationTime(
          value: 3702,
          timescale: 3000,
        ),
      ),
      const MaximumVideoFrameDescriptor(
        mediaId: 'video',
        frameIndex: 18,
        timestamp: Duration(milliseconds: 1267),
        fullFrameHash: -9223372036854775807,
        centerCropHash: 9223372036854775807,
        width: 1280,
        height: 720,
      ),
    ];
    const codec = MaximumVideoFrameDescriptorCodec();

    final bytes = codec.encode(descriptors);
    final decoded = codec.decode(mediaId: 'video', bytes: bytes);

    expect(bytes, hasLength(12 + (48 * descriptors.length)));
    expect(decoded, hasLength(2));
    expect(decoded[0].mediaId, 'video');
    expect(decoded[0].frameIndex, 17);
    expect(decoded[0].timestamp, const Duration(milliseconds: 1234));
    expect(decoded[0].fullFrameHash, -1);
    expect(decoded[0].centerCropHash, 0x123456789);
    expect(decoded[0].width, 3840);
    expect(decoded[0].height, 2160);
    expect(
      decoded[0].presentationTime,
      const VideoFramePresentationTime(value: 3702, timescale: 3000),
    );
    expect(decoded[1].presentationTime, isNull);
  });

  test(
    'Isar chunk mapper persists packed bytes instead of descriptor JSON',
    () {
      final chunk = VideoMaximumFrameIndexChunk(
        mediaId: 'video',
        chunkIndex: 0,
        fingerprint: 'v2',
        descriptors: <MaximumVideoFrameDescriptor>[
          const MaximumVideoFrameDescriptor(
            mediaId: 'video',
            frameIndex: 0,
            timestamp: Duration.zero,
            fullFrameHash: 1,
            centerCropHash: 2,
            width: 640,
            height: 480,
          ),
        ],
        computedAt: DateTime(2024),
      );

      final collection = chunk.toCollection();
      final decoded = collection.toDomain();

      expect(collection.descriptorBytes, hasLength(60));
      expect(decoded.descriptors.single.fullFrameHash, 1);
      expect(decoded.descriptors.single.centerCropHash, 2);
    },
  );

  test('packed chunk decoder rejects truncated data', () {
    expect(
      () => const MaximumVideoFrameDescriptorCodec().decode(
        mediaId: 'video',
        bytes: const <int>[1, 2, 3],
      ),
      throwsFormatException,
    );
  });

  test('only complete statuses are searchable completion markers', () {
    final building = VideoMaximumFrameIndexStatus(
      mediaId: 'video',
      fingerprint: 'fingerprint',
      sourceSize: 100,
      sourceLastModified: DateTime(2024),
      descriptorVersion: maximumVideoFrameDescriptorVersion,
      visionRevision: maximumVideoFrameVisionRevision,
      frameCount: 2,
      chunkCount: 1,
      state: MaximumVideoFrameIndexState.building,
      computedAt: DateTime(2024),
    );

    expect(building.isComplete, isFalse);
    expect(
      building.copyWith(state: MaximumVideoFrameIndexState.complete).isComplete,
      isTrue,
    );
  });
}
