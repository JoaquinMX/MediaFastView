import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tag_entity.dart';
import '../states/tag_state.dart';
import '../view_models/tag_management_view_model.dart';
import 'tag_chip.dart';

/// Bottom sheet that lets users assign a shared set of tags to a collection
/// of items without covering the entire screen.
class BulkTagAssignmentSheet extends ConsumerStatefulWidget {
  const BulkTagAssignmentSheet({
    super.key,
    required this.title,
    required this.description,
    required this.initialTagIds,
    required this.onTagsAssigned,
  });

  /// Title displayed at the top of the sheet.
  final String title;

  /// Descriptive helper text that explains how the assignment behaves.
  final String description;

  /// Tag IDs that should be pre-selected when the sheet opens.
  final List<String> initialTagIds;

  /// Callback invoked when the user confirms their selection.
  final Future<void> Function(List<String> tagIds) onTagsAssigned;

  /// Shows the bottom sheet and returns true when the selection was saved.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String description,
    List<String> initialTagIds = const <String>[],
    required Future<void> Function(List<String> tagIds) onTagsAssigned,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: BulkTagAssignmentSheet(
          title: title,
          description: description,
          initialTagIds: initialTagIds,
          onTagsAssigned: onTagsAssigned,
        ),
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<BulkTagAssignmentSheet> createState() =>
      _BulkTagAssignmentSheetState();
}

class _BulkTagAssignmentSheetState
    extends ConsumerState<BulkTagAssignmentSheet> {
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
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Material(
          color: theme.colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              const SizedBox(height: 12),
              _DragHandle(color: theme.colorScheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: switch (tagState) {
                    TagLoaded(:final tags) => _buildTagSelection(context, tags),
                    TagLoading() => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    TagError(:final message) => Center(
                        child: Text(
                          'Error: $message',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    TagEmpty() => _buildEmptyState(context),
                  },
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagSelection(BuildContext context, List<TagEntity> tags) {
    if (tags.isEmpty) {
      return _buildEmptyState(context);
    }

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
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
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
          Text('No tags available', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Create tags first to assign them to selected items.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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

class _DragHandle extends StatelessWidget {
  const _DragHandle({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(2)),
      ),
    );
  }
}
