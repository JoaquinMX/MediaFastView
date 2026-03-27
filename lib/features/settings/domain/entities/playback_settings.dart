import 'package:flutter/foundation.dart';

/// Represents persisted playback preferences for videos.
@immutable
class PlaybackSettings {
  const PlaybackSettings({
    required this.autoplayVideos,
    required this.loopVideos,
    required this.startMuted,
  });

  const PlaybackSettings.initial()
      : autoplayVideos = false,
        loopVideos = false,
        startMuted = false;

  final bool autoplayVideos;
  final bool loopVideos;
  final bool startMuted;

  PlaybackSettings copyWith({
    bool? autoplayVideos,
    bool? loopVideos,
    bool? startMuted,
  }) {
    return PlaybackSettings(
      autoplayVideos: autoplayVideos ?? this.autoplayVideos,
      loopVideos: loopVideos ?? this.loopVideos,
      startMuted: startMuted ?? this.startMuted,
    );
  }
}
