import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart';
import 'package:media_fast_view/core/services/isar_id.dart';

/// The id an Isar collection computes for a given key.
///
/// Delegates to production rather than restating the maths, so the in-memory
/// fakes key their rows exactly as the real collections do.
Id isarIdForString(String value) => isarIdFromKey(value);

/// The id the tag and favorite collections used to compute, before the fix.
///
/// Summing the digest bytes caps the key space at 8160 and, being normally
/// distributed, reaches only ~2,800 values in practice — so rows silently
/// overwrote one another. Kept only so tests can seed a store in the legacy
/// state and prove the migration rescues it.
Id legacyIsarIdForString(String value) {
  final hash = sha256.convert(utf8.encode(value)).bytes;
  return hash.fold<int>(0, (previousValue, element) => previousValue + element);
}
