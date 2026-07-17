import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/duplicates/data/services/duplicate_clusterer.dart';

import '../duplicate_test_helpers.dart';

void main() {
  const clusterer = DuplicateClusterer();

  Set<String> idsOf(List candidates) =>
      candidates.map((c) => c.id as String).toSet();

  group('DuplicateClusterer', () {
    test('groups hashes within the threshold', () {
      final groups = clusterer.cluster([
        buildCandidate('a', 0),
        buildCandidate('b', 3), // 2 bits from a
      ], 8);
      expect(groups, hasLength(1));
      expect(idsOf(groups.single), {'a', 'b'});
    });

    test('drops singletons and keeps distant items out', () {
      final groups = clusterer.cluster([
        buildCandidate('a', 0),
        buildCandidate('b', 0),
        buildCandidate('c', 0xFFFF), // 16 bits away
      ], 8);
      expect(groups, hasLength(1));
      expect(idsOf(groups.single), {'a', 'b'});
    });

    test('links transitively through a shared neighbour', () {
      // a~b (2), b~c (2), but a~c (4). At threshold 3 the chain still unites all.
      final groups = clusterer.cluster([
        buildCandidate('a', 0), // 000000
        buildCandidate('b', 3), // 000011
        buildCandidate('c', 27), // 011011
      ], 3);
      expect(groups, hasLength(1));
      expect(idsOf(groups.single), {'a', 'b', 'c'});
    });

    test('threshold 0 groups only identical hashes', () {
      final groups = clusterer.cluster([
        buildCandidate('a', 0),
        buildCandidate('b', 0),
        buildCandidate('c', 1),
      ], 0);
      expect(groups, hasLength(1));
      expect(idsOf(groups.single), {'a', 'b'});
    });

    test('returns nothing for fewer than two candidates', () {
      expect(clusterer.cluster([buildCandidate('a', 0)], 8), isEmpty);
      expect(clusterer.cluster([], 8), isEmpty);
    });

    test('separates two independent clusters', () {
      final groups = clusterer.cluster([
        buildCandidate('a', 0),
        buildCandidate('b', 1),
        buildCandidate('x', 0xFFFF),
        buildCandidate('y', 0xFFFE), // 1 bit from x
      ], 4);
      expect(groups, hasLength(2));
      // Sets compare by identity, so normalise to sorted lists before matching.
      final grouped = groups.map((g) => idsOf(g).toList()..sort()).toList();
      expect(
        grouped,
        containsAll([
          ['a', 'b'],
          ['x', 'y'],
        ]),
      );
    });
  });
}
