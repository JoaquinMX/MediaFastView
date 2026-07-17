import 'package:flutter/material.dart';

import '../../../../core/utils/file_size_formatter.dart';
import '../../domain/entities/duplicate_candidate.dart';
import '../../domain/entities/duplicate_group.dart';
import 'duplicate_thumbnail.dart';

/// A results-list card summarising one duplicate group: a thumbnail strip
/// (keeper first) and how much trashing the rest would reclaim. Tapping opens
/// the comparison view.
class DuplicateGroupCard extends StatelessWidget {
  const DuplicateGroupCard({
    super.key,
    required this.group,
    required this.selectedForDeletion,
    required this.onTap,
  });

  final DuplicateGroup group;
  final Set<String> selectedForDeletion;
  final VoidCallback onTap;

  static const int _maxThumbnails = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ordered = _orderedCandidates();
    final shown = ordered.take(_maxThumbnails).toList();
    final overflow = ordered.length - shown.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 88,
                child: Row(
                  children: [
                    for (final candidate in shown) ...[
                      _Thumb(
                        candidate: candidate,
                        isKeeper: candidate.id == group.keeperId,
                        isMarkedForDeletion: selectedForDeletion.contains(
                          candidate.id,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (overflow > 0) _OverflowChip(count: overflow),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${group.copyCount} similar images',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Reclaim ${formatFileSize(group.reclaimableBytes)} · '
                          '${selectedForDeletion.length} marked to delete',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Keeper first, then the rest in their existing order.
  List<DuplicateCandidate> _orderedCandidates() {
    final keeper = group.keeper;
    return [
      keeper,
      ...group.candidates.where((candidate) => candidate.id != keeper.id),
    ];
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.candidate,
    required this.isKeeper,
    required this.isMarkedForDeletion,
  });

  final DuplicateCandidate candidate;
  final bool isKeeper;
  final bool isMarkedForDeletion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: DuplicateThumbnail(media: candidate.media, cacheWidth: 200),
          ),
          if (isMarkedForDeletion)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: theme.colorScheme.error.withValues(alpha: 0.28),
                border: Border.all(color: theme.colorScheme.error, width: 2),
              ),
            ),
          if (isKeeper)
            Positioned(
              top: 4,
              left: 4,
              child: _Badge(
                icon: Icons.star,
                color: Colors.amber,
                tooltip: 'Keeper',
              ),
            ),
        ],
      ),
    );
  }
}

class _OverflowChip extends StatelessWidget {
  const _OverflowChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 56,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Text('+$count', style: theme.textTheme.titleMedium),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
