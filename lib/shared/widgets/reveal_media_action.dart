import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../features/media_library/domain/entities/media_entity.dart';
import '../../features/media_library/presentation/screens/media_grid_screen.dart';
import '../providers/navigation_provider.dart';
import '../providers/repository_providers.dart';
import '../utils/bookmark_resolver.dart';

/// Takes the user to the folder [media] actually lives in, and highlights it
/// there.
///
/// The "Reveal in Finder" idiom. Media reached from the Tags tab or from
/// Favorites is aggregated from all over the library, so the containing folder
/// is otherwise invisible — the only clue is the path in the Info dialog.
///
/// Unwinds to the root before pushing, so Back lands the user on the Library
/// tab rather than bouncing them into the viewer they just left. That is safe:
/// the full-screen viewer's `FullScreenExitResult` is popped as `null`, and the
/// grid awaiting it already bails on a null result.
///
/// Reads providers through a container captured from `context` rather than a
/// `WidgetRef`, for the same reason `confirmAndDeleteMedia` does: the calling
/// widget is torn down by the `popUntil` below, so its `ref` cannot survive the
/// await.
Future<void> revealMediaInLibrary(
  BuildContext context,
  MediaEntity media,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final navigator = Navigator.of(context, rootNavigator: true);

  // The folder holding *this* item, not the directory the viewer was opened
  // with: paging through a tag's media crosses directories.
  final directoryPath = p.dirname(media.path);

  final directories = await container
      .read(directoryRepositoryProvider)
      .getDirectories();
  final bookmarkData =
      resolveBookmarkForPath(directoryPath, directories) ?? media.bookmarkData;

  container.read(selectedTabProvider.notifier).state = AppTab.library;

  navigator.popUntil((route) => route.isFirst);
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => MediaGridScreen(
        directoryPath: directoryPath,
        directoryName: p.basename(directoryPath),
        bookmarkData: bookmarkData,
        initialMediaId: media.id,
      ),
    ),
  );
}
