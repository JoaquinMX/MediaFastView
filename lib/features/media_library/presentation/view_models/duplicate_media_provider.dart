import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/repository_providers.dart';
import '../../domain/entities/media_entity.dart';
import '../models/duplicate_group.dart';

/// Provides suspected duplicate media groups keyed by lightweight signatures.
final duplicateMediaGroupsProvider =
    FutureProvider.autoDispose<List<DuplicateMediaGroup>>((ref) async {
  final mediaRepository = ref.watch(mediaRepositoryProvider);
  final directoryRepository = ref.watch(directoryRepositoryProvider);

  final mediaItems = await mediaRepository.getAllMedia();
  final directories = await directoryRepository.getDirectories();
  final directoryMap = {for (final directory in directories) directory.id: directory};

  final grouped = <_DuplicateKey, List<MediaEntity>>{};

  for (final media in mediaItems) {
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
      })
      .toList()
    ..sort(
      (a, b) => b.items.length.compareTo(a.items.length),
    );

  return groups;
});

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
