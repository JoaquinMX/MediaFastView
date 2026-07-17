import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/duplicate_providers.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../domain/entities/duplicate_group.dart';
import '../../domain/entities/duplicate_scan_progress.dart';
import '../../domain/entities/duplicate_sensitivity.dart';
import '../../domain/entities/keeper_strategy.dart';
import '../../domain/use_cases/dismiss_duplicate_group_use_case.dart';
import '../../domain/use_cases/load_duplicate_groups_use_case.dart';
import '../../domain/use_cases/scan_for_duplicates_use_case.dart';

/// The screen's state machine.
sealed class DuplicateScanState {
  const DuplicateScanState();
}

/// Reading already-cached results on entry, before any user action.
class DuplicateLoading extends DuplicateScanState {
  const DuplicateLoading();
}

/// The hashing pass is running.
class DuplicateScanning extends DuplicateScanState {
  const DuplicateScanning(this.progress);

  final DuplicateScanProgress progress;
}

/// Duplicate groups to review.
class DuplicateResults extends DuplicateScanState {
  const DuplicateResults({
    required this.groups,
    required this.selection,
    required this.sensitivity,
    required this.keeperStrategy,
  });

  final List<DuplicateGroup> groups;

  /// group signature -> media ids checked for deletion.
  final Map<String, Set<String>> selection;

  final DuplicateSensitivity sensitivity;
  final KeeperStrategy keeperStrategy;

  DuplicateResults copyWith({
    List<DuplicateGroup>? groups,
    Map<String, Set<String>>? selection,
    DuplicateSensitivity? sensitivity,
    KeeperStrategy? keeperStrategy,
  }) {
    return DuplicateResults(
      groups: groups ?? this.groups,
      selection: selection ?? this.selection,
      sensitivity: sensitivity ?? this.sensitivity,
      keeperStrategy: keeperStrategy ?? this.keeperStrategy,
    );
  }
}

/// No groups. [hasScanned] distinguishes "nothing found" from "not scanned yet".
class DuplicateEmpty extends DuplicateScanState {
  const DuplicateEmpty({required this.hasScanned});

  final bool hasScanned;
}

class DuplicateScanError extends DuplicateScanState {
  const DuplicateScanError(this.message);

  final String message;
}

/// Drives the Duplicate Management screen: runs the hashing pass, clusters the
/// results, and holds the per-group keeper/deletion choices.
class DuplicateScanViewModel extends StateNotifier<DuplicateScanState> {
  DuplicateScanViewModel({
    required ScanForDuplicatesUseCase scanUseCase,
    required LoadDuplicateGroupsUseCase loadUseCase,
    required DismissDuplicateGroupUseCase dismissUseCase,
  }) : _scanUseCase = scanUseCase,
       _loadUseCase = loadUseCase,
       _dismissUseCase = dismissUseCase,
       super(const DuplicateLoading()) {
    // Show anything already in the cache without forcing a scan first.
    unawaited(_loadGroups());
  }

  final ScanForDuplicatesUseCase _scanUseCase;
  final LoadDuplicateGroupsUseCase _loadUseCase;
  final DismissDuplicateGroupUseCase _dismissUseCase;

  DuplicateSensitivity _sensitivity = DuplicateSensitivity.balanced;
  KeeperStrategy _keeperStrategy = KeeperStrategy.highestResolution;
  bool _hasScanned = false;
  DuplicateScanCancellation? _cancellation;

  DuplicateSensitivity get sensitivity => _sensitivity;
  KeeperStrategy get keeperStrategy => _keeperStrategy;

  /// Runs the hashing pass, then clusters. Cancellable via [cancelScan].
  Future<void> scan() async {
    _cancellation = DuplicateScanCancellation();
    state = const DuplicateScanning(DuplicateScanProgress.initial());
    try {
      await for (final progress in _scanUseCase(cancellation: _cancellation)) {
        if (!mounted) return;
        state = DuplicateScanning(progress);
      }
    } catch (error) {
      if (!mounted) return;
      state = DuplicateScanError('Failed to scan library: $error');
      return;
    }
    // Cluster whatever was hashed — a cancelled run still banks partial work.
    await _loadGroups(markScanned: true);
  }

  void cancelScan() => _cancellation?.cancel();

  Future<void> setSensitivity(DuplicateSensitivity value) async {
    if (value == _sensitivity) return;
    _sensitivity = value;
    await _loadGroups();
  }

  Future<void> setKeeperStrategy(KeeperStrategy value) async {
    if (value == _keeperStrategy) return;
    _keeperStrategy = value;
    await _loadGroups();
  }

  Future<void> _loadGroups({bool markScanned = false}) async {
    try {
      final groups = await _loadUseCase(
        sensitivity: _sensitivity,
        keeperStrategy: _keeperStrategy,
      );
      if (!mounted) return;
      _hasScanned = _hasScanned || markScanned;
      if (groups.isEmpty) {
        state = DuplicateEmpty(hasScanned: _hasScanned);
        return;
      }
      state = DuplicateResults(
        groups: groups,
        selection: _defaultSelection(groups),
        sensitivity: _sensitivity,
        keeperStrategy: _keeperStrategy,
      );
    } catch (error) {
      if (!mounted) return;
      state = DuplicateScanError('Failed to load duplicates: $error');
    }
  }

