import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/utils/tag_cache_refresher.dart';
import '../../../../shared/widgets/tag_selection_dialog.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../domain/entities/tag_entity.dart';
import '../../domain/entities/tag_usage.dart';
import '../../domain/use_cases/assign_tag_use_case.dart';
import '../view_models/tag_management_view_model.dart';
import '../view_models/tags_view_model.dart';
import 'tag_creation_dialog.dart';
import 'tag_edit_dialog.dart';
import 'tag_merge_dialog.dart';

/// A dialog for managing tags - viewing, adding, removing, and assigning.
class TagManagementDialog extends ConsumerWidget {
  const TagManagementDialog({super.key, this.media});

  final MediaEntity? media;

  static Future<void> show(BuildContext context, {MediaEntity? media}) {
    return showDialog(
      context: context,
      builder: (context) => TagManagementDialog(media: media),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignTagUseCase = ref.read(assignTagUseCaseProvider);
    final tagsNotifier = ref.read(tagsViewModelProvider.notifier);
    final tagViewModel = ref.read(tagViewModelProvider.notifier);
    final mediaRepository = ref.read(mediaRepositoryProvider);

    return TagSelectionDialog<void>(
      title: media != null ? 'Assign Tags' : 'Manage Tags',
      assignmentTargetLabel: media != null
          ? 'Assign tags to "${media!.name}"'
          : null,
      loadInitialSelection: media != null
          ? () async {
              final fetched = await mediaRepository.getMediaById(media!.id);
              return fetched?.tagIds ?? <String>[];
            }
          : null,
      initialSelectedTagIds:
          media == null ? const <String>[] : media!.tagIds,
      onTagToggle: media == null
          ? null
          : (TagEntity tag, bool isSelected) async {
              // Directory entries surfaced within the media grid are persisted as media
              // items, so ensure their tag assignments are updated through the media
              // repository. Updating via the directory repository would miss these
              // nested directories, causing the new tag to be lost on reload.
              await assignTagUseCase.toggleTagOnMedia(media!.id, tag);
              await tagsNotifier.refreshTags();
            },
      showCancelButton: true,
      cancelLabel: 'Close',
      showConfirmButton: false,
      showCreateButton: media == null,
      onCreateTag: media == null
          ? (context) => TagCreationDialog.show(context)
          : null,
      showDeleteButtons: media == null,
      onDeleteTag: media == null
          ? (context, tag) => _confirmDeleteTag(context, ref, tag, tagViewModel)
          : null,
      showEditButtons: media == null,
      onEditTag: media == null
          ? (context, tag) => TagEditDialog.show(context, tag)
          : null,
      showMergeButtons: media == null,
      onMergeTag: media == null
          ? (context, tag) => TagMergeDialog.show(context, tag)
          : null,
      emptyStateBuilder: (context) => _buildEmptyState(context, media != null),
    );
  }

  static Future<void> _confirmDeleteTag(
    BuildContext context,
    WidgetRef ref,
    TagEntity tag,
    TagViewModel tagViewModel,
  ) async {
    final refresher = ref.read(tagCacheRefresherProvider);
    final usage = ref.read(tagUsageProvider).valueOrNull?[tag.id];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag'),
        content: Text(_describeDeletion(tag, usage)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await tagViewModel.deleteTag(tag.id);
    await refresher.refresh();
  }

  /// Names the blast radius before the user commits to it.
  ///
  /// The old copy said only "this cannot be undone", which left the important
  /// part ambiguous: deleting a tag untags things, it does not delete them.
  static String _describeDeletion(TagEntity tag, TagUsage? usage) {
    if (usage == null || usage.isUnused) {
      return 'Delete "${tag.name}"? Nothing is using it. '
          'This cannot be undone.';
    }

    return 'Delete "${tag.name}"? It is on ${usage.describe()}, which will lose '
        'this tag but keep their others. The files themselves are not deleted. '
        'This cannot be undone.';
  }

  static Widget _buildEmptyState(BuildContext context, bool forAssignment) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.tag,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text('No tags yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            forAssignment
                ? 'Create tags first to assign them to this item'
                : 'Create your first tag to organize your content',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (!forAssignment) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => TagCreationDialog.show(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Tag'),
            ),
          ],
        ],
      ),
    );
  }
}
