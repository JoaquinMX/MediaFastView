import 'package:flutter/foundation.dart';

/// Represents persisted playback preferences for videos.
@immutable
class PlaybackSettings {
  const PlaybackSettings({
    required this.autoplayVideos,
    required this.loopVideos,
  });

  const PlaybackSettings.initial()
      : autoplayVideos = false,
        loopVideos = false;

  final bool autoplayVideos;
  final bool loopVideos;

  PlaybackSettings copyWith({
    bool? autoplayVideos,
    bool? loopVideos,
  }) {
    return PlaybackSettings(
      autoplayVideos: autoplayVideos ?? this.autoplayVideos,
      loopVideos: loopVideos ?? this.loopVideos,
    );
  }
}
