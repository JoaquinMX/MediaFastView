import 'package:isar/isar.dart';

import '../../../../core/services/isar_id.dart';

part 'image_lookup_history_collection.g.dart';

/// The Isar primary key for a saved lookup session.
Id imageLookupHistoryCollectionId(String sessionId) =>
    isarIdFromKey('image_lookup::$sessionId');

/// A persisted snapshot of one completed image-lookup batch.
@collection
class ImageLookupHistoryCollection {
  ImageLookupHistoryCollection({
    required this.sessionId,
    required this.profileId,
    required this.createdAt,
    required this.payloadJson,
  });

  Id get id => imageLookupHistoryCollectionId(sessionId);
  set id(Id value) {}

  @Index(unique: true, replace: true)
  String sessionId;

  @Index(type: IndexType.hash)
  String profileId;

  DateTime createdAt;

  String payloadJson;
}
