import '../../../media_library/domain/entities/media_entity.dart';
import '../repositories/media_viewer_repository.dart';

/// Use case for navigating between media in full-screen view
class NavigateMediaUseCase {
  const NavigateMediaUseCase(this._repository);

  final MediaViewerRepository _repository;

  /// Get next media in the list
  Future<MediaEntity?> getNext(
    String currentMediaId,
    List<String> mediaIds,
  ) async {
    return _repository.getNextMedia(currentMediaId, mediaIds);
  }

  /// Get previous media in the list
  Future<MediaEntity?> getPrevious(
    String currentMediaId,
    List<String> mediaIds,
  ) async {
    return _repository.getPreviousMedia(currentMediaId, mediaIds);
  }
}
