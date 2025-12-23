import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';

const int slideshowControlsHideDelayMinSeconds = 1;
const int slideshowControlsHideDelayMaxSeconds = 30;
const String _slideshowControlsHideDelayKey = 'slideshowControlsHideDelay';

class SlideshowControlsHideDelayNotifier extends StateNotifier<Duration> {
  SlideshowControlsHideDelayNotifier()
      : super(AppConfig.defaultSlideshowControlsHideDelay) {
    _loadDelay();
  }

  Future<void> _loadDelay() async {
    final prefs = await SharedPreferences.getInstance();
    final storedSeconds =
        prefs.getInt(_slideshowControlsHideDelayKey) ??
        AppConfig.defaultSlideshowControlsHideDelay.inSeconds;
    state = Duration(seconds: storedSeconds);
  }

  Future<void> setDelay(Duration delay) async {
    final clampedSeconds = delay.inSeconds
        .clamp(
          slideshowControlsHideDelayMinSeconds,
          slideshowControlsHideDelayMaxSeconds,
        )
        .toInt();
    if (state.inSeconds == clampedSeconds) {
      return;
    }
    state = Duration(seconds: clampedSeconds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_slideshowControlsHideDelayKey, clampedSeconds);
  }
}

final slideshowControlsHideDelayProvider =
    StateNotifierProvider<SlideshowControlsHideDelayNotifier, Duration>((ref) {
      return SlideshowControlsHideDelayNotifier();
    });
