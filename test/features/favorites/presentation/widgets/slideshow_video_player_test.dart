import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:media_fast_view/features/favorites/presentation/widgets/slideshow_video_player.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  _FakeVideoPlayerPlatform();

  final StreamController<VideoEvent> _eventController =
      StreamController<VideoEvent>.broadcast();
  int _textureCounter = 1;
  bool playCalled = false;
  bool pauseCalled = false;
  double lastVolume = 1;
  double lastSpeed = 1;
  bool loopingEnabled = false;

  @override
  Future<int?> create(DataSource dataSource) async {
    final textureId = _textureCounter++;
    _eventController.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 1),
        size: const Size(1, 1),
      ),
    );
    return textureId;
  }

  @override
  Future<void> dispose(int textureId) async {
  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return _eventController.stream;
  }

  @override
  Future<void> setLooping(int textureId, bool looping) async {
    loopingEnabled = looping;
  }

  @override
  Future<void> play(int textureId) async {
    playCalled = true;
  }

  @override
  Future<void> pause(int textureId) async {
    pauseCalled = true;
  }

  @override
  Future<void> setVolume(int textureId, double volume) async {
    lastVolume = volume;
  }

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {
    lastSpeed = speed;
  }

  @override
  Future<void> seekTo(int textureId, Duration position) async {}

  @override
  Future<Duration> getPosition(int textureId) async {
    return const Duration();
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

void main() {
  final media = MediaEntity(
    id: 'video',
    path: '/tmp/video.mp4',
    name: 'video.mp4',
    type: MediaType.video,
    size: 10,
    lastModified: DateTime(2024, 1, 1),
    tagIds: const [],
    directoryId: 'dir',
    bookmarkData: null,
  );

  testWidgets('configures controller based on props', (tester) async {
    final platform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;

    var completed = false;
    var progress = 0.0;

    await tester.pumpWidget(
      MaterialApp(
        home: SlideshowVideoPlayer(
          media: media,
          isPlaying: true,
          isMuted: true,
          isVideoLooping: true,
          playbackSpeed: 2.0,
          onProgress: (value) => progress = value,
          onCompleted: () => completed = true,
        ),
      ),
    );

    await tester.pump();

    expect(platform.playCalled, isTrue);
    expect(platform.lastVolume, 0.0);
    expect(platform.loopingEnabled, isTrue);
    expect(platform.lastSpeed, 2.0);

    platform._eventController.add(
      VideoEvent(eventType: VideoEventType.completed),
    );
    await tester.pump();

    expect(completed, isTrue);
    expect(progress, greaterThanOrEqualTo(0));
  });
}
