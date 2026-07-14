import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/profiles/domain/entities/profile_entity.dart';
import 'package:media_fast_view/features/profiles/domain/profile_validation.dart';

ProfileEntity _profile(String id, String name) => ProfileEntity(
      id: id,
      name: name,
      sortOrder: 0,
      createdAt: DateTime(2024, 1, 1),
    );

void main() {
  group('validateProfileName', () {
    test('accepts a normal name', () {
      expect(() => validateProfileName('Photography'), returnsNormally);
    });

    test('validates the trimmed name, since that is what is persisted', () {
      expect(() => validateProfileName('  Work  '), returnsNormally);
      expect(() => validateProfileName('   '), throwsA(isA<ProfileValidationException>()));
    });

    test('rejects a name that is too short or too long', () {
      expect(
        () => validateProfileName('a'),
        throwsA(isA<ProfileValidationException>()),
      );
      expect(
        () => validateProfileName('a' * (maxProfileNameLength + 1)),
        throwsA(isA<ProfileValidationException>()),
      );
    });

    test('rejects path-hostile characters', () {
      for (final name in <String>['a/b', 'a<b', 'a|b', 'a?b']) {
        expect(
          () => validateProfileName(name),
          throwsA(isA<ProfileValidationException>()),
          reason: name,
        );
      }
    });
  });

  group('isProfileNameTaken', () {
    final profiles = <ProfileEntity>[
      _profile('p1', 'Work'),
      _profile('p2', 'Personal'),
    ];

    test('matches case-insensitively', () {
      expect(isProfileNameTaken('work', profiles), isTrue);
      expect(isProfileNameTaken('Reference', profiles), isFalse);
    });

    test('a profile does not collide with itself when renaming', () {
      // The case fix that would otherwise be rejected as a duplicate of itself.
      expect(
        isProfileNameTaken('WORK', profiles, excludingId: 'p1'),
        isFalse,
      );
      // But it still collides with a *different* profile.
      expect(
        isProfileNameTaken('Personal', profiles, excludingId: 'p1'),
        isTrue,
      );
    });
  });
}
