import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../../../core/constants/ui_constants.dart';
import '../../../../shared/widgets/file_operation_button.dart';
import '../../../full_screen/presentation/screens/full_screen_viewer_screen.dart';
import '../models/duplicate_group.dart';
import '../view_models/duplicate_media_provider.dart';

/// Panel that surfaces suspected duplicate media items grouped by signature.
class DuplicateMediaPanel extends ConsumerWidget {
  const DuplicateMediaPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duplicateGroups = ref.watch(duplicateMediaGroupsProvider);

    return duplicateGroups.when(
      data: (groups) {
        if (groups.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: UiSpacing.gridPadding,
          child: Card(
            elevation: UiSizing.elevationLow,
            child: Padding(
              padding: UiSpacing.dialogPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.copy),
                      const SizedBox(width: UiSpacing.smallGap),
                      Text(
                        'Suspected duplicates',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Refresh duplicates',
                        onPressed: () => ref.refresh(duplicateMediaGroupsProvider),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: UiSpacing.verticalGap),
                  SizedBox(
                    height: 240,
                    child: ListView.separated(
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return _DuplicateGroupTile(group: group);
                      },
                      separatorBuilder: (_, __) => const SizedBox(
                        height: UiSpacing.smallGap,
                      ),
                      itemCount: groups.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: UiSpacing.gridPadding,
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => Padding(
        padding: UiSpacing.gridPadding,
        child: Text('Failed to load duplicates: $error'),
      ),
    );
  }
}

class _DuplicateGroupTile extends StatelessWidget {
  const _DuplicateGroupTile({required this.group});

  final DuplicateMediaGroup group;

  @override
  Widget build(BuildContext context) {
    final subtitle =
        '${group.items.length} items • ${(group.size / 1024).toStringAsFixed(1)} KB';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subtitle,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: UiSpacing.extraSmallGap),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: group.items
                .map((item) => Padding(
                      padding:
                          const EdgeInsets.only(right: UiSpacing.smallGap),
                      child: _DuplicateMediaChip(item: item),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _DuplicateMediaChip extends StatelessWidget {
  const _DuplicateMediaChip({required this.item});

  final DuplicateMediaItem item;

  @override
  Widget build(BuildContext context) {
    final directoryLabel = item.directory?.name ??
        path.basename(path.dirname(item.media.path));
    return Container(
      width: 220,
      padding: const EdgeInsets.all(UiSpacing.smallGap),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(UiSizing.borderRadiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ThumbnailPreview(media: item.media),
              const SizedBox(width: UiSpacing.smallGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.media.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      directoryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: UiSpacing.smallGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Open',
                icon: const Icon(Icons.open_in_new),
                onPressed: () => _openMedia(context, item),
              ),
              FileOperationButton(
                media: item.media,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openMedia(BuildContext context, DuplicateMediaItem item) {
    final directoryPath = item.directory?.path ??
        path.dirname(item.media.path);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenViewerScreen(
          directoryPath: directoryPath,
          directoryName: item.directory?.name,
          bookmarkData: item.directory?.bookmarkData,
          initialMediaId: item.media.id,
          mediaList: [item.media],
        ),
      ),
    );
  }
}

class _ThumbnailPreview extends StatelessWidget {
  const _ThumbnailPreview({required this.media});

  final DuplicateMediaItem media;

  @override
  Widget build(BuildContext context) {
    final mediaFile = File(media.media.path);
    final size = UiSizing.iconHuge;
    if (media.media.type == MediaType.image && mediaFile.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(UiSizing.borderRadiusSmall),
        child: Image.file(
          mediaFile,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackIcon(context),
        ),
      );
    }

    final icon = switch (media.media.type) {
      MediaType.video => Icons.videocam,
      MediaType.text => Icons.description,
      _ => Icons.insert_drive_file,
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(UiSizing.borderRadiusSmall),
      ),
      child: Icon(icon),
    );
  }

  Widget _fallbackIcon(BuildContext context) {
    return Container(
      width: UiSizing.iconHuge,
      height: UiSizing.iconHuge,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(UiSizing.borderRadiusSmall),
      ),
      child: const Icon(Icons.insert_drive_file),
    );
  }
}
