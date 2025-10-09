import 'package:isar/isar.dart';

part 'tag_record.g.dart';

/// Persistent representation of a tag assigned to media or directories.
@collection
class TagRecord {
  TagRecord({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index(caseSensitive: false)
  late String name;

  late int color;

  late DateTime createdAt;
}
