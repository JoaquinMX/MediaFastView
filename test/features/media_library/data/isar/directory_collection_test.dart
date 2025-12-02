import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:media_fast_view/features/media_library/data/isar/directory_collection.dart';
import 'package:media_fast_view/shared/utils/directory_id_utils.dart';
import 'package:test/test.dart';

void main() {
  group('computeDirectoryCollectionId', () {
    test('produces distinct ids for different directory hashes', () {
      final firstDirectoryId = generateDirectoryId('/tmp/zVariados');
      final secondDirectoryId = generateDirectoryId('/tmp/zOnlyFotos');

      final firstIsarId = computeDirectoryCollectionId(firstDirectoryId);
      final secondIsarId = computeDirectoryCollectionId(secondDirectoryId);

      expect(firstIsarId, isNot(equals(secondIsarId)));
    });

    test('matches the first 64 bits of the SHA-256 hash', () {
      final directoryId = generateDirectoryId('/tmp/sample');
      final expected = int.parse(
        sha256.convert(utf8.encode(directoryId)).toString().substring(0, 16),
        radix: 16,
      );

      expect(computeDirectoryCollectionId(directoryId), expected);
    });
  });
}
