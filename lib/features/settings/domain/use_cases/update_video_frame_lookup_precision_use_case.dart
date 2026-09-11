import '../../../../core/models/video_frame_lookup_precision.dart';
import '../repositories/settings_repository.dart';

/// Persists the precision tier used by image-to-video frame lookup.
class UpdateVideoFrameLookupPrecisionUseCase {
  const UpdateVideoFrameLookupPrecisionUseCase(this._repository);

  final SettingsRepository _repository;

  Future<void> call(VideoFrameLookupPrecision precision) {
    return _repository.saveVideoFrameLookupPrecision(precision);
  }
}