  Map<String, Set<String>> _defaultSelection(List<DuplicateGroup> groups) {
    return {
      for (final group in groups)
        group.signature: group.removable
            .map((candidate) => candidate.id)
            .toSet(),
    };
  }

  /// Re-picks the keeper of one group; the deletion selection for that group
  /// resets to the new set of non-keepers.
  void setKeeper(String signature, String mediaId) {
    final results = state;
    if (results is! DuplicateResults) return;
    final groups = results.groups
        .map(
          (group) =>
              group.signature == signature ? group.withKeeper(mediaId) : group,
        )
        .toList(growable: false);
    final updated = groups.firstWhere((group) {
      // The signature is membership-based, so it is unchanged by a keeper swap.
      return group.signature == signature;
    });
    final selection = Map<String, Set<String>>.from(results.selection);
    selection[signature] = updated.removable
        .map((candidate) => candidate.id)
        .toSet();
    state = results.copyWith(groups: groups, selection: selection);
  }

  /// Checks/unchecks one copy for deletion. The keeper can never be selected.
  void toggleDeletion(String signature, String mediaId, bool selected) {
    final results = state;
    if (results is! DuplicateResults) return;
    final group = results.groups
        .where((group) => group.signature == signature)
        .firstOrNull;
    if (group == null || group.keeperId == mediaId) return;

    final selection = Map<String, Set<String>>.from(results.selection);
    final ids = Set<String>.from(selection[signature] ?? const <String>{});
    if (selected) {
      ids.add(mediaId);
    } else {
      ids.remove(mediaId);
    }
    selection[signature] = ids;
    state = results.copyWith(selection: selection);
  }

  Future<void> dismissGroup(DuplicateGroup group) async {
    await _dismissUseCase(group);
    if (!mounted) return;
    applyRemovedSignature(group.signature);
  }

  /// Removes a group by signature (after a dismissal).
  void applyRemovedSignature(String signature) {
    final results = state;
    if (results is! DuplicateResults) return;
    final groups = results.groups
        .where((group) => group.signature != signature)
        .toList(growable: false);
    _emitGroups(results, groups);
  }

  /// Prunes [removedIds] from every group after a delete/move — whether it
  /// happened here or on another screen (via the mutation bus). Groups that fall
  /// below two survivors disappear.
  void applyRemovedIds(Set<String> removedIds) {
    final results = state;
    if (results is! DuplicateResults || removedIds.isEmpty) return;

    final groups = <DuplicateGroup>[];
    final selection = <String, Set<String>>{};
    for (final group in results.groups) {
      final updated = group.withoutIds(removedIds, results.keeperStrategy);
      if (updated == null) continue;
      groups.add(updated);
      final removableIds = updated.removable
          .map((candidate) => candidate.id)
          .toSet();
      final previous = results.selection[group.signature] ?? const <String>{};
      selection[updated.signature] = previous
          .difference(removedIds)
          .intersection(removableIds);
    }
    _emitGroups(results, groups, selection: selection);
  }

  void _emitGroups(
    DuplicateResults previous,
    List<DuplicateGroup> groups, {
    Map<String, Set<String>>? selection,
  }) {
    if (groups.isEmpty) {
      state = const DuplicateEmpty(hasScanned: true);
      return;
    }
    state = previous.copyWith(
      groups: groups,
      selection: selection ?? previous.selection,
    );
  }

  /// The media items currently checked for deletion, across all groups.
  List<MediaEntity> selectedMedia() {
    final results = state;
    if (results is! DuplicateResults) return const [];
    final media = <MediaEntity>[];
    for (final group in results.groups) {
      final ids = results.selection[group.signature] ?? const <String>{};
      for (final candidate in group.candidates) {
        if (ids.contains(candidate.id)) {
          media.add(candidate.media);
        }
      }
    }
    return media;
  }

  int get selectedCount {
    final results = state;
    if (results is! DuplicateResults) return 0;
    return results.selection.values.fold(0, (sum, ids) => sum + ids.length);
  }

  int get selectedBytes {
    final results = state;
    if (results is! DuplicateResults) return 0;
    var bytes = 0;
    for (final group in results.groups) {
      final ids = results.selection[group.signature] ?? const <String>{};
      for (final candidate in group.candidates) {
        if (ids.contains(candidate.id)) {
          bytes += candidate.sizeBytes;
        }
      }
    }
    return bytes;
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    super.dispose();
  }
}

final duplicateScanViewModelProvider =
    StateNotifierProvider.autoDispose<
      DuplicateScanViewModel,
      DuplicateScanState
    >((ref) {
      return DuplicateScanViewModel(
        scanUseCase: ref.watch(scanForDuplicatesUseCaseProvider),
        loadUseCase: ref.watch(loadDuplicateGroupsUseCaseProvider),
        dismissUseCase: ref.watch(dismissDuplicateGroupUseCaseProvider),
      );
    });
