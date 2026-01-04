import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/media_library/data/data_sources/local_directory_data_source.dart';
import '../../features/media_library/domain/entities/directory_entity.dart';
import 'repository_providers.dart';

/// Streams directory scan progress and results for duplicate media detection flows.
final duplicateMediaScanProvider = StreamProvider.autoDispose
    .family<DirectoryScanProgress, DirectoryEntity>((ref, rootDirectory) {
  final controller = StreamController<DirectoryScanProgress>();
  final cancellationToken = DirectoryScanCancellationToken();

  ref.onDispose(() {
    cancellationToken.cancel();
    controller.close();
  });

  unawaited(() async {
    try {
      await ref.read(localDirectoryDataSourceProvider).scanDirectoriesWithMedia(
            rootDirectory,
            cancellationToken: cancellationToken,
            onProgress: controller.add,
          );
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
    } finally {
      await controller.close();
    }
  }());

  return controller.stream;
});
