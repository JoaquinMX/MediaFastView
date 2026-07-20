import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy decode-cap setting is removed and real cache defaults on',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'thumbnail_caching_enabled': false,
      });
      const repository = SettingsRepositoryImpl();

      final settings = await repository.loadSettings();
      final preferences = await SharedPreferences.getInstance();

      expect(settings.thumbnailDiskCacheEnabled, isTrue);
      expect(preferences.containsKey('thumbnail_caching_enabled'), isFalse);
    },
  );

  test('persists the new disk cache preference independently', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const repository = SettingsRepositoryImpl();

    await repository.saveThumbnailDiskCacheEnabled(false);
    final settings = await repository.loadSettings();

    expect(settings.thumbnailDiskCacheEnabled, isFalse);
  });
}
