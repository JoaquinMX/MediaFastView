import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart';

/// Derives a stable Isar primary key from an arbitrary string [key].
///
/// Takes the first 64 bits of the SHA-256 digest and clears the sign bit, which
/// leaves 63 bits of entropy, always positive, and never equal to Isar's
/// `autoIncrement` sentinel.
///
/// **Never sum the digest bytes.** `TagCollection` and `FavoriteCollection` used
/// to derive their ids as `sha256(key).bytes.fold(0, (a, b) => a + b)`. A sum of
/// 32 bytes cannot exceed 8160, and is normally distributed about 4081, so only
/// ~2,800 distinct keys are reachable in practice. Isar's `put()` keys on `Id`,
/// so colliding rows silently overwrite one another — around 50 tags that is a
/// coin flip, and at 500 favourites it destroys dozens of them. See
/// `test/core/services/isar_id_test.dart`, which pins the difference.
Id isarIdFromKey(String key) {
  final digest = sha256.convert(utf8.encode(key)).bytes;

  var id = 0;
  for (final byte in digest.take(8)) {
    id = (id << 8) | byte;
  }

  // Clear the sign bit rather than letting the top byte make the id negative.
  return id & 0x7FFFFFFFFFFFFFFF;
}
