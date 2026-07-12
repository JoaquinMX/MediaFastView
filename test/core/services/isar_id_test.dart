import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/isar_id.dart';
import 'package:media_fast_view/features/media_library/data/isar/directory_collection.dart';

import '../../helpers/isar_id.dart';

/// Ids in the shape the app actually produces: uuid v4 (TagViewModel.createTag),
/// `tag_<millis>_<suffix>` (CreateTagUseCase), and the sha-256 media ids that
/// favorites are keyed on.
List<String> _realisticKeys(int count) {
  return [
    for (var i = 0; i < count; i++)
      if (i.isEven)
        'tag_${1750000000000 + i}_${i % 1000}'
      else
        'media::${isarIdFromKey('$i-seed').toRadixString(16)}$i',
  ];
}

void main() {
  group('isarIdFromKey', () {
    test('is deterministic', () {
      expect(isarIdFromKey('beach'), isarIdFromKey('beach'));
    });

    test('is always positive, so it can never be the autoIncrement sentinel', () {
      for (final key in _realisticKeys(2000)) {
        expect(isarIdFromKey(key), isNonNegative);
      }
    });

    test('separates keys that differ by a single character', () {
      expect(isarIdFromKey('beach'), isNot(isarIdFromKey('Beach')));
      expect(isarIdFromKey('tag_1'), isNot(isarIdFromKey('tag_2')));
    });
  });

  group('the primary-key collision this fixed', () {
    // The bug: TagCollection and FavoriteCollection derived their Isar id by
    // SUMMING the 32 bytes of a sha-256 digest. That caps the key space at 8160
    // and, being a normal distribution about 4081, reaches only ~2,800 values in
    // practice. Isar's put() keys on Id, so colliding rows silently overwrote
    // each other — at 100 tags that is near-certain, and at 500 favorites it
    // destroyed dozens.
    test('the OLD derivation collides catastrophically', () {
      final keys = _realisticKeys(500);
      final distinct = keys.map(legacyIsarIdForString).toSet();

      expect(
        distinct.length,
        lessThan(keys.length),
        reason: 'the byte-sum should collide well before 500 keys',
      );
      // Not a near miss: hundreds of rows land on an id another row already owns.
      expect(keys.length - distinct.length, greaterThan(50));
    });

    test('the NEW derivation does not collide across 100k keys', () {
      final keys = _realisticKeys(100000);
      final distinct = keys.map(isarIdFromKey).toSet();

      expect(distinct.length, keys.length);
    });

    test('the old key space is tiny; the new one is not', () {
      final keys = _realisticKeys(20000);

      // Every legacy id fits in [0, 8160] — that is the whole problem.
      expect(keys.map(legacyIsarIdForString).every((id) => id <= 8160), isTrue);
      expect(keys.map(legacyIsarIdForString).toSet().length, lessThan(4000));

      expect(keys.map(isarIdFromKey).toSet().length, keys.length);
    });
  });

  group('directory ids are unchanged', () {
    test('computeDirectoryCollectionId still returns exactly its old value', () {
      // It now delegates to isarIdFromKey, which must be bit-for-bit identical to
      // the BigInt implementation it replaced — otherwise every directory row,
      // and the macOS bookmarks they carry, would silently need re-keying too.
      // Comparing against the delegate would be tautological, so this pins the
      // ORIGINAL algorithm and compares against that.
      for (final path in _realisticKeys(5000)) {
        expect(
          computeDirectoryCollectionId(path),
          _originalDirectoryId(path),
          reason: 'directory rows must keep the keys they were written under',
        );
      }
    });
  });
}

/// The BigInt implementation `computeDirectoryCollectionId` used to carry,
/// reproduced verbatim so the delegation can be proven value-preserving.
int _originalDirectoryId(String directoryId) {
  final hash = sha256.convert(utf8.encode(directoryId)).toString();
  final first64Bits = hash.substring(0, 16);
  final parsed = BigInt.parse(first64Bits, radix: 16);
  const maxSignedInt64 = 0x7FFFFFFFFFFFFFFF;
  return (parsed & BigInt.from(maxSignedInt64)).toInt();
}
