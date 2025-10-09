import 'package:isar/isar.dart';

part 'favorite_record.g.dart';

/// Persistent representation of a favorite media item.
@collection
class FavoriteRecord {
  FavoriteRecord({
    required this.mediaId,
    required this.addedAt,
  });

  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String mediaId;

  late DateTime addedAt;
}
