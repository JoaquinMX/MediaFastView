import 'package:isar/isar.dart';

import '../../features/duplicates/data/isar/dismissed_duplicate_group_collection.dart';
import '../../features/duplicates/data/isar/perceptual_hash_collection.dart';
import '../../features/favorites/data/isar/favorite_collection.dart';
import '../../features/media_library/data/isar/directory_collection.dart';
import '../../features/media_library/data/isar/media_collection.dart';
import '../../features/profiles/data/isar/profile_collection.dart';
import '../../features/tagging/data/isar/saved_filter_collection.dart';
import '../../features/tagging/data/isar/tag_collection.dart';

/// Aggregated list of Isar collection schemas used by the application.
///
/// Appending a new collection needs no migration — Isar creates the empty
/// collection on next open. Only re-keying or reshaping an existing collection
/// does (see [runIsarMigrations]).
const List<CollectionSchema<dynamic>> isarCollectionSchemas = <CollectionSchema<dynamic>>[
  DirectoryCollectionSchema,
  MediaCollectionSchema,
  TagCollectionSchema,
  FavoriteCollectionSchema,
  SavedFilterCollectionSchema,
  ProfileCollectionSchema,
  PerceptualHashCollectionSchema,
  DismissedDuplicateGroupCollectionSchema,
];
