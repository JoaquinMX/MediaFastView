import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/repository_providers.dart';
import '../../domain/entities/media_entity.dart';
import '../models/duplicate_group.dart';

/// Tracks the state of duplicate detection scans running in the background.
class DuplicateMediaScanState {
  const DuplicateMediaScanState({
    required this.groups,
    required this.isScanning,
    required this.scannedCount,
    required this.totalCount,
    this.truncated = false,
  });

  const DuplicateMediaScanState.initial()
      : groups = const [],
        isScanning = true,
        scannedCount = 0,
        totalCount = 0,
        truncated = false;

  final List<DuplicateMediaGroup> groups;
  final bool isScanning;
  final int scannedCount;
  final int totalCount;
  final bool truncated;

  double? get progress => totalCount == 0
      ? null
      : (scannedCount / totalCount).clamp(0, 1).toDouble();

  DuplicateMediaScanState copyWith({
    List<DuplicateMediaGroup>? groups,
    bool? isScanning,
    int? scannedCount,
    int? totalCount,
    bool? truncated,
  }) {
    return DuplicateMediaScanState(
      groups: groups ?? this.groups,
      isScanning: isScanning ?? this.isScanning,
      scannedCount: scannedCount ?? this.scannedCount,
      totalCount: totalCount ?? this.totalCount,
      truncated: truncated ?? this.truncated,
    );
  }
}

/// Provides suspected duplicate media groups while running scans off the UI thread.
final duplicateMediaScanProvider = AutoDisposeNotifierProvider<
    DuplicateMediaScanner, DuplicateMediaScanState>(
  DuplicateMediaScanner.new,
);

class DuplicateMediaScanner extends AutoDisposeNotifier<DuplicateMediaScanState> {
  static const int _maxItemsToProcess = 2000;
  static const int _yieldEvery = 200;

  bool _hasScheduledScan = false;

  @override
  DuplicateMediaScanState build() {
    // Kick off scan without blocking build.
    if (!_hasScheduledScan) {
      _hasScheduledScan = true;
      unawaited(_refreshScan());
    }
    return const DuplicateMediaScanState.initial();
  }

  Future<void> refresh() async {
    await _refreshScan();
  }

  Future<void> _refreshScan() async {
    final mediaRepository = ref.read(mediaRepositoryProvider);
    final directoryRepository = ref.read(directoryRepositoryProvider);

    state = state.copyWith(
      isScanning: true,
      scannedCount: 0,
      totalCount: 0,
    );

    final mediaItems = await mediaRepository.getAllMedia();
    final directories = await directoryRepository.getDirectories();
    final directoryMap = {
      for (final directory in directories) directory.id: directory
    };

    final total = mediaItems.length > _maxItemsToProcess
        ? _maxItemsToProcess
        : mediaItems.length;

    final grouped = <_DuplicateKey, List<MediaEntity>>{};

    for (var index = 0; index < total; index++) {
      final media = mediaItems[index];
      final signature = media.signature;

      if (signature == null || signature.isEmpty) {
        continue;
      }
      if (media.type == MediaType.directory) {
        continue;
      }

      final key = _DuplicateKey(
        signature: signature,
        size: media.size,
        type: media.type,
      );
      grouped.putIfAbsent(key, () => <MediaEntity>[]).add(media);

      if ((index + 1) % _yieldEvery == 0) {
        // Periodically yield to keep the UI responsive while scanning.
        await Future<void>.delayed(Duration.zero);
        state = state.copyWith(
          scannedCount: index + 1,
          totalCount: total,
        );
      }
    }

    final groups = grouped.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) {
      final sortedItems = entry.value
        ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
      final mappedItems = sortedItems
          .map(
            (media) => DuplicateMediaItem(
              media: media,
              directory: directoryMap[media.directoryId],
            ),
          )
          .toList(growable: false);
      return DuplicateMediaGroup(
        signature: entry.key.signature,
        size: entry.key.size,
        type: entry.key.type,
        items: mappedItems,
      );
    }).toList()
      ..sort(
        (a, b) => b.items.length.compareTo(a.items.length),
      );

    state = state.copyWith(
      groups: groups,
      isScanning: false,
      scannedCount: total,
      totalCount: total,
      truncated: mediaItems.length > _maxItemsToProcess,
    );
  }
}

class _DuplicateKey {
  const _DuplicateKey({
    required this.signature,
    required this.size,
    required this.type,
  });

  final String signature;
  final int size;
  final MediaType type;

  @override
  bool operator ==(Object other) {
    return other is _DuplicateKey &&
        other.signature == signature &&
        other.size == size &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(signature, size, type);
}
