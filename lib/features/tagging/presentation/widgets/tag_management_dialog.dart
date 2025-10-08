import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/media_library/domain/entities/media_entity.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../domain/entities/tag_entity.dart';
import '../../domain/use_cases/assign_tag_use_case.dart';
import '../view_models/tags_view_model.dart';
import '../states/tag_state.dart';
import '../view_models/tag_management_view_model.dart';
import 'tag_chip.dart';
import 'tag_creation_dialog.dart';

/// A dialog for managing tags - viewing, adding, and removing tags.
/// Shows all existing tags with options to delete them and add new ones.
/// If a media item is provided, allows assigning/removing tags from that item.
class TagManagementDialog extends ConsumerStatefulWidget {
  const TagManagementDialog({super.key, this.media});

  final MediaEntity? media;

  static Future<void> show(BuildContext context, {MediaEntity? media}) {
    return showDialog(
      context: context,
      builder: (context) => TagManagementDialog(media: media),
    );
  }

  @override
  ConsumerState<TagManagementDialog> createState() => _TagManagementDialogState();
}

class _TagManagementDialogState extends ConsumerState<TagManagementDialog> {
  late Future<List<String>> _assignedTagIdsFuture;
  List<String> _assignedTagIds = <String>[];
  bool _hasLoadedInitialAssignments = false;

  @override
  void initState() {
    super.initState();
    _assignedTagIdsFuture = _loadInitialAssignedTagIds();
  }

  @override
  void didUpdateWidget(covariant TagManagementDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media?.id != widget.media?.id) {
      setState(() {
        _hasLoadedInitialAssignments = false;
        _assignedTagIdsFuture = _loadInitialAssignedTagIds();
      });
    }
  }

  Future<List<String>> _loadInitialAssignedTagIds() async {
    if (widget.media == null) {
      _assignedTagIds = <String>[];
      _hasLoadedInitialAssignments = true;
      return const <String>[];
    }

    final repository = ref.read(mediaRepositoryProvider);
    final media = await repository.getMediaById(widget.media!.id);
    final ids = media?.tagIds ?? <String>[];
    _assignedTagIds = List<String>.from(ids);
    _hasLoadedInitialAssignments = true;
    return _assignedTagIds;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _assignedTagIdsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_hasLoadedInitialAssignments) {
          return const AlertDialog(
            title: Text('Loading...'),
            content: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to load current tags: ${snapshot.error}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        }

        final tagState = ref.watch(tagViewModelProvider);
        final tagViewModel = ref.read(tagViewModelProvider.notifier);
        final assignTagUseCase = ref.read(assignTagUseCaseProvider);

        return AlertDialog(
          title: Text(widget.media != null ? 'Assign Tags' : 'Manage Tags'),
          content: SizedBox(
            width: double.maxFinite,
            child: switch (tagState) {
              TagLoaded(:final tags) =>
                  _buildContent(context, tags, tagViewModel, assignTagUseCase),
              TagLoading() => const Center(child: CircularProgressIndicator()),
              TagError(:final message) => Center(
                child: Text(
                  'Error: $message',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              TagEmpty() => _buildEmptyState(context),
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<TagEntity> tags,
    TagViewModel tagViewModel,
    AssignTagUseCase assignTagUseCase,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.media != null)
          Text(
            'Assign tags to "${widget.media!.name}"',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          Row(
            children: [
              const Text('Tags', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showCreateTagDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Tag'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        if (tags.isEmpty)
          _buildEmptyState(context)
        else
          Flexible(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map(
                    (tag) => widget.media != null
                        ? TagChip(
                            tag: tag,
                            selected: _assignedTagIds.contains(tag.id),
                            onTap: () => _toggleTagAssignment(tag, assignTagUseCase),
                          )
                        : TagChip(
                            tag: tag,
                            showDeleteIcon: true,
                            onDeleted: () =>
                                _confirmDeleteTag(context, tag, tagViewModel),
                          ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.tag,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text('No tags yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            widget.media != null
                ? 'Create tags first to assign them to this item'
                : 'Create your first tag to organize your content',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (widget.media == null)
            ElevatedButton.icon(
              onPressed: () => _showCreateTagDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Tag'),
            ),
        ],
      ),
    );
  }

  void _showCreateTagDialog(BuildContext context) {
    TagCreationDialog.show(context);
  }

  void _confirmDeleteTag(
    BuildContext context,
    TagEntity tag,
    TagViewModel tagViewModel,
  ) {
    showDialog(
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
              Navigator.of(context).pop(); // Close confirmation dialog
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

  void _toggleTagAssignment(TagEntity tag, AssignTagUseCase assignTagUseCase) async {
    if (widget.media == null) return;

    setState(() {
      if (_assignedTagIds.contains(tag.id)) {
        _assignedTagIds.remove(tag.id);
      } else {
        _assignedTagIds.add(tag.id);
      }
    });

    try {
      if (widget.media!.type == MediaType.directory) {
        await assignTagUseCase.toggleTagOnDirectory(widget.media!.id, tag);
      } else {
        await assignTagUseCase.toggleTagOnMedia(widget.media!.id, tag);
      }
      await ref.read(tagsViewModelProvider.notifier).refreshTags();
    } catch (e) {
      // Revert on error
      setState(() {
        if (_assignedTagIds.contains(tag.id)) {
          _assignedTagIds.remove(tag.id);
        } else {
          _assignedTagIds.add(tag.id);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update tag: $e')),
        );
      }
    }
  }
}
