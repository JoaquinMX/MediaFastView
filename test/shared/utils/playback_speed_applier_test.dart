import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/shared/utils/playback_speed_applier.dart';

void main() {
  test('replaces a pending request with the latest speed', () async {
    final firstApplication = Completer<void>();
    final appliedSpeeds = <double>[];
    final rejectedSpeeds = <double>[];
    final applier = PlaybackSpeedApplier(
      apply: (speed) {
        appliedSpeeds.add(speed);
        return speed == 2.0 ? firstApplication.future : Future<void>.value();
      },
      initialSpeed: 1.0,
      onRejected: (attemptedSpeed, fallbackSpeed, error, stackTrace) {
        rejectedSpeeds.add(attemptedSpeed);
      },
    );

    applier.request(2.0);
    await Future<void>.delayed(Duration.zero);
    applier.request(3.0);
    applier.request(4.0);
    firstApplication.complete();
    await pumpEventQueue();

    expect(appliedSpeeds, <double>[2.0, 4.0]);
    expect(applier.lastAppliedSpeed, 4.0);
    expect(rejectedSpeeds, isEmpty);
  });

  test(
    'restores the last applied speed and reports latest rejection',
    () async {
      final appliedSpeeds = <double>[];
      final rejections = <(double, double)>[];
      final applier = PlaybackSpeedApplier(
        apply: (speed) async {
          appliedSpeeds.add(speed);
          if (speed == 16.0) {
            throw StateError('Unsupported speed');
          }
        },
        initialSpeed: 1.0,
        onRejected: (attemptedSpeed, fallbackSpeed, error, stackTrace) {
          rejections.add((attemptedSpeed, fallbackSpeed));
        },
      );

      applier.request(16.0);
      await pumpEventQueue();

      expect(appliedSpeeds, <double>[16.0, 1.0]);
      expect(applier.lastAppliedSpeed, 1.0);
      expect(rejections, <(double, double)>[(16.0, 1.0)]);
    },
  );

  test('does not report a failed request superseded by a newer one', () async {
    final firstApplication = Completer<void>();
    final appliedSpeeds = <double>[];
    final rejectedSpeeds = <double>[];
    final applier = PlaybackSpeedApplier(
      apply: (speed) {
        appliedSpeeds.add(speed);
        return speed == 8.0 ? firstApplication.future : Future<void>.value();
      },
      initialSpeed: 1.0,
      onRejected: (attemptedSpeed, fallbackSpeed, error, stackTrace) {
        rejectedSpeeds.add(attemptedSpeed);
      },
    );

    applier.request(8.0);
    await Future<void>.delayed(Duration.zero);
    applier.request(12.0);
    firstApplication.completeError(StateError('Unsupported speed'));
    await pumpEventQueue();

    expect(appliedSpeeds, <double>[8.0, 1.0, 12.0]);
    expect(applier.lastAppliedSpeed, 12.0);
    expect(rejectedSpeeds, isEmpty);
  });
}
