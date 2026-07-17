import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_group.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/keeper_strategy.dart';

import '../duplicate_test_helpers.dart';

void main() {
  group('KeeperStrategy.selectKeeperId', () {
    test('highestResolution picks the largest pixel count', () {
      final keeper = KeeperStrategy.highestResolution.selectKeeperId([
        buildCandidate('small', 0, width: 100, height: 100),
        buildCandidate('big', 0, width: 400, height: 300),
        buildCandidate('mid', 0, width: 200, height: 200),
      ]);
      expect(keeper, 'big');
    });

    test('largestFile picks the biggest byte size', () {
      final keeper = KeeperStrategy.largestFile.selectKeeperId([
        buildCandidate('a', 0, size: 1000),
        buildCandidate('b', 0, size: 5000),
        buildCandidate('c', 0, size: 2000),
      ]);
      expect(keeper, 'b');
    });

    test('newest picks the most recently modified', () {
      final keeper = KeeperStrategy.newest.selectKeeperId([
        buildCandidate('old', 0, modified: DateTime(2019)),
        buildCandidate('new', 0, modified: DateTime(2023)),
        buildCandidate('mid', 0, modified: DateTime(2021)),
      ]);
      expect(keeper, 'new');
    });

    test('breaks resolution ties by file size', () {
      final keeper = KeeperStrategy.highestResolution.selectKeeperId([
        buildCandidate('a', 0, width: 200, height: 200, size: 1000),
        buildCandidate('b', 0, width: 200, height: 200, size: 3000),
      ]);
      expect(keeper, 'b');
    });
  });

  group('DuplicateGroup', () {
    test('reclaimableBytes sums every non-keeper', () {
      final group = DuplicateGroup.fromCandidates([
        buildCandidate('keep', 0, width: 400, height: 400, size: 9000),
        buildCandidate('a', 0, size: 1000),
        buildCandidate('b', 0, size: 2000),
      ], KeeperStrategy.highestResolution);
      expect(group.keeperId, 'keep');
      expect(group.reclaimableBytes, 3000);
      expect(group.removable.map((c) => c.id), ['a', 'b']);
    });

    test('signature is stable across order and keeper choice', () {
      final one = DuplicateGroup.fromCandidates([
        buildCandidate('a', 0),
        buildCandidate('b', 0),
      ], KeeperStrategy.newest);
      final two = DuplicateGroup.fromCandidates([
        buildCandidate('b', 0),
        buildCandidate('a', 0),
      ], KeeperStrategy.largestFile);
      expect(one.signature, two.signature);
      expect(one.signature, 'a|b');
    });

    test('withKeeper swaps the keeper and resets removable', () {
      final group = DuplicateGroup.fromCandidates([
        buildCandidate('big', 0, width: 400, height: 400),
        buildCandidate('small', 0, width: 100, height: 100),
      ], KeeperStrategy.highestResolution);
      expect(group.keeperId, 'big');
      final swapped = group.withKeeper('small');
      expect(swapped.keeperId, 'small');
      expect(swapped.removable.map((c) => c.id), ['big']);
    });

    test('withoutIds shrinks the group and re-picks a removed keeper', () {
      final group = DuplicateGroup.fromCandidates([
        buildCandidate('keep', 0, width: 400, height: 400),
        buildCandidate('a', 0, width: 300, height: 300),
        buildCandidate('b', 0, width: 100, height: 100),
      ], KeeperStrategy.highestResolution);
      expect(group.keeperId, 'keep');

      final afterKeeperRemoved = group.withoutIds({
        'keep',
      }, KeeperStrategy.highestResolution);
      expect(afterKeeperRemoved, isNotNull);
      expect(afterKeeperRemoved!.candidates.length, 2);
      // The next-highest resolution becomes the keeper.
      expect(afterKeeperRemoved.keeperId, 'a');
    });

    test('withoutIds returns null below two survivors', () {
      final group = DuplicateGroup.fromCandidates([
        buildCandidate('a', 0),
        buildCandidate('b', 0),
      ], KeeperStrategy.newest);
      expect(group.withoutIds({'a'}, KeeperStrategy.newest), isNull);
    });
  });
}
