import 'dart:async';

/// Applies playback-speed requests sequentially to a media backend.
///
/// Newer requests replace pending ones, which prevents rapid slider changes
/// from allowing an older asynchronous request to win.
class PlaybackSpeedApplier {
  PlaybackSpeedApplier({
    required Future<void> Function(double speed) apply,
    required double initialSpeed,
    required void Function(
      double attemptedSpeed,
      double fallbackSpeed,
      Object error,
      StackTrace stackTrace,
    )
    onRejected,
  }) : _apply = apply,
       _lastAppliedSpeed = initialSpeed,
       _onRejected = onRejected;

  final Future<void> Function(double speed) _apply;
  final void Function(
    double attemptedSpeed,
    double fallbackSpeed,
    Object error,
    StackTrace stackTrace,
  )
  _onRejected;

  double _lastAppliedSpeed;
  double? _pendingSpeed;
  bool _isApplying = false;
  bool _isDisposed = false;

  double get lastAppliedSpeed => _lastAppliedSpeed;

  /// Queues [speed], replacing any request that has not started yet.
  void request(double speed) {
    if (_isDisposed) {
      return;
    }

    _pendingSpeed = speed;
    if (!_isApplying) {
      unawaited(_drain());
    }
  }

  /// Prevents pending requests and callbacks from continuing.
  void dispose() {
    _isDisposed = true;
    _pendingSpeed = null;
  }

  Future<void> _drain() async {
    _isApplying = true;
    try {
      while (!_isDisposed && _pendingSpeed != null) {
        final requestedSpeed = _pendingSpeed!;
        _pendingSpeed = null;
        final fallbackSpeed = _lastAppliedSpeed;

        try {
          await _apply(requestedSpeed);
          if (_isDisposed) {
            return;
          }
          _lastAppliedSpeed = requestedSpeed;
        } catch (error, stackTrace) {
          if (_isDisposed) {
            return;
          }

          try {
            await _apply(fallbackSpeed);
          } catch (_) {
            // The original error is the actionable failure. The player widget
            // logs it and restores its state through [_onRejected].
          }

          if (_isDisposed) {
            return;
          }

          if (_pendingSpeed == null) {
            _onRejected(requestedSpeed, fallbackSpeed, error, stackTrace);
          }
        }
      }
    } finally {
      _isApplying = false;
      if (!_isDisposed && _pendingSpeed != null) {
        unawaited(_drain());
      }
    }
  }
}
