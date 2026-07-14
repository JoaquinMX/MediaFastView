import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which profile was last active, across launches.
///
/// Deliberately not part of `AppSettings`: settings are app-wide and stay that
/// way, and this is the one preference that selects between profiles rather than
/// living inside one.
class ActiveProfileStore {
  const ActiveProfileStore();

  static const String _key = 'active_profile_id';

  /// The last active profile id, or null on a first launch.
  ///
  /// May name a profile that no longer exists — the caller is expected to fall
  /// back rather than trust it.
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    return (stored == null || stored.isEmpty) ? null : stored;
  }

  Future<void> write(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, profileId);
  }
}
