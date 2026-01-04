import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/ui_constants.dart';
import '../view_models/duplicate_media_scan_provider.dart';

/// Displays lightweight progress feedback while duplicate scans run in the background.
class DuplicateScanStatusBar extends ConsumerWidget {
  const DuplicateScanStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(duplicateMediaScanProvider);

    if (!scanState.isScanning && !scanState.truncated) {
      return const SizedBox.shrink();
    }

    final progress = scanState.progress;
    final message = scanState.isScanning
        ? 'Scanning library for duplicates...'
        : 'Duplicate scan limited to the first ${scanState.totalCount} items';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: UiSpacing.extraLargeGap,
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
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              IconButton(
                tooltip: 'Restart duplicate scan',
                onPressed: () =>
                    ref.read(duplicateMediaScanProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: UiSpacing.extraSmallGap),
          LinearProgressIndicator(
            value: scanState.isScanning ? progress : 1,
          ),
        ],
      ),
    );
  }
}
