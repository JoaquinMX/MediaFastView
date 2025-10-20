/// Domain entity representing a tag in the media library.
class TagEntity {
  const TagEntity({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  /// Unique identifier of the tag.
  final String id;

  /// Display name of the tag.
  final String name;

  /// Packed ARGB color value associated with the tag.
  final int color;

  /// Timestamp capturing when the tag was created.
  final DateTime createdAt;

  /// Returns a copy of this entity with any provided fields replaced.
  TagEntity copyWith({
    String? id,
    String? name,
    int? color,
    DateTime? createdAt,
  }) {
    return TagEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TagEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TagEntity(id: $id, name: $name, color: $color, createdAt: $createdAt)';
}
