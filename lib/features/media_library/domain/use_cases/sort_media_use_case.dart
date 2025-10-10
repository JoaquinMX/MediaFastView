import '../entities/media_entity.dart';
import '../value_objects/sort_option.dart';

/// Use case responsible for sorting media items using the provided option.
class SortMediaUseCase {
  const SortMediaUseCase();

  /// Returns a new list of media items sorted according to [option].
  List<MediaEntity> call(
    List<MediaEntity> media,
    MediaSortOption option,
  ) {
    final sortedMedia = List<MediaEntity>.from(media);
    sortedMedia.sort((a, b) {
      final comparison = switch (option.field) {
        MediaSortField.name => a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            ),
        MediaSortField.lastModified => a.lastModified.compareTo(
              b.lastModified,
            ),
        MediaSortField.size => a.size.compareTo(b.size),
      };

      return option.order == SortOrder.ascending ? comparison : -comparison;
    });

    return sortedMedia;
  }
}
