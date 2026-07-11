import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/file_transfer_result.dart';
import '../../core/services/logging_service.dart';
import '../../features/media_library/domain/entities/media_entity.dart';

enum MediaMutationKind { deleted, moved, copied }

/// A filesystem change that already happened, expressed as a delta every open
/// grid can apply to its own list without rescanning the disk.
@immutable
class MediaMutation {
  const MediaMutation({
    required this.sequence,
    required this.kind,
    this.removed = const <MediaEntity>[],
    this.added = const <MediaEntity>[],
  });

  /// Monotonic. Lets a listener ignore a mutation it already applied, and keeps
  /// two identical consecutive mutations distinguishable.
  final int sequence;

  final MediaMutationKind kind;

  /// The items as they were *before* the operation. Carries the source id and
  /// the source path — which is what a listener matches on, since a moved item's
  /// id can change (a rename or a cross-volume move rewrites it).
  final List<MediaEntity> removed;

  /// The items as they now exist at the destination.
  final List<MediaEntity> added;

  bool get isEmpty => removed.isEmpty && added.isEmpty;

  @override
  String toString() =>
      'MediaMutation(#$sequence, ${kind.name}, '
      '-${removed.length} +${added.length})';
}

/// Broadcasts completed file operations so that every live view model can update
/// in place.
///
/// This exists so a move, copy or delete never triggers a rescan: the operation
/// already knows exactly what changed, and re-reading the directory from disk to
/// rediscover it costs a spinner and throws away the user's search and tag
/// filter along the way.
///
/// Publishers must only publish **after** the operation and its cache
/// reconciliation have completed, so that a listener reading the database sees
/// the settled state.
///
/// Deliberately touches no other provider — not even to invalidate one.
/// `Ref.invalidate` *mounts* a provider that nobody is watching, so a bus that
/// reached out to its listeners would bring dormant view models to life just to
/// tell them about a change they have no one to show. Listeners subscribe here
/// themselves and refresh whatever they own.
class MediaMutationBus extends StateNotifier<MediaMutation?> {
  MediaMutationBus() : super(null);

  int _sequence = 0;

  void publishDeleted(List<MediaEntity> items) {
    _emit(
      MediaMutation(
        sequence: ++_sequence,
        kind: MediaMutationKind.deleted,
        removed: List.unmodifiable(items),
      ),
    );
  }

  /// Publishes a single move or copy. A move leaves its source directory; a copy
  /// leaves the source in place.
  void publishTransfer({
    required TransferMode mode,
    required MediaEntity source,
    required MediaEntity result,
  }) {
    publishTransferBatch(
      mode: mode,
      transfers: [(source: source, result: result)],
    );
  }

  void publishTransferBatch({
    required TransferMode mode,
    required List<({MediaEntity source, MediaEntity result})> transfers,
  }) {
    final isMove = mode == TransferMode.move;
    final added = <MediaEntity>[];
    final removed = <MediaEntity>[];

    for (final transfer in transfers) {
      if (isMove) {
        removed.add(transfer.source);
        added.add(transfer.result);
        continue;
      }

      // A copy that came back wearing its source's id means the reconciler hit
      // its "would overwrite the original" guard and wrote no row. Announcing it
      // would put a tile on screen that no record backs.
      if (transfer.result.id == transfer.source.id) {
        LoggingService.instance.warning(
          'Not announcing the copy of ${transfer.source.path}: it kept its '
          "source's id, so no record was written for it",
        );
        continue;
      }
      added.add(transfer.result);
    }

    _emit(
      MediaMutation(
        sequence: ++_sequence,
        kind: isMove ? MediaMutationKind.moved : MediaMutationKind.copied,
        removed: List.unmodifiable(removed),
        added: List.unmodifiable(added),
      ),
    );
  }

  void _emit(MediaMutation mutation) {
    if (mutation.isEmpty) {
      return;
    }
    state = mutation;
  }
}

/// Not auto-disposed: it has to outlive every screen, so that a mutation
/// published while one route is being torn down still reaches the routes behind
/// it.
final mediaMutationBusProvider =
    StateNotifierProvider<MediaMutationBus, MediaMutation?>(
      (ref) => MediaMutationBus(),
    );
