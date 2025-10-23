import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/file_log_output.dart';
import 'core/services/logging_service.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/widgets/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeLogging();
  runApp(const ProviderScope(child: MyApp()));
}

Future<void> _initializeLogging() async {
  try {
    final fileOutput = await FileLogOutput.create();
    LoggingService.instance.addOutput(fileOutput);
    LoggingService.instance.info('File logging configured', {
      'path': fileOutput.filePath,
    });
  } catch (error) {
    debugPrint('Failed to initialize file logging: $error');
  }
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
