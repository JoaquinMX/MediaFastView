import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/utils/file_size_formatter.dart';
import '../../../../shared/widgets/app_bar.dart';
import '../../../../shared/widgets/delete_media_action.dart';
import '../../../../shared/widgets/finder_media_actions.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../domain/entities/duplicate_candidate.dart';
import '../../domain/entities/duplicate_group.dart';
import '../view_models/duplicate_scan_view_model.dart';
import '../widgets/duplicate_thumbnail.dart';

/// Side-by-side review of one duplicate group.
///
/// Reads its group live from [duplicateScanViewModelProvider] by [signature], so
/// changing the keeper, checking copies, or deleting from here stays in sync
/// with the results list underneath — and the screen pops itself once the group
/// no longer exists (dismissed, or shrunk below two by deletions).
class DuplicateComparisonScreen extends ConsumerWidget {
  const DuplicateComparisonScreen({super.key, required this.signature});

  final String signature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(duplicateScanViewModelProvider);
    final viewModel = ref.read(duplicateScanViewModelProvider.notifier);

    final group = state is DuplicateResults
        ? state.groups.where((g) => g.signature == signature).firstOrNull
        : null;

    if (group == null) {
      // The group is gone. Leave once the current frame settles.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(
        appBar: CustomAppBar(title: 'Review duplicates'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final selection =
        (state as DuplicateResults).selection[signature] ?? const <String>{};
    final maxPixels = group.candidates
        .map((candidate) => candidate.pixelCount)
        .fold<int>(0, (max, value) => value > max ? value : max);
    final selectedInGroup = group.candidates
        .where((candidate) => selection.contains(candidate.id))
        .map((candidate) => candidate.media)
        .toList(growable: false);

    return Scaffold(
      appBar: CustomAppBar(
        title: '${group.copyCount} similar images',
        actions: [
          TextButton.icon(
            onPressed: () => unawaited(viewModel.dismissGroup(group)),
            icon: const Icon(Icons.rule),
            label: const Text('Not duplicates'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _Header(group: group),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth / 300).floor().clamp(
                  1,
                  4,
                );
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: group.candidates.length,
                  itemBuilder: (context, index) {
                    final candidate = group.candidates[index];
                    final isKeeper = candidate.id == group.keeperId;
                    return _CandidateCard(
                      candidate: candidate,
                      isKeeper: isKeeper,
                      isHighestResolution: candidate.pixelCount == maxPixels,
                      isMarkedForDeletion: selection.contains(candidate.id),
                      distanceToKeeper: group.hashDistanceToKeeper(candidate),
                      onMakeKeeper: () =>
                          viewModel.setKeeper(signature, candidate.id),
                      onToggleDeletion: (value) => viewModel.toggleDeletion(
                        signature,
                        candidate.id,
                        value,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _DeleteBar(
            selected: selectedInGroup,
            onDeleted: (ids) => viewModel.applyRemovedIds(ids),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.group});

  final DuplicateGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Text(
        'Keep the ★ copy and trash the rest — or pick a different keeper. '
        'Reclaims up to ${formatFileSize(group.reclaimableBytes)}.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.isKeeper,
    required this.isHighestResolution,
    required this.isMarkedForDeletion,
    required this.distanceToKeeper,
    required this.onMakeKeeper,
    required this.onToggleDeletion,
  });

  final DuplicateCandidate candidate;
  final bool isKeeper;
  final bool isHighestResolution;
  final bool isMarkedForDeletion;
  final int distanceToKeeper;
  final VoidCallback onMakeKeeper;
  final ValueChanged<bool> onToggleDeletion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = candidate.media;
    final borderColor = isKeeper
        ? Colors.amber
        : isMarkedForDeletion
        ? theme.colorScheme.error
        : theme.colorScheme.outlineVariant;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: isKeeper ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _showFullPreview(context, media),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DuplicateThumbnail(media: media),
                  if (isKeeper)
                    const Positioned(top: 6, left: 6, child: _KeeperChip()),
                  if (supportsFinderActions)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: _CandidateMenu(media: media),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${candidate.width} × ${candidate.height}',
                      style: theme.textTheme.titleSmall,
                    ),
                    if (isHighestResolution) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.high_quality,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatFileSize(media.size)} · '
                  '${_extension(media.path)} · ${_formatDate(media.lastModified)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.dirname(media.path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!isKeeper && distanceToKeeper > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$distanceToKeeper-bit difference from keeper',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (isKeeper)
                  Row(
                    children: [
                      Icon(Icons.star, size: 18, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text('Keeper', style: theme.textTheme.labelLarge),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: onMakeKeeper,
                          icon: const Icon(Icons.star_outline, size: 18),
                          label: const Text('Keep'),
                        ),
                      ),
                      Tooltip(
                        message: 'Move to Trash',
                        child: Checkbox(
                          value: isMarkedForDeletion,
                          onChanged: (value) =>
                              onToggleDeletion(value ?? false),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullPreview(BuildContext context, MediaEntity media) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 6,
              child: Center(child: Image.file(File(media.path))),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _extension(String path) {
    final ext = p.extension(path);
    return ext.isEmpty ? 'file' : ext.substring(1).toUpperCase();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _KeeperChip extends StatelessWidget {
  const _KeeperChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: Colors.amber),
          const SizedBox(width: 4),
          const Text(
            'Keeper',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CandidateMenu extends StatelessWidget {
  const _CandidateMenu({required this.media});

  final MediaEntity media;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
        tooltip: 'Actions',
        onSelected: (value) {
          switch (value) {
            case 'reveal':
              unawaited(revealMediaInFinder(context, media));
            case 'copy':
              unawaited(copyMediaPath(context, media));
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'reveal', child: Text('Reveal in Finder')),
          PopupMenuItem(value: 'copy', child: Text('Copy path')),
        ],
      ),
    );
  }
}

class _DeleteBar extends StatelessWidget {
  const _DeleteBar({required this.selected, required this.onDeleted});

  final List<MediaEntity> selected;
  final ValueChanged<Set<String>> onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = selected.length;
    final bytes = selected.fold<int>(0, (sum, media) => sum + media.size);

    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  count == 0
                      ? 'No copies marked in this group'
                      : '$count marked · ${formatFileSize(bytes)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: count == 0
                    ? null
                    : () => unawaited(_delete(context)),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Move to Trash'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final result = await confirmAndDeleteMediaBatch(context, selected);
    if (result == null || !result.hasSuccesses) return;
    onDeleted(result.successfulIds.toSet());
  }
}
