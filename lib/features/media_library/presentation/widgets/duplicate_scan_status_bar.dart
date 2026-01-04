import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/shared/providers/duplicate_media_scan_provider.dart';

import '../../../../core/constants/ui_constants.dart';

/// Displays lightweight progress feedback while duplicate scans run in the background.
class DuplicateScanStatusBar extends ConsumerWidget {
  const DuplicateScanStatusBar({
    super.key,
    required this.rootDirectory,
  });

  final DirectoryEntity rootDirectory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(duplicateMediaScanProvider(rootDirectory));

    return scanState.when(
      data: (progress) {
        final isScanning = !progress.isComplete && !progress.isCancelled;

        if (!isScanning) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: UiSpacing.verticalGap,
            vertical: UiSpacing.smallGap,
          ),
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.refresh),
                  const SizedBox(width: UiSpacing.smallGap),
                  Expanded(
                    child: Text(
                      'Scanning library for duplicates...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Restart duplicate scan',
                    onPressed: () => ref.refresh(
                      duplicateMediaScanProvider(rootDirectory),
                    ),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: UiSpacing.extraSmallGap),
              const LinearProgressIndicator(),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: UiSpacing.gridPadding,
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => Padding(
        padding: UiSpacing.gridPadding,
        child: Text('Failed to scan duplicates: $error'),
      ),
    );
  }
}
