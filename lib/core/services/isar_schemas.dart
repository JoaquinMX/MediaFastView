import 'package:isar/isar.dart';

import '../../features/favorites/data/isar/favorite_collection.dart';
import '../../features/media_library/data/isar/directory_collection.dart';
import '../../features/media_library/data/isar/media_collection.dart';
import '../../features/tagging/data/isar/tag_collection.dart';

/// Aggregated list of Isar collection schemas used by the application.
const List<CollectionSchema<dynamic>> isarCollectionSchemas = <CollectionSchema<dynamic>>[
  DirectoryCollectionSchema,
  MediaCollectionSchema,
  TagCollectionSchema,
  FavoriteCollectionSchema,
];
