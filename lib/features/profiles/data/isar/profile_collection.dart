import 'package:isar/isar.dart';

import '../../../../core/services/isar_id.dart';
import '../models/profile_model.dart';

part 'profile_collection.g.dart';

/// The Isar primary key for the profile identified by [profileId].
///
/// Shared with the data source's delete path, which must address exactly the key
/// the collection was stored under.
Id profileCollectionId(String profileId) => isarIdFromKey(profileId);

/// Isar collection representing a profile.
@collection
class ProfileCollection {
  ProfileCollection({
    required this.profileId,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
  });

  Id get id => profileCollectionId(profileId);
  set id(Id value) {}

  /// Stable profile identifier used throughout the app.
  @Index(unique: true, replace: true)
  String profileId;

  /// Deliberately not indexed. A `unique: true, replace: true` index on the name
  /// would make renaming a profile to an existing name silently delete that
  /// other profile's row. Uniqueness is enforced in the use cases instead, the
  /// same way `TagCollection` does it.
  String name;

  int sortOrder;

  DateTime createdAt;
}

extension ProfileCollectionMapper on ProfileCollection {
  ProfileModel toModel() {
    return ProfileModel(
      id: profileId,
      name: name,
      sortOrder: sortOrder,
      createdAt: createdAt,
    );
  }
}

extension ProfileModelIsarMapper on ProfileModel {
  ProfileCollection toCollection() {
    return ProfileCollection(
      profileId: id,
      name: name,
      sortOrder: sortOrder,
      createdAt: createdAt,
    );
  }
}
