import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/domain/repositories/media_repository.dart';
import '../../../media_library/domain/use_cases/get_media_use_case.dart';
import '../../../../core/services/logging_service.dart';

/// Use case that resolves and persists media needed by favorites features.
class FavoriteMediaUseCase {
  const FavoriteMediaUseCase(this._mediaRepository, this._getMediaUseCase);

  final MediaRepository _mediaRepository;
  final GetMediaUseCase _getMediaUseCase;

  /// Retrieves media entities for the given [favoriteIds], preferring cached
  /// entries and falling back to repository lookups when necessary.
  Future<List<MediaEntity>> resolveMediaForFavorites(List<String> favoriteIds) async {
    LoggingService.instance.info(
      'Loading media for ${favoriteIds.length} favorite IDs: $favoriteIds',
    );

    if (favoriteIds.isEmpty) {
      LoggingService.instance.info('No favorite IDs provided, returning empty');
      return const <MediaEntity>[];
    }

    final storedMedia = await _mediaRepository.getAllMedia();
    LoggingService.instance.info(
      'Found ${storedMedia.length} stored media items',
    );

    final storedMediaMap = {for (final media in storedMedia) media.id: media};
    final resolvedMedia = <MediaEntity>[];
    final missingIds = <String>[];

    for (final id in favoriteIds) {
      final stored = storedMediaMap[id];
      if (stored != null) {
        resolvedMedia.add(stored);
        LoggingService.instance.debug(
          'Successfully loaded cached media for ID $id: ${stored.name}, path: ${stored.path}',
        );
      } else {
        missingIds.add(id);
        LoggingService.instance.warning(
          'No cached media found for favorite ID $id, will attempt repository lookup',
        );
      }
    }

    if (missingIds.isNotEmpty) {
      LoggingService.instance.info(
        'Attempting to resolve ${missingIds.length} missing favorites via repository',
      );
      for (final id in missingIds) {
        final media = await _getMediaUseCase.byId(id);
        if (media != null) {
          resolvedMedia.add(media);
          LoggingService.instance.debug(
            'Resolved missing favorite $id via repository lookup',
          );
        } else {
          LoggingService.instance.warning(
            'Repository could not resolve favorite ID $id',
          );
        }
      }
    }

    LoggingService.instance.info(
      'Loaded ${resolvedMedia.length} valid media entities out of ${favoriteIds.length} favorites',
    );
    return resolvedMedia;
  }

  /// Persists [media] to the underlying repository for offline use.
  Future<void> persistMedia(MediaEntity media) {
    return _mediaRepository.upsertMedia([media]);
  }
}
