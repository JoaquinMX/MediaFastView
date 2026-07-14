import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profiles/data/active_profile_store.dart';

final activeProfileStoreProvider = Provider<ActiveProfileStore>(
  (ref) => const ActiveProfileStore(),
);

/// The profile every scoped provider reads from.
///
/// Resolved before the first frame by `ProfileBootstrap` and seeded into the root
/// `ProviderScope` in `main`, so it is a plain non-null `String` rather than an
/// `AsyncValue` that every consumer would have to unwrap.
///
/// The unseeded build throws on purpose. A default would be worse than a crash:
/// it would silently scope the whole app to a profile that owns nothing, and the
/// user would see an empty library rather than an error.
final activeProfileIdProvider =
    NotifierProvider<ActiveProfileIdNotifier, String>(
  ActiveProfileIdNotifier.new,
);

class ActiveProfileIdNotifier extends Notifier<String> {
  ActiveProfileIdNotifier([this._seed]);

  final String? _seed;

  @override
  String build() {
    final seed = _seed;
    if (seed == null) {
      throw StateError(
        'activeProfileIdProvider was read without being seeded. Override it in '
        'the root ProviderScope with the id resolved by ProfileBootstrap.',
      );
    }
    return seed;
  }

  /// Switches the app to [profileId].
  ///
  /// Setting `state` is what re-scopes everything: the repository providers watch
  /// this, and being `autoDispose` they are torn down and rebuilt against the new
  /// profile, taking their use cases, caches and view models with them.
  Future<void> switchTo(String profileId) async {
    if (state == profileId) {
      return;
    }
    await ref.read(activeProfileStoreProvider).write(profileId);
    state = profileId;
  }
}
