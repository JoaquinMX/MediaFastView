import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/shared/utils/playback_speed_policy.dart';

void main() {
  group('PlaybackSpeedPolicy', () {
    test('clamps and snaps finite speeds to half-step values', () {
      expect(PlaybackSpeedPolicy.normalize(0.1), 0.5);
      expect(PlaybackSpeedPolicy.normalize(2.6), 2.5);
      expect(PlaybackSpeedPolicy.normalize(2.8), 3.0);
      expect(PlaybackSpeedPolicy.normalize(100), 16.0);
    });

    test('rejects non-finite speeds', () {
      expect(PlaybackSpeedPolicy.normalize(double.nan), isNull);
      expect(PlaybackSpeedPolicy.normalize(double.infinity), isNull);
      expect(PlaybackSpeedPolicy.normalize(double.negativeInfinity), isNull);
    });

    test('formats whole and half-step values consistently', () {
      expect(PlaybackSpeedPolicy.format(1.0), '1');
      expect(PlaybackSpeedPolicy.format(1.5), '1.5');
      expect(PlaybackSpeedPolicy.format(16.0), '16');
    });
  });
}
