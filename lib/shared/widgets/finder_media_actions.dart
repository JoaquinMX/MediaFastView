import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/services/bookmark_service.dart';
import '../../features/media_library/domain/entities/media_entity.dart';
import '../providers/repository_providers.dart';
import '../utils/bookmark_resolver.dart';

/// Whether Finder actions can be offered at all.
bool get supportsFinderActions => Platform.isMacOS;

/// Opens Finder with [media] selected.
///
/// The sibling of "Go to directory", which relocates you *inside* the app. This
/// one hands you off to the Finder, which is what people reach for next.
///
/// A sub-directory has no bookmark of its own, so access rides on the enclosing
/// tracked root's — the same resolution the reveal-in-library action uses.
Future<void> revealMediaInFinder(
  BuildContext context,
  MediaEntity media,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);

  final directories = await container
      .read(directoryRepositoryProvider)
      .getDirectories();
  final bookmarkData =
      resolveBookmarkForPath(p.dirname(media.path), directories) ??
          media.bookmarkData;

  try {
    await BookmarkService.instance.revealInFinder(
      media.path,
      bookmarkData: bookmarkData,
    );
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Could not reveal "${media.name}" in Finder: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

/// Copies [media]'s full path to the clipboard.
///
/// No platform work and no permissions — the path is already in hand.
Future<void> copyMediaPath(BuildContext context, MediaEntity media) async {
  final messenger = ScaffoldMessenger.of(context);

  await Clipboard.setData(ClipboardData(text: media.path));

  messenger.showSnackBar(
    const SnackBar(
      content: Text('Path copied'),
      duration: Duration(seconds: 2),
    ),
  );
}
