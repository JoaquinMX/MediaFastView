import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/repository_providers.dart';
import '../../domain/entities/media_entity.dart';
import 'directory_cover_providers.dart';
import 'directory_preview_catalog_invalidator.dart';

/// Performs directory-cover mutations and refreshes every affected preview.
class DirectoryCoverController extends StateNotifier<AsyncValue<void>> {
  DirectoryCoverController(this._ref, this._directoryPath)
    : super(const AsyncData<void>(null));

  final Ref _ref;
  final String _directoryPath;

  Future<void> setCover(MediaEntity media) async {
    return setCovers(<MediaEntity>[media]);
  }

  Future<void> setCovers(List<MediaEntity> images) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(() async {
      await _ref.read(setDirectoryCoverUseCaseProvider)(
        directoryPath: _directoryPath,
        images: images,
      );
      _invalidatePreviews();
    });
  }

  Future<void> setNoCover() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(() async {
      await _ref.read(setDirectoryNoCoverUseCaseProvider)(_directoryPath);
      _invalidatePreviews();
    });
  }

  Future<void> resetCover() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(() async {
      await _ref.read(resetDirectoryCoverUseCaseProvider)(_directoryPath);
      _invalidatePreviews();
    });
  }

  /// Removes selections confirmed missing while retaining any valid images.
  Future<void> reconcileMissingSelections(
    List<String> missingSourceFileNames,
  ) async {
    try {
      await _ref.read(reconcileDirectoryCoverUseCaseProvider)(
        directoryPath: _directoryPath,
        missingSourceFileNames: missingSourceFileNames,
      );
      _invalidatePreviews();
    } catch (_) {
      // The automatic fallback is already visible. A later read can retry.
    }
  }

  void _invalidatePreviews() {
    _ref.invalidate(directoryCoverProvider(_directoryPath));
    _ref
        .read(directoryPreviewCatalogInvalidatorProvider)
        .invalidateDirectory(_directoryPath);
  }
}

final directoryCoverControllerProvider = StateNotifierProvider.autoDispose
    .family<DirectoryCoverController, AsyncValue<void>, String>(
      DirectoryCoverController.new,
    );
