import 'package:path/path.dart' as p;

import '../../../../core/utils/file_utils.dart';
import '../entities/directory_cover_entity.dart';
import '../entities/media_entity.dart';
import '../repositories/directory_cover_repository.dart';

/// Validates and persists one to four direct-child images as a directory cover.
class SetDirectoryCoverUseCase {
  const SetDirectoryCoverUseCase(this._repository);

  final DirectoryCoverRepository _repository;

  Future<void> call({
    required String directoryPath,
    required List<MediaEntity> images,
  }) async {
    if (images.isEmpty ||
        images.length > DirectoryCoverEntity.maximumSelectionCount) {
      throw ArgumentError.value(
        images.length,
        'images',
        'A directory cover requires one to four images.',
      );
    }

    final normalizedDirectory = p.normalize(directoryPath);
    final selectedNames = <String>{};
    for (final image in images) {
      if (image.type != MediaType.image) {
        throw ArgumentError.value(
          image.type,
          'images',
          'A directory cover selection must be an image.',
        );
      }
      final mediaParent = p.normalize(p.dirname(image.path));
      final fileName = p.basename(image.path);
      if (normalizedDirectory.toLowerCase() != mediaParent.toLowerCase()) {
        throw ArgumentError.value(
          image.path,
          'images',
          'A directory cover must be a direct child of the directory.',
        );
      }
      if (isExcludedMediaFileName(fileName)) {
        throw ArgumentError.value(
          image.path,
          'images',
          'System metadata cannot be used as a directory cover.',
        );
      }
      if (!selectedNames.add(fileName.toLowerCase())) {
        throw ArgumentError.value(
          image.path,
          'images',
          'A directory cover cannot select the same image twice.',
        );
      }
    }

    await _repository.saveCover(
      DirectoryCoverEntity.images(
        directoryPath: normalizedDirectory,
        sourceFileNames: images
            .map((image) => p.basename(image.path))
            .toList(growable: false),
        updatedAt: DateTime.now(),
      ),
    );
  }
}
