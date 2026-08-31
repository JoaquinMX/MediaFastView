/// Coverage of the visual perceptual-hash cache for the active profile.
class DuplicateLibraryCoverage {
  const DuplicateLibraryCoverage({
    required this.totalImages,
    required this.readyImages,
  });

  final int totalImages;
  final int readyImages;

  int get pendingImages => totalImages - readyImages;

  bool get isComplete => pendingImages == 0;
}
