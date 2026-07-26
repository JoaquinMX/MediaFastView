import 'package:path/path.dart' as p;

import '../entities/directory_cover_entity.dart';
import '../entities/media_entity.dart';
import '../repositories/directory_cover_repository.dart';

/// Validates and persists a direct-child image or video as a directory cover.
class SetDirectoryCoverUseCase {
  const SetDirectoryCoverUseCase(this._repository);

  final DirectoryCoverRepository _repository;

  Future<void> call({
    required String directoryPath,
    required MediaEntity media,
  }) async {
    if (media.type != MediaType.image && media.type != MediaType.video) {
      throw ArgumentError.value(
        media.type,
        'media',
        'A directory cover must be an image or video.',
      );
    }

    final normalizedDirectory = p.normalize(directoryPath);
    final mediaParent = p.normalize(p.dirname(media.path));
    if (normalizedDirectory.toLowerCase() != mediaParent.toLowerCase()) {
      throw ArgumentError.value(
        media.path,
        'media',
        'A directory cover must be a direct child of the directory.',
      );
    }

    await _repository.saveCover(
      DirectoryCoverEntity.media(
        directoryPath: normalizedDirectory,
        sourceFileName: p.basename(media.path),
        mediaType: media.type,
        updatedAt: DateTime.now(),
      ),
    );
  }
}
