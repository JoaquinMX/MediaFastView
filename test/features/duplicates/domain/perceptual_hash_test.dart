import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/perceptual_hash.dart';

void main() {
  group('hammingDistance', () {
    test('is zero for identical hashes', () {
      expect(hammingDistance(0, 0), 0);
      expect(hammingDistance(123456789, 123456789), 0);
      expect(hammingDistance(-1, -1), 0);
    });

    test('counts single-bit differences', () {
      expect(hammingDistance(0, 1), 1);
      expect(hammingDistance(0, 3), 2);
      expect(hammingDistance(0, 7), 3);
    });

    test('counts every bit when all differ', () {
      // -1 is all 64 bits set in two's complement.
      expect(hammingDistance(0, -1), 64);
    });

    test('counts the sign bit like any other', () {
      // 1 << 63 is the most-significant (sign) bit only.
      expect(hammingDistance(0, 1 << 63), 1);
      expect(hammingDistance(-1, (1 << 63)), 63);
    });

    test('is symmetric', () {
      expect(hammingDistance(42, 99), hammingDistance(99, 42));
    });
  });

  group('perceptualFingerprint', () {
    test('combines size and modified millis', () {
      final fingerprint = perceptualFingerprint(
        size: 2048,
        lastModified: DateTime.fromMillisecondsSinceEpoch(5000),
      );
      expect(fingerprint, '2048_5000');
    });

    test('changes when size or mtime changes', () {
      final base = perceptualFingerprint(
        size: 10,
        lastModified: DateTime.fromMillisecondsSinceEpoch(1),
      );
      final biggerFile = perceptualFingerprint(
        size: 11,
        lastModified: DateTime.fromMillisecondsSinceEpoch(1),
      );
      final touched = perceptualFingerprint(
        size: 10,
        lastModified: DateTime.fromMillisecondsSinceEpoch(2),
      );
      expect(base, isNot(biggerFile));
      expect(base, isNot(touched));
    });
  });
}
