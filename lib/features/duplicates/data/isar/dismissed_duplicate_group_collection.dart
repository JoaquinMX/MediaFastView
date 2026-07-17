import 'package:isar/isar.dart';

import '../../../../core/services/isar_id.dart';

part 'dismissed_duplicate_group_collection.g.dart';

/// The Isar primary key for a dismissed group [signature].
Id dismissedDuplicateGroupId(String signature) => isarIdFromKey(signature);

/// Remembers a group the user marked "not duplicates".
///
/// Keyed by the group's membership [signature] (sorted media ids). Because the
/// signature changes as soon as the set of clustered files changes, a dismissal
/// only suppresses the exact same grouping — add or remove a member and it
/// resurfaces for review.
@collection
class DismissedDuplicateGroupCollection {
  DismissedDuplicateGroupCollection({
    required this.signature,
    required this.dismissedAt,
  });

  Id get id => dismissedDuplicateGroupId(signature);
  set id(Id value) {}

  @Index(unique: true, replace: true)
  String signature;

  DateTime dismissedAt;
}
