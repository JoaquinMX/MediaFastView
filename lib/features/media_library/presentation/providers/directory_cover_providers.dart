import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/providers/active_profile_provider.dart';
import '../../domain/entities/directory_cover_entity.dart';
import '../../domain/entities/media_entity.dart';

/// Loads the active profile's cover override for [directoryPath].
final directoryCoverProvider = FutureProvider.autoDispose
    .family<DirectoryCoverEntity?, String>((ref, directoryPath) {
      ref.watch(activeProfileIdProvider);
      ref.watch(directoryCoverRevisionProvider);
      return ref
          .watch(directoryCoverRepositoryProvider)
          .getCover(directoryPath);
    });

class DirectoryCoverCandidatesQuery {
  const DirectoryCoverCandidatesQuery({
    required this.directoryPath,
    this.bookmarkData,
  });

  final String directoryPath;
  final String? bookmarkData;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DirectoryCoverCandidatesQuery &&
            directoryPath == other.directoryPath &&
            bookmarkData == other.bookmarkData;
  }

  @override
  int get hashCode => Object.hash(directoryPath, bookmarkData);
}

/// Loads direct-child image and video choices for the cover picker.
final directoryCoverCandidatesProvider = FutureProvider.autoDispose
    .family<List<MediaEntity>, DirectoryCoverCandidatesQuery>((
      ref,
      query,
    ) async {
      final media = await ref
          .watch(getMediaUseCaseProvider)
          .forDirectoryPath(
            query.directoryPath,
            bookmarkData: query.bookmarkData,
          );
      return media
          .where(
            (item) =>
                item.type == MediaType.image || item.type == MediaType.video,
          )
          .toList(growable: false);
    });
