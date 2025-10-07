/// Domain entity representing a tag.
class TagEntity {
  const TagEntity({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int color;
  final DateTime createdAt;

  /// Creates a copy with updated fields.
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagEntity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TagEntity(id: $id, name: $name, color: $color, createdAt: $createdAt)';
}
