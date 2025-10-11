import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tag_entity.dart';
import '../states/tag_state.dart';
import '../view_models/tag_management_view_model.dart';
import 'tag_chip.dart';

/// Dialog that lets users assign a shared set of tags to a collection of items.
class BulkTagAssignmentDialog extends ConsumerStatefulWidget {
  const BulkTagAssignmentDialog({
    super.key,
    required this.title,
    required this.description,
    required this.initialTagIds,
    required this.onTagsAssigned,
  });

  /// Title displayed in the dialog header.
  final String title;

  /// Descriptive helper text that explains how the assignment behaves.
  final String description;

  /// Tag IDs that should be pre-selected when the dialog opens.
  final List<String> initialTagIds;

  /// Callback invoked when the user confirms their selection.
  final Future<void> Function(List<String> tagIds) onTagsAssigned;

  /// Shows the dialog and returns true when the selection was saved.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String description,
    List<String> initialTagIds = const <String>[],
    required Future<void> Function(List<String> tagIds) onTagsAssigned,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => BulkTagAssignmentDialog(
        title: title,
        description: description,
        initialTagIds: initialTagIds,
        onTagsAssigned: onTagsAssigned,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<BulkTagAssignmentDialog> createState() =>
      _BulkTagAssignmentDialogState();
}

class _BulkTagAssignmentDialogState
    extends ConsumerState<BulkTagAssignmentDialog> {
  late final List<String> _tempSelectedTagIds;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tempSelectedTagIds = List<String>.from(widget.initialTagIds);
  }

  @override
  Widget build(BuildContext context) {
    final tagState = ref.watch(tagViewModelProvider);

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: switch (tagState) {
          TagLoaded(:final tags) => _buildContent(context, tags),
          TagLoading() => const Center(child: CircularProgressIndicator()),
          TagError(:final message) => Center(
              child: Text(
                'Error: $message',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TagEmpty() => _buildEmptyState(context),
        },
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving
              ? null
              : () async {
                  setState(() {
                    _isSaving = true;
                    _errorMessage = null;
                  });
                  try {
                    await widget.onTagsAssigned(
                      List<String>.from(_tempSelectedTagIds),
                    );
                    if (!mounted) {
                      return;
                    }
                    Navigator.of(context).pop(true);
                  } catch (error) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _isSaving = false;
                      _errorMessage = 'Failed to save tags: $error';
                    });
                  }
                },
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Apply Tags'),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, List<TagEntity> tags) {
    final availableHeight = MediaQuery.of(context).size.height;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: availableHeight * 0.5,
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags
                    .map(
                      (tag) => TagChip(
                        tag: tag,
                        selected: _tempSelectedTagIds.contains(tag.id),
                        onTap: () => _toggleTagSelection(tag.id),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
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
          Text('No tags available', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Create tags first to assign them to selected items.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _toggleTagSelection(String tagId) {
    if (_isSaving) {
      return;
    }
    setState(() {
      if (_tempSelectedTagIds.contains(tagId)) {
        _tempSelectedTagIds.remove(tagId);
      } else {
        _tempSelectedTagIds.add(tagId);
      }
    });
  }
}
