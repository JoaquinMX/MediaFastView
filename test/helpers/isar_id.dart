import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart';
import 'package:media_fast_view/features/tagging/data/isar/tag_collection.dart';

/// Mimics the hashing logic used by Isar collection id getters.
Id isarIdForString(String value) {
  final hash = sha256.convert(utf8.encode(value)).bytes;
  return hash.fold<int>(0, (previousValue, element) => previousValue + element);
}

/// Mirrors the collision-resistant ID mapping used for tags.
Id tagIdForString(String tagId) {
  return computeTagCollectionId(tagId);
}

/// Helper for cleaning up legacy tag records persisted with the previous hash.
Id legacyTagIdForString(String tagId) {
  return computeLegacyTagCollectionId(tagId);
}
