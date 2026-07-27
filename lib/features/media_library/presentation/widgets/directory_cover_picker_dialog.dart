import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/utils/file_utils.dart';
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
  List<MediaEntity> _selectedImages = <MediaEntity>[];
  bool _isNoCoverSelected = false;
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
              'Choose one to four images directly inside this folder. '
              'Tap a selected image to remove it, or select No cover to '
              'display the folder icon.',
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
              : _saveSelection,
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
    final images = items
        .where(
          (item) =>
              item.type == MediaType.image &&
              !isExcludedMediaFileName(item.name),
        )
        .toList(growable: false);
    final effectiveSelections = _effectiveSelections(images, currentCover);
    final isNoCoverSelected = _selectionChanged
        ? _isNoCoverSelected
        : currentCover?.mode == DirectoryCoverMode.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${effectiveSelections.length} of '
          '${DirectoryCoverEntity.maximumSelectionCount} images selected',
          key: const Key('directory-cover-selection-count'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.sizeOf(context).width < 600 ? 2 : 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: images.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _NoCoverCandidate(
                  isSelected: isNoCoverSelected,
                  onTap: () {
                    setState(() {
                      _selectedImages = <MediaEntity>[];
                      _isNoCoverSelected = true;
                      _selectionChanged = true;
                      _errorMessage = null;
                    });
                  },
                );
              }

              final item = images[index - 1];
              final selectedIndex = effectiveSelections.indexWhere(
                (selected) => _samePath(selected.path, item.path),
              );
              return _CoverCandidate(
                media: item,
                bookmarkData: widget.bookmarkData,
                selectionPosition: selectedIndex < 0 ? null : selectedIndex + 1,
                onTap: () =>
                    _toggleSelection(item, effectiveSelections, selectedIndex),
              );
            },
          ),
        ),
      ],
    );
  }

  List<MediaEntity> _effectiveSelections(
    List<MediaEntity> items,
    DirectoryCoverEntity? currentCover,
  ) {
    if (_selectionChanged) {
      return _selectedImages;
    }
    if (currentCover?.mode != DirectoryCoverMode.media) {
      return const <MediaEntity>[];
    }

    final selections = <MediaEntity>[];
    for (final coverSelection in currentCover!.selections) {
      if (coverSelection.mediaType != MediaType.image) {
        continue;
      }
      final match = items
          .where(
            (item) =>
                item.name.toLowerCase() ==
                coverSelection.sourceFileName.toLowerCase(),
          )
          .firstOrNull;
      if (match != null) {
        selections.add(match);
      }
    }
    return selections;
  }

  void _toggleSelection(
    MediaEntity item,
    List<MediaEntity> effectiveSelections,
    int selectedIndex,
  ) {
    if (selectedIndex < 0 &&
        effectiveSelections.length >=
            DirectoryCoverEntity.maximumSelectionCount) {
      setState(() {
        _errorMessage =
            'You can select up to '
            '${DirectoryCoverEntity.maximumSelectionCount} images. '
            'Remove one before choosing another.';
      });
      return;
    }

    final updatedSelections = List<MediaEntity>.of(effectiveSelections);
    if (selectedIndex >= 0) {
      updatedSelections.removeAt(selectedIndex);
    } else {
      updatedSelections.add(item);
    }
    setState(() {
      _selectedImages = updatedSelections;
      _isNoCoverSelected = false;
      _selectionChanged = true;
      _errorMessage = null;
    });
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
    if (_isNoCoverSelected) {
      return currentCover?.mode != DirectoryCoverMode.none;
    }
    if (_selectedImages.isEmpty) {
      return false;
    }
    if (currentCover?.mode != DirectoryCoverMode.media ||
        currentCover!.selections.length != _selectedImages.length) {
      return true;
    }
    for (var index = 0; index < _selectedImages.length; index += 1) {
      final currentSelection = currentCover.selections[index];
      if (currentSelection.mediaType != MediaType.image ||
          currentSelection.sourceFileName.toLowerCase() !=
              _selectedImages[index].name.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  Future<void> _saveSelection() async {
    if (_selectionChanged && _isNoCoverSelected) {
      await _setNoCover();
      return;
    }

    if (!_selectionChanged || _selectedImages.isEmpty) {
      setState(() {
        _errorMessage = 'Select at least one image or choose No cover.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    await ref
        .read(directoryCoverControllerProvider(widget.directoryPath).notifier)
        .setCovers(_selectedImages);
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

  bool _samePath(String first, String second) {
    return p.normalize(first).toLowerCase() ==
        p.normalize(second).toLowerCase();
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
    required this.selectionPosition,
    required this.onTap,
  });

  final MediaEntity media;
  final String? bookmarkData;
  final int? selectionPosition;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = selectionPosition != null;
    return Material(
      key: Key('directory-cover-candidate-${media.name}'),
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
                  const Icon(Icons.image_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      media.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selectionPosition case final position?)
                    Semantics(
                      label: 'Selected image $position',
                      child: CircleAvatar(
                        key: Key(
                          'directory-cover-selection-position-$position',
                        ),
                        radius: 11,
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        child: Text(
                          '$position',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onPrimary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
