import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/widgets/tag_selection_dialog.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../domain/entities/tag_entity.dart';
import '../../domain/use_cases/assign_tag_use_case.dart';
import '../view_models/tag_management_view_model.dart';
import '../view_models/tags_view_model.dart';
import 'tag_creation_dialog.dart';

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
              if (media!.type == MediaType.directory) {
                await assignTagUseCase.toggleTagOnDirectory(media!.id, tag);
              } else {
                await assignTagUseCase.toggleTagOnMedia(media!.id, tag);
              }
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
          ? (context, tag) => _confirmDeleteTag(context, tag, tagViewModel)
          : null,
      emptyStateBuilder: (context) => _buildEmptyState(context, media != null),
    );
  }

  static Future<void> _confirmDeleteTag(
    BuildContext context,
    TagEntity tag,
    TagManagementViewModel tagViewModel,
  ) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag'),
        content: Text(
          'Are you sure you want to delete "${tag.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              tagViewModel.deleteTag(tag.id);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
