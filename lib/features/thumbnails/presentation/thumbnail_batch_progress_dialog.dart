import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_batch_progress.dart';
import 'package:media_fast_view/features/thumbnails/presentation/thumbnail_batch_controller.dart';

class ThumbnailBatchProgressDialog extends ConsumerWidget {
  const ThumbnailBatchProgressDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(thumbnailBatchControllerProvider);
    final controller = ref.read(thumbnailBatchControllerProvider.notifier);
    final isCancelling = progress.status == ThumbnailBatchStatus.cancelling;

    return PopScope(
      canPop: !progress.isActive,
      child: AlertDialog(
        title: Text(_title(progress.status)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (progress.isActive) ...[
                LinearProgressIndicator(value: progress.fraction),
                const SizedBox(height: 16),
              ],
              Text('${progress.completed} of ${progress.total} processed'),
              if (progress.currentName != null) ...[
                const SizedBox(height: 8),
                Text(
                  progress.currentName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '${progress.generated} generated · '
                '${progress.cacheHits} already cached · '
                '${progress.failed} failed',
              ),
              if (progress.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  progress.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (progress.isActive)
            TextButton(
              onPressed: isCancelling ? null : controller.cancel,
              child: Text(isCancelling ? 'Cancelling…' : 'Cancel'),
            )
          else
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
        ],
      ),
    );
  }

  String _title(ThumbnailBatchStatus status) {
    return switch (status) {
      ThumbnailBatchStatus.idle ||
      ThumbnailBatchStatus.running => 'Generating Thumbnails',
      ThumbnailBatchStatus.cancelling => 'Cancelling…',
      ThumbnailBatchStatus.completed => 'Thumbnails Ready',
      ThumbnailBatchStatus.cancelled => 'Generation Cancelled',
      ThumbnailBatchStatus.failed => 'Generation Failed',
    };
  }
}
