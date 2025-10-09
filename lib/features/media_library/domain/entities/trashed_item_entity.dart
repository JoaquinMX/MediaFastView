class TrashedItemEntity {
  const TrashedItemEntity({
    required this.id,
    required this.originalPath,
    required this.trashedPath,
    required this.trashedAt,
    this.bookmarkData,
  });

  final String id;
  final String originalPath;
  final String trashedPath;
  final DateTime trashedAt;
  final String? bookmarkData;

  TrashedItemEntity copyWith({
    String? id,
    String? originalPath,
    String? trashedPath,
    DateTime? trashedAt,
    String? bookmarkData,
  }) {
    return TrashedItemEntity(
      id: id ?? this.id,
      originalPath: originalPath ?? this.originalPath,
      trashedPath: trashedPath ?? this.trashedPath,
      trashedAt: trashedAt ?? this.trashedAt,
      bookmarkData: bookmarkData ?? this.bookmarkData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalPath': originalPath,
      'trashedPath': trashedPath,
      'trashedAt': trashedAt.toIso8601String(),
      'bookmarkData': bookmarkData,
    };
  }

  factory TrashedItemEntity.fromJson(Map<String, dynamic> json) {
    return TrashedItemEntity(
      id: json['id'] as String,
      originalPath: json['originalPath'] as String,
      trashedPath: json['trashedPath'] as String,
      trashedAt: DateTime.parse(json['trashedAt'] as String),
      bookmarkData: json['bookmarkData'] as String?,
    );
  }
}
