import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:media_fast_view/features/thumbnails/data/native_thumbnail_generator.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_disk_cache.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_request.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_result.dart';

enum ThumbnailPriority { visible, background }

/// Cooperative cancellation shared by providers and batch operations.
class ThumbnailCancellationToken {
  bool _isCancelled = false;
  final Set<VoidCallback> _listeners = <VoidCallback>{};

  bool get isCancelled => _isCancelled;

  VoidCallback addListener(VoidCallback listener) {
    if (_isCancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void cancel() {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    final listeners = List<VoidCallback>.from(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }
}

typedef VoidCallback = void Function();

/// Deduplicates requests and schedules native generation without allowing a
/// background batch to occupy all available decoder capacity.
class ThumbnailCoordinator {
  ThumbnailCoordinator({
    required ThumbnailGenerator generator,
    required ThumbnailDiskCache cache,
    Uuid uuid = const Uuid(),
    this.maximumConcurrent = 2,
    this.maximumBackgroundConcurrent = 1,
  }) : _generator = generator,
       _cache = cache,
       _uuid = uuid;

  final ThumbnailGenerator _generator;
  final ThumbnailDiskCache _cache;
  final Uuid _uuid;
  final int maximumConcurrent;
  final int maximumBackgroundConcurrent;

  final List<_ThumbnailJob> _visibleQueue = <_ThumbnailJob>[];
  final List<_ThumbnailJob> _backgroundQueue = <_ThumbnailJob>[];
  final Map<String, _ThumbnailJob> _jobs = <String, _ThumbnailJob>{};
  int _activeCount = 0;
  int _activeBackgroundCount = 0;
  bool _isDisposed = false;

  Future<ThumbnailResult> load(
    ThumbnailRequest request, {
    ThumbnailPriority priority = ThumbnailPriority.visible,
    ThumbnailCancellationToken? cancellationToken,
  }) async {
    if (!request.isSupported) {
      throw UnsupportedError(
        'Thumbnails are not supported for ${request.mediaType.name}',
      );
    }
    if (_isDisposed || cancellationToken?.isCancelled == true) {
      throw const ThumbnailCancelledException();
    }

    if (request.diskCacheEnabled) {
      final cached = await _cache.read(request);
      if (_isDisposed || cancellationToken?.isCancelled == true) {
        throw const ThumbnailCancelledException();
      }
      if (cached != null) {
        return ThumbnailResult(
          payload: FileThumbnailPayload(cached.path),
          isCacheHit: true,
        );
      }
    }

    return _enqueue(
      request,
      priority: priority,
      cancellationToken: cancellationToken,
    );
  }

  Future<ThumbnailResult> _enqueue(
    ThumbnailRequest request, {
    required ThumbnailPriority priority,
    ThumbnailCancellationToken? cancellationToken,
  }) {
    final cacheKey = _cache.keyFor(request);
    final jobKey = '${request.diskCacheEnabled ? 'disk' : 'memory'}:$cacheKey';
    var job = _jobs[jobKey];
    if (job == null) {
      job = _ThumbnailJob(
        key: jobKey,
        requestId: _uuid.v4(),
        request: request,
        priority: priority,
      );
      _jobs[jobKey] = job;
      _queue(job);
    } else if (priority == ThumbnailPriority.visible &&
        job.priority == ThumbnailPriority.background &&
        !job.isRunning) {
      _backgroundQueue.remove(job);
      job.priority = ThumbnailPriority.visible;
      _visibleQueue.add(job);
    }
    if (job.request.bookmarkData == null &&
        request.bookmarkData != null &&
        !job.isRunning) {
      job.request = request;
    }

    final subscriber = _ThumbnailSubscriber(cancellationToken);
    job.subscribers.add(subscriber);
    subscriber.removeCancellationListener = cancellationToken?.addListener(() {
      _cancelSubscriber(job!, subscriber);
    });
    _drain();
    return subscriber.completer.future;
  }

  void _queue(_ThumbnailJob job) {
    switch (job.priority) {
      case ThumbnailPriority.visible:
        _visibleQueue.add(job);
      case ThumbnailPriority.background:
        _backgroundQueue.add(job);
    }
  }

  void _cancelSubscriber(_ThumbnailJob job, _ThumbnailSubscriber subscriber) {
    if (!subscriber.completer.isCompleted) {
      subscriber.completer.completeError(const ThumbnailCancelledException());
    }
    subscriber.removeCancellationListener?.call();
    job.subscribers.remove(subscriber);
    if (job.subscribers.isNotEmpty) {
      return;
    }

    if (job.isRunning) {
      // A new subscriber must not attach to native work that has already been
      // cancelled. The running job releases its slot when native code replies,
      // while an equivalent new request can be queued independently.
      _jobs.remove(job.key);
      unawaited(_generator.cancel(job.requestId));
      return;
    }

    _visibleQueue.remove(job);
    _backgroundQueue.remove(job);
    _jobs.remove(job.key);
    _drain();
  }

  void _drain() {
    if (_isDisposed) {
      return;
    }

    while (_activeCount < maximumConcurrent) {
      final _ThumbnailJob? job;
      if (_visibleQueue.isNotEmpty) {
        job = _visibleQueue.removeAt(0);
      } else if (_backgroundQueue.isNotEmpty &&
          _activeBackgroundCount < maximumBackgroundConcurrent) {
        job = _backgroundQueue.removeAt(0);
      } else {
        break;
      }

      if (job.subscribers.isEmpty) {
        _jobs.remove(job.key);
        continue;
      }
      _start(job);
    }
  }

  void _start(_ThumbnailJob job) {
    job.isRunning = true;
    _activeCount += 1;
    if (job.priority == ThumbnailPriority.background) {
      _activeBackgroundCount += 1;
    }
    unawaited(_run(job));
  }

  Future<void> _run(_ThumbnailJob job) async {
    try {
      final native = await _generator.generate(
        job.request,
        requestId: job.requestId,
      );
      late final ThumbnailPayload payload;
      if (job.request.diskCacheEnabled) {
        try {
          final file = await _cache.write(job.request, native.bytes);
          payload = FileThumbnailPayload(file.path);
        } catch (_) {
          payload = MemoryThumbnailPayload(native.bytes);
        }
      } else {
        payload = MemoryThumbnailPayload(native.bytes);
      }
      _complete(job, ThumbnailResult(payload: payload, isCacheHit: false));
    } catch (error, stackTrace) {
      _completeError(job, error, stackTrace);
    } finally {
      _activeCount -= 1;
      if (job.priority == ThumbnailPriority.background) {
        _activeBackgroundCount -= 1;
      }
      if (identical(_jobs[job.key], job)) {
        _jobs.remove(job.key);
      }
      _drain();
    }
  }

  void _complete(_ThumbnailJob job, ThumbnailResult result) {
    for (final subscriber in List<_ThumbnailSubscriber>.from(job.subscribers)) {
      subscriber.removeCancellationListener?.call();
      if (!subscriber.completer.isCompleted) {
        subscriber.completer.complete(result);
      }
    }
    job.subscribers.clear();
  }

  void _completeError(_ThumbnailJob job, Object error, StackTrace stackTrace) {
    for (final subscriber in List<_ThumbnailSubscriber>.from(job.subscribers)) {
      subscriber.removeCancellationListener?.call();
      if (!subscriber.completer.isCompleted) {
        subscriber.completer.completeError(error, stackTrace);
      }
    }
    job.subscribers.clear();
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    final jobs = List<_ThumbnailJob>.from(_jobs.values);
    _visibleQueue.clear();
    _backgroundQueue.clear();
    for (final job in jobs) {
      for (final subscriber in job.subscribers) {
        subscriber.removeCancellationListener?.call();
        if (!subscriber.completer.isCompleted) {
          subscriber.completer.completeError(
            const ThumbnailCancelledException(),
          );
        }
      }
      job.subscribers.clear();
      if (job.isRunning) {
        await _generator.cancel(job.requestId);
      }
    }
    _jobs.clear();
  }
}

class _ThumbnailJob {
  _ThumbnailJob({
    required this.key,
    required this.requestId,
    required this.request,
    required this.priority,
  });

  final String key;
  final String requestId;
  ThumbnailRequest request;
  ThumbnailPriority priority;
  bool isRunning = false;
  final Set<_ThumbnailSubscriber> subscribers = <_ThumbnailSubscriber>{};
}

class _ThumbnailSubscriber {
  _ThumbnailSubscriber(this.cancellationToken);

  final ThumbnailCancellationToken? cancellationToken;
  final Completer<ThumbnailResult> completer = Completer<ThumbnailResult>();
  VoidCallback? removeCancellationListener;
}
