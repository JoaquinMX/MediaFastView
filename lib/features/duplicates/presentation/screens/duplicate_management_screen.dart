import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/file_size_formatter.dart';
import '../../../../shared/providers/media_mutation_bus.dart';
import '../../../../shared/widgets/app_bar.dart';
import '../../../../shared/widgets/delete_media_action.dart';
import '../../domain/entities/duplicate_group.dart';
import '../../domain/entities/duplicate_scan_progress.dart';
import '../../domain/entities/keeper_strategy.dart';
import '../view_models/duplicate_scan_view_model.dart';
import '../widgets/duplicate_group_card.dart';
import '../widgets/sensitivity_selector.dart';
import 'duplicate_comparison_screen.dart';

/// Library-wide review of visually-similar images: scan, tune, and trash.
class DuplicateManagementScreen extends ConsumerWidget {
  const DuplicateManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(duplicateScanViewModelProvider);
    final viewModel = ref.read(duplicateScanViewModelProvider.notifier);

    // A delete or move on any screen prunes the affected copies from the groups,
    // so the list self-heals without a rescan.
    ref.listen<MediaMutation?>(mediaMutationBusProvider, (previous, next) {
      if (next == null || next.removed.isEmpty) return;
      viewModel.applyRemovedIds({for (final media in next.removed) media.id});
    });

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Duplicates',
        actions: [
          if (state is DuplicateResults)
            PopupMenuButton<KeeperStrategy>(
              icon: const Icon(Icons.star_outline),
              tooltip: 'Which copy to keep',
              initialValue: state.keeperStrategy,
              onSelected: (value) =>
                  unawaited(viewModel.setKeeperStrategy(value)),
              itemBuilder: (context) => [
                for (final strategy in KeeperStrategy.values)
                  CheckedPopupMenuItem<KeeperStrategy>(
                    value: strategy,
                    checked: strategy == state.keeperStrategy,
                    child: Text(strategy.label),
                  ),
              ],
            ),
          if (state is DuplicateResults || state is DuplicateEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Rescan library',
              onPressed: () => unawaited(viewModel.scan()),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: switch (state) {
        DuplicateLoading() => const Center(child: CircularProgressIndicator()),
        DuplicateScanning(:final progress) => _ScanningView(
          progress: progress,
          onCancel: viewModel.cancelScan,
        ),
        DuplicateEmpty(:final hasScanned) => _EmptyView(
          hasScanned: hasScanned,
          onScan: () => unawaited(viewModel.scan()),
        ),
        DuplicateScanError(:final message) => _ErrorView(
          message: message,
          onRetry: () => unawaited(viewModel.scan()),
        ),
        DuplicateResults() => _ResultsView(state: state, viewModel: viewModel),
      },
    );
  }
}

class _CoverageNote extends StatelessWidget {
  const _CoverageNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.info_outline,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Similarity matching covers images already indexed in your '
            'library. Video and audio are not compared.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanningView extends StatelessWidget {
  const _ScanningView({required this.progress, required this.onCancel});

  final DuplicateScanProgress progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scanning for duplicates',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress.total == 0 ? null : progress.fraction,
              ),
              const SizedBox(height: 12),
              Text(
                progress.total == 0
                    ? 'Preparing…'
                    : 'Hashing ${progress.processed} of ${progress.total} images'
                          '${progress.reused > 0 ? ' · ${progress.reused} reused from cache' : ''}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.hasScanned, required this.onScan});

  final bool hasScanned;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasScanned ? Icons.done_all : Icons.difference_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                hasScanned
                    ? 'No visually similar images found'
                    : 'Find duplicate photos',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                hasScanned
                    ? 'Nothing matched at this sensitivity. Try a looser match, '
                          'or rescan after adding folders.'
                    : 'Scan your library to group resized, re-exported, and '
                          'duplicated copies of the same image.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.search),
                label: Text(hasScanned ? 'Scan again' : 'Scan library'),
              ),
              const SizedBox(height: 24),
              const _CoverageNote(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({required this.state, required this.viewModel});

  final DuplicateResults state;
  final DuplicateScanViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = state.groups;
    final extraCopies = groups.fold<int>(
      0,
      (sum, group) => sum + group.copyCount - 1,
    );
    final reclaimable = groups.fold<int>(
      0,
      (sum, group) => sum + group.reclaimableBytes,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${groups.length} group${groups.length == 1 ? '' : 's'} · '
                '$extraCopies extra cop${extraCopies == 1 ? 'y' : 'ies'} · '
                'up to ${formatFileSize(reclaimable)} reclaimable',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SensitivitySelector(
                value: state.sensitivity,
                onChanged: (value) =>
                    unawaited(viewModel.setSensitivity(value)),
              ),
              const SizedBox(height: 12),
              const _CoverageNote(),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final group = groups[index];
              return DuplicateGroupCard(
                group: group,
                selectedForDeletion:
                    state.selection[group.signature] ?? const <String>{},
                onTap: () => _openComparison(context, group),
              );
            },
          ),
        ),
        _GlobalDeleteBar(viewModel: viewModel),
      ],
    );
  }

  void _openComparison(BuildContext context, DuplicateGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            DuplicateComparisonScreen(signature: group.signature),
      ),
    );
  }
}

class _GlobalDeleteBar extends StatelessWidget {
  const _GlobalDeleteBar({required this.viewModel});

  final DuplicateScanViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = viewModel.selectedCount;
    final bytes = viewModel.selectedBytes;

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
                      ? 'Marked copies across all groups will show here'
                      : '$count marked · ${formatFileSize(bytes)} to reclaim',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: count == 0
                    ? null
                    : () => unawaited(_deleteAll(context)),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                icon: const Icon(Icons.delete_outline),
                label: Text('Move $count to Trash'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAll(BuildContext context) async {
    final media = viewModel.selectedMedia();
    if (media.isEmpty) return;
    // confirmAndDeleteMediaBatch handles the macOS/"Delete From Source" gates,
    // confirmation, progress, Trash, and publishing to the mutation bus — which
    // the screen listens to and prunes the groups from.
    await confirmAndDeleteMediaBatch(context, media);
  }
}
