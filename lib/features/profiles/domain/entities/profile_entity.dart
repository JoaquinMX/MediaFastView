/// Domain entity representing a profile: a named, switchable scope over the
/// library.
///
/// A profile owns directories, tags, favorites and saved filters. Switching the
/// active profile re-scopes the whole app. App-wide settings (theme, playback,
/// grid columns) deliberately live outside a profile.
class ProfileEntity {
  const ProfileEntity({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// Position in the switcher. Also the tie-breaker the bootstrap uses to pick
  /// a profile when the stored active one is missing or stale.
  final int sortOrder;

  final DateTime createdAt;

  ProfileEntity copyWith({
    String? id,
    String? name,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ProfileEntity(id: $id, name: $name, sortOrder: $sortOrder)';
}
