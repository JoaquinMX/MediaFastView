import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../shared/providers/media_mutation_bus.dart';
import '../../domain/entities/media_entity.dart';

/// Tracks preview-catalog revisions without rebuilding unrelated directories.
class DirectoryPreviewCatalogRevisions {
  const DirectoryPreviewCatalogRevisions({
    this.globalRevision = 0,
    this.pathRevisions = const <String, int>{},
  });

  final int globalRevision;
  final Map<String, int> pathRevisions;

  int revisionFor(String directoryPath) {
    return globalRevision + (pathRevisions[_normalizePath(directoryPath)] ?? 0);
  }

  DirectoryPreviewCatalogRevisions copyWith({
    int? globalRevision,
    Map<String, int>? pathRevisions,
  }) {
    return DirectoryPreviewCatalogRevisions(
      globalRevision: globalRevision ?? this.globalRevision,
      pathRevisions: pathRevisions ?? this.pathRevisions,
    );
  }
}

class _DirectoryPreviewCatalogRevisionNotifier
    extends StateNotifier<DirectoryPreviewCatalogRevisions> {
  _DirectoryPreviewCatalogRevisionNotifier()
    : super(const DirectoryPreviewCatalogRevisions());

  void invalidateDirectory(String directoryPath) {
    final normalizedPath = _normalizePath(directoryPath);
    final revisions = Map<String, int>.from(state.pathRevisions);
    revisions[normalizedPath] = (revisions[normalizedPath] ?? 0) + 1;
    state = state.copyWith(pathRevisions: Map.unmodifiable(revisions));
  }

  void invalidateAll() {
    state = state.copyWith(globalRevision: state.globalRevision + 1);
  }
}

/// The revisions read by directory-preview catalog families.
final directoryPreviewCatalogRevisionProvider =
    StateNotifierProvider<
      _DirectoryPreviewCatalogRevisionNotifier,
      DirectoryPreviewCatalogRevisions
    >((ref) => _DirectoryPreviewCatalogRevisionNotifier());

/// Selects the revision relevant to one directory path.
final directoryPreviewCatalogPathRevisionProvider = Provider.autoDispose
    .family<int, String>((ref, directoryPath) {
      return ref.watch(
        directoryPreviewCatalogRevisionProvider.select(
          (revisions) => revisions.revisionFor(directoryPath),
        ),
      );
    });

/// Refreshes directory preview catalogs after filesystem and cache changes.
///
/// Its media-mutation subscription is activated by each live catalog. A file
/// mutation only changes the revision for its direct parent, so open cards in
/// unrelated folders retain their resolved catalog.
class DirectoryPreviewCatalogInvalidator {
  DirectoryPreviewCatalogInvalidator(this._ref);

  final Ref _ref;
  bool _isDisposed = false;

  /// Refreshes every catalog for [directoryPath], regardless of bookmark.
  void invalidateDirectory(String directoryPath) {
    if (_isDisposed) {
      return;
    }
    _ref
        .read(directoryPreviewCatalogRevisionProvider.notifier)
        .invalidateDirectory(directoryPath);
  }

  /// Refreshes every live catalog, for example after clearing all thumbnails.
  void invalidateAll() {
    if (_isDisposed) {
      return;
    }
    _ref.read(directoryPreviewCatalogRevisionProvider.notifier).invalidateAll();
  }

  void dispose() {
    _isDisposed = true;
  }

  void invalidateForMutation(MediaMutation mutation) {
    final affectedDirectories = <String>{
      for (final media in <MediaEntity>[...mutation.removed, ...mutation.added])
        p.dirname(media.path),
    };
    for (final directoryPath in affectedDirectories) {
      invalidateDirectory(directoryPath);
    }
  }
}

/// Makes filesystem mutations refresh only catalogs whose direct children
/// changed. The provider remains small and has no UI ownership, so catalog
/// auto-disposal also tears down the subscription when no preview is visible.
final directoryPreviewCatalogInvalidatorProvider =
    Provider.autoDispose<DirectoryPreviewCatalogInvalidator>((ref) {
      final invalidator = DirectoryPreviewCatalogInvalidator(ref);
      ref.listen<MediaMutation?>(mediaMutationBusProvider, (_, mutation) {
        if (mutation != null) {
          invalidator.invalidateForMutation(mutation);
        }
      }, fireImmediately: false);
      ref.onDispose(invalidator.dispose);
      return invalidator;
    });

String _normalizePath(String value) => p.normalize(value);
