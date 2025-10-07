import '../../../media_library/domain/entities/media_entity.dart';

/// Use case for starting a slideshow with favorite media items.
class StartSlideshowUseCase {
  const StartSlideshowUseCase();

  /// Executes the use case to prepare media for slideshow.
  /// In a real implementation, this might filter/sort media or prepare resources.
  Future<List<MediaEntity>> execute(List<MediaEntity> favorites) async {
    // For now, just return the favorites as-is
    // In the future, this could include sorting by date, filtering by type, etc.
    return favorites;
  }
}
