import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/isar_database.dart';
import 'core/services/isar_schemas.dart';
import 'features/profiles/domain/profile_bootstrap.dart';
import 'shared/providers/active_profile_provider.dart';
import 'shared/providers/repository_providers.dart';
import 'shared/providers/settings_providers.dart';
import 'shared/widgets/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The database is built here rather than left to its provider so the active
  // profile can be resolved before the first frame: every scoped provider reads
  // it synchronously. Opening it also runs the migrations. The same instance is
  // then handed to the provider, so there is exactly one database and the
  // migrations run exactly once.
  final database = IsarDatabase(
    schemas: isarCollectionSchemas,
    migrate: runIsarMigrations,
  );
  final activeProfileId = await ProfileBootstrap(database: database).resolve();

  runApp(
    // A single root scope. Nesting one below `MaterialApp` would leave the
    // full-screen viewer — pushed as a `Navigator` route — outside the override,
    // and `activeProfileIdProvider` would throw there.
    ProviderScope(
      overrides: <Override>[
        isarDatabaseProvider.overrideWithValue(database),
        activeProfileIdProvider.overrideWith(
          () => ActiveProfileIdNotifier(activeProfileId),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
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
    );
  }
}
