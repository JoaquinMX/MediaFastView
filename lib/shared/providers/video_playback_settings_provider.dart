import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents persisted playback preferences for videos.
@immutable
class VideoPlaybackSettings {
  const VideoPlaybackSettings({
    required this.autoplayVideos,
    required this.loopVideos,
  });

  const VideoPlaybackSettings.initial()
      : autoplayVideos = false,
        loopVideos = false;

  final bool autoplayVideos;
  final bool loopVideos;

  VideoPlaybackSettings copyWith({
    bool? autoplayVideos,
    bool? loopVideos,
  }) {
    return VideoPlaybackSettings(
      autoplayVideos: autoplayVideos ?? this.autoplayVideos,
      loopVideos: loopVideos ?? this.loopVideos,
    );
  }
}

/// Provider that exposes the current [VideoPlaybackSettings].
final videoPlaybackSettingsProvider =
    StateNotifierProvider<VideoPlaybackSettingsNotifier, VideoPlaybackSettings>(
  (ref) => VideoPlaybackSettingsNotifier(),
);

/// Notifier responsible for persisting and updating video playback settings.
class VideoPlaybackSettingsNotifier
    extends StateNotifier<VideoPlaybackSettings> {
  VideoPlaybackSettingsNotifier()
      : super(const VideoPlaybackSettings.initial());

  void setAutoplayVideos(bool enabled) {
    debugPrint('VideoPlaybackSettings: Setting autoplay to $enabled');
    state = state.copyWith(autoplayVideos: enabled);
  }

  void setLoopVideos(bool enabled) {
    debugPrint('VideoPlaybackSettings: Setting loop to $enabled');
    state = state.copyWith(loopVideos: enabled);
  }
}
