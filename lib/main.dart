import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/isar_database.dart';
import 'core/database/migration/database_migrator.dart';
import 'features/favorites/data/data_sources/isar_favorites_data_source.dart';
import 'features/media_library/data/data_sources/isar_directory_data_source.dart';
import 'features/media_library/data/data_sources/isar_media_data_source.dart';
import 'features/tagging/data/data_sources/isar_tag_data_source.dart';
import 'shared/providers/repository_providers.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/widgets/error_boundary.dart';
import 'shared/widgets/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  final isar = await IsarDatabase.open();

  final migrator = DatabaseMigrator(
    sharedPreferences: sharedPreferences,
    directoryDataSource: IsarDirectoryDataSource(isar),
    mediaDataSource: IsarMediaDataSource(isar),
    tagDataSource: IsarTagDataSource(isar),
    favoritesDataSource: IsarFavoritesDataSource(isar),
  );
  await migrator.migrateIfNeeded();

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      isarProvider.overrideWithValue(isar),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return ErrorBoundary(
      child: MaterialApp(
        title: 'Media Fast View',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: themeMode,
        home: const MainNavigation(),
      ),
    );
  }
}
