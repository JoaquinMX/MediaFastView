import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../thumbnails/presentation/media_thumbnail.dart';
import '../../domain/entities/directory_cover_entity.dart';
import '../../domain/entities/media_entity.dart';
import '../providers/directory_cover_controller.dart';
import '../providers/directory_cover_providers.dart';

/// Lets the user select or reset a directory's direct-child media cover.
class DirectoryCoverPickerDialog extends ConsumerStatefulWidget {
  const DirectoryCoverPickerDialog({
    super.key,
    required this.directoryPath,
    required this.directoryName,
    this.bookmarkData,
  });

  final String directoryPath;
  final String directoryName;
  final String? bookmarkData;

  static Future<bool?> show(
    BuildContext context, {
    required String directoryPath,
    required String directoryName,
    String? bookmarkData,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => DirectoryCoverPickerDialog(
        directoryPath: directoryPath,
        directoryName: directoryName,
        bookmarkData: bookmarkData,
      ),
    );
  }

  @override
  ConsumerState<DirectoryCoverPickerDialog> createState() {
    return _DirectoryCoverPickerDialogState();
  }
}

class _DirectoryCoverPickerDialogState
    extends ConsumerState<DirectoryCoverPickerDialog> {
  MediaEntity? _selectedMedia;
  bool _selectionChanged = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    ref.watch(directoryCoverControllerProvider(widget.directoryPath));
    final cover = ref.watch(directoryCoverProvider(widget.directoryPath));
    final screenSize = MediaQuery.sizeOf(context);
    final contentWidth = (screenSize.width - 80).clamp(280.0, 640.0).toDouble();
    final contentHeight = (screenSize.height - 200)
        .clamp(280.0, 440.0)
        .toDouble();
    final candidates = ref.watch(
      directoryCoverCandidatesProvider(
        DirectoryCoverCandidatesQuery(
          directoryPath: widget.directoryPath,
          bookmarkData: widget.bookmarkData,
        ),
      ),
    );

    return AlertDialog(
      title: Text('Choose cover for ${widget.directoryName}'),
      content: SizedBox(
        width: contentWidth,
        height: contentHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose an image or video directly inside this folder, or '
              'select No cover to display the folder icon.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: candidates.when(
                data: (items) => cover.when(
                  data: (currentCover) =>
                      _buildCandidateGrid(items, currentCover),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _buildError(error),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _buildError(error),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (cover.valueOrNull != null)
          TextButton(
            onPressed: _isSaving ? null : _useAutomaticCover,
            child: const Text('Use automatic'),
          ),
        FilledButton(
          onPressed: _isSaving || !_hasEffectiveChange(cover.valueOrNull)
              ? null
              : () => _saveSelection(cover.valueOrNull),
          child: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildCandidateGrid(
    List<MediaEntity> items,
    DirectoryCoverEntity? currentCover,
  ) {
    final currentFileName = currentCover?.sourceFileName;
    final effectivePath = _selectionChanged
        ? _selectedMedia?.path
        : items
              .where(
                (item) =>
                    item.name.toLowerCase() == currentFileName?.toLowerCase(),
              )
              .firstOrNull
              ?.path;
    final isNoCoverSelected = _selectionChanged
        ? _selectedMedia == null
        : currentCover?.mode == DirectoryCoverMode.none;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width < 600 ? 2 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _NoCoverCandidate(
            isSelected: isNoCoverSelected,
            onTap: () {
              setState(() {
                _selectedMedia = null;
                _selectionChanged = true;
                _errorMessage = null;
              });
            },
          );
        }

        final item = items[index - 1];
        final isSelected =
            p.normalize(item.path).toLowerCase() ==
            p.normalize(effectivePath ?? '').toLowerCase();
        return _CoverCandidate(
          media: item,
          bookmarkData: widget.bookmarkData,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              _selectedMedia = item;
              _selectionChanged = true;
              _errorMessage = null;
            });
          },
        );
      },
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Text(
        'Could not load cover choices: $error',
        textAlign: TextAlign.center,
      ),
    );
  }

  bool _hasEffectiveChange(DirectoryCoverEntity? currentCover) {
    if (!_selectionChanged) {
      return false;
    }
    final selectedMedia = _selectedMedia;
    if (selectedMedia == null) {
      return currentCover?.mode != DirectoryCoverMode.none;
    }
    return currentCover?.mode != DirectoryCoverMode.media ||
        selectedMedia.name.toLowerCase() !=
            currentCover?.sourceFileName?.toLowerCase();
  }

  Future<void> _saveSelection(DirectoryCoverEntity? currentCover) async {
    if (_selectionChanged && _selectedMedia == null) {
      await _setNoCover();
      return;
    }

    final candidates = ref.read(
      directoryCoverCandidatesProvider(
        DirectoryCoverCandidatesQuery(
          directoryPath: widget.directoryPath,
          bookmarkData: widget.bookmarkData,
        ),
      ),
    );
    final items = candidates.valueOrNull ?? const <MediaEntity>[];
    final media = _selectionChanged
        ? _selectedMedia
        : items
              .where(
                (item) =>
                    item.name.toLowerCase() ==
                    currentCover?.sourceFileName?.toLowerCase(),
              )
              .firstOrNull;
    if (media == null) {
      setState(() => _errorMessage = 'Select a cover first.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    await ref
        .read(directoryCoverControllerProvider(widget.directoryPath).notifier)
        .setCover(media);
    if (!mounted) {
      return;
    }
    final result = ref.read(
      directoryCoverControllerProvider(widget.directoryPath),
    );
    result.when(
      data: (_) => Navigator.of(context).pop(true),
      loading: () {},
      error: (error, _) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Could not save the cover: $error';
        });
      },
    );
  }

  Future<void> _setNoCover() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    await ref
        .read(directoryCoverControllerProvider(widget.directoryPath).notifier)
        .setNoCover();
    if (!mounted) {
      return;
    }
    final result = ref.read(
      directoryCoverControllerProvider(widget.directoryPath),
    );
    result.when(
      data: (_) => Navigator.of(context).pop(true),
      loading: () {},
      error: (error, _) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Could not save the no-cover choice: $error';
        });
      },
    );
  }

  Future<void> _useAutomaticCover() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    await ref
        .read(directoryCoverControllerProvider(widget.directoryPath).notifier)
        .resetCover();
    if (!mounted) {
      return;
    }
    final result = ref.read(
      directoryCoverControllerProvider(widget.directoryPath),
    );
    result.when(
      data: (_) => Navigator.of(context).pop(true),
      loading: () {},
      error: (error, _) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Could not restore automatic previews: $error';
        });
      },
    );
  }
}

class _NoCoverCandidate extends StatelessWidget {
  const _NoCoverCandidate({required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          width: isSelected ? 3 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ColoredBox(
                color: colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.folder_outlined,
                  size: 64,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Icon(Icons.hide_image_outlined, size: 16),
                  const SizedBox(width: 6),
                  const Expanded(child: Text('No cover')),
                  if (isSelected)
                    Icon(Icons.check_circle, color: colorScheme.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverCandidate extends StatelessWidget {
  const _CoverCandidate({
    required this.media,
    required this.bookmarkData,
    required this.isSelected,
    required this.onTap,
  });

  final MediaEntity media;
  final String? bookmarkData;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          width: isSelected ? 3 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: MediaThumbnail(
                media: media,
                bookmarkData: bookmarkData,
                placeholderBuilder: (_) =>
                    const Center(child: CircularProgressIndicator()),
                errorBuilder: (_) => Icon(
                  media.type == MediaType.video
                      ? Icons.movie_outlined
                      : Icons.broken_image_outlined,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(
                    media.type == MediaType.video
                        ? Icons.movie_outlined
                        : Icons.image_outlined,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      media.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: colorScheme.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
