import '../repositories/media_repository.dart';

/// Forces a full re-read of the library from disk.
///
/// The library is normally scanned lazily, one folder at a time, as you browse
/// into it — so a folder you have not opened since files were added, changed, or
/// removed outside the app still shows the old cache (and is missing from the
/// Tags tab entirely). This walks every folder under every library root and
/// rescans it, merging tag assignments back onto whatever survived.
class RescanLibraryUseCase {
  const RescanLibraryUseCase(this._mediaRepository);

  final MediaRepository _mediaRepository;

  /// Returns the number of folders rescanned.
  Future<int> call({void Function(int done, int total)? onProgress}) {
    return _mediaRepository.rescanLibrary(onProgress: onProgress);
  }
}
