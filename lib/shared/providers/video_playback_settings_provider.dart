import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      : super(const VideoPlaybackSettings.initial()) {
    _loadSettings();
  }

  static const _autoplayKey = 'video_autoplay_enabled';
  static const _loopKey = 'video_loop_enabled';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final autoplay = prefs.getBool(_autoplayKey) ?? false;
    final loop = prefs.getBool(_loopKey) ?? false;
    state = VideoPlaybackSettings(
      autoplayVideos: autoplay,
      loopVideos: loop,
    );
  }

  Future<void> setAutoplayVideos(bool enabled) async {
    debugPrint('VideoPlaybackSettings: Setting autoplay to $enabled');
    state = state.copyWith(autoplayVideos: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoplayKey, enabled);
  }

  Future<void> setLoopVideos(bool enabled) async {
    debugPrint('VideoPlaybackSettings: Setting loop to $enabled');
    state = state.copyWith(loopVideos: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loopKey, enabled);
  }
}
