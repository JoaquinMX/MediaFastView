/// Domain entity representing a favorite media item.
class FavoriteEntity {
  const FavoriteEntity({required this.mediaId, required this.addedAt});

  final String mediaId;
  final DateTime addedAt;

  /// Creates a copy with updated fields.
  FavoriteEntity copyWith({String? mediaId, DateTime? addedAt}) {
    return FavoriteEntity(
      mediaId: mediaId ?? this.mediaId,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteEntity &&
          runtimeType == other.runtimeType &&
          mediaId == other.mediaId;

  @override
  int get hashCode => mediaId.hashCode;

  @override
  String toString() => 'FavoriteEntity(mediaId: $mediaId, addedAt: $addedAt)';
}
