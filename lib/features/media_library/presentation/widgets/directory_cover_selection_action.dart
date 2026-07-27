import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/media_entity.dart';
import '../providers/directory_cover_controller.dart';

/// Applies an already-validated image selection as a directory cover.
class DirectoryCoverSelectionAction extends ConsumerWidget {
  const DirectoryCoverSelectionAction({
    super.key,
    required this.directoryPath,
    required this.selectedImages,
    required this.onSaved,
  });

  static const Key actionKey = Key('use-selected-images-as-directory-cover');
  static const String actionLabel = 'Use selected images as directory cover';

  final String directoryPath;
  final List<MediaEntity> selectedImages;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(directoryCoverControllerProvider(directoryPath));
    return Tooltip(
      message: actionLabel,
      child: Semantics(
        button: true,
        label: actionLabel,
        child: FilledButton.icon(
          key: actionKey,
          onPressed: state.isLoading
              ? null
              : () => unawaited(_saveSelection(context, ref)),
          icon: const Icon(Icons.collections_bookmark_outlined),
          label: const Text('Use as cover'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: const Size(0, 40),
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }

  Future<void> _saveSelection(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(directoryCoverControllerProvider(directoryPath).notifier)
        .setCovers(selectedImages);
    if (!context.mounted) {
      return;
    }

    final result = ref.read(directoryCoverControllerProvider(directoryPath));
    result.when(
      data: (_) {
        onSaved();
        final count = selectedImages.length;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              count == 1
                  ? 'Set 1 image as the directory cover'
                  : 'Set $count images as the directory cover',
            ),
          ),
        );
      },
      loading: () {},
      error: (error, _) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not save the cover: $error')),
        );
      },
    );
  }
}
