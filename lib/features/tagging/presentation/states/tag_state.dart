import '../../domain/entities/tag_entity.dart';

/// Sealed class representing the different states of tag operations.
/// Uses Dart 3 sealed classes pattern for exhaustive state handling.
sealed class TagState {
  const TagState();
}

/// Loading state when fetching or processing tags.
class TagLoading extends TagState {
  const TagLoading();
}

/// Loaded state containing the list of tags.
class TagLoaded extends TagState {
  const TagLoaded(this.tags);

  final List<TagEntity> tags;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagLoaded &&
          runtimeType == other.runtimeType &&
          _listEquals(tags, other.tags);

  @override
  int get hashCode => tags.hashCode;

  bool _listEquals(List<TagEntity> a, List<TagEntity> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Error state when tag operations fail.
class TagError extends TagState {
  const TagError(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagError &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}

/// Empty state when no tags exist.
class TagEmpty extends TagState {
  const TagEmpty();
}
