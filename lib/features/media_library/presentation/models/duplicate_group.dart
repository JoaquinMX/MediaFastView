import '../../domain/entities/directory_entity.dart';
import '../../domain/entities/media_entity.dart';

/// Represents a group of media items that appear to be duplicates.
class DuplicateMediaGroup {
  const DuplicateMediaGroup({
    required this.signature,
    required this.size,
    required this.type,
    required this.items,
  });

  final String signature;
  final int size;
  final MediaType type;
  final List<DuplicateMediaItem> items;
}

/// Descriptor for a single media item within a duplicate group.
class DuplicateMediaItem {
  const DuplicateMediaItem({
    required this.media,
    required this.directory,
  });

  final MediaEntity media;
  final DirectoryEntity? directory;
}
