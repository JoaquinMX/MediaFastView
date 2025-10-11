import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/favorites/data/data_sources/shared_preferences_data_source.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SharedPreferencesFavoritesDataSource dataSource;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    dataSource = SharedPreferencesFavoritesDataSource(prefs);
  });

  test('getFavorites migrates legacy mediaId entries to item schema', () async {
    final legacyFavorites = [
      {
        'mediaId': 'm1',
        'addedAt': '2024-01-01T00:00:00.000Z',
      },
      {
        'mediaId': 'm2',
        'addedAt': DateTime(2024, 01, 02).millisecondsSinceEpoch,
      },
    ];

    await prefs.setString('favorites', jsonEncode(legacyFavorites));

    final favorites = await dataSource.getFavorites();

    expect(favorites, hasLength(2));
    expect(favorites.first.itemId, 'm1');
    expect(favorites.first.itemType, FavoriteItemType.media);
    expect(favorites.last.itemId, 'm2');

    final persistedRaw = prefs.getString('favorites');
    expect(persistedRaw, isNotNull);
    final persisted = jsonDecode(persistedRaw!) as List<dynamic>;
    final firstEntry = persisted.first as Map<String, dynamic>;
    expect(firstEntry['itemId'], 'm1');
    expect(firstEntry['itemType'], 'media');
    expect(firstEntry.containsKey('mediaId'), isFalse);
  });
}
