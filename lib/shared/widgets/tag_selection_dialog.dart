import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/tagging/domain/entities/tag_entity.dart';
import '../../features/tagging/presentation/states/tag_state.dart';
import '../../features/tagging/presentation/view_models/tag_management_view_model.dart';
import '../../features/tagging/presentation/widgets/tag_chip.dart';

typedef TagToggleCallback = Future<void> Function(TagEntity tag, bool isSelected);
typedef TagDeletionCallback = Future<void> Function(BuildContext context, TagEntity tag);
typedef TagCreationCallback = Future<void> Function(BuildContext context);
typedef TagSelectionConfirmCallback<T> = Future<T?> Function(List<String> tagIds);
typedef TagSelectionLoader = Future<List<String>> Function();
typedef TagLongPressCallback = Future<void> Function(TagEntity tag);

/// A flexible dialog for selecting and managing tags across multiple flows.
///
/// The dialog centralises tag fetching, loading/error/empty states, chip grids
/// and confirmation logic so feature flows only need to supply the behaviour
/// differences (copy, destructive actions, etc.).
class TagSelectionDialog<T> extends ConsumerStatefulWidget {
  const TagSelectionDialog({
    super.key,
    required this.title,
    this.description,
    this.initialSelectedTagIds = const <String>[],
    this.loadInitialSelection,
    this.assignmentTargetLabel,
    this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.showCancelButton = true,
    this.showConfirmButton,
    this.onConfirm,
    this.cancelResult,
    this.onSelectionChanged,
    this.onTagToggle,
    this.onTagLongPress,
    this.onDeleteTag,
    this.onCreateTag,
    this.showCreateButton = false,
    this.showDeleteButtons = false,
    this.selectionLimit,
    this.selectionLimitMessage,
    this.showAllOption = false,
    this.allOptionLabel = 'All',
    this.emptyStateBuilder,
    this.popOnConfirm = true,
  });

  /// Title displayed in the dialog header.
  final String title;

  /// Optional descriptive helper text.
  final String? description;

  /// Optional text describing the assignment target ("Assign to <name>").
  final String? assignmentTargetLabel;

  /// Pre-selected tag ids when no [loadInitialSelection] is provided.
  final List<String> initialSelectedTagIds;

  /// Lazy loader for fetching the initial selection when it depends on IO.
  final TagSelectionLoader? loadInitialSelection;

  /// Callback invoked when the confirm button is pressed.
  final TagSelectionConfirmCallback<T>? onConfirm;

  /// Called every time the in-memory selection changes.
  final ValueChanged<List<String>>? onSelectionChanged;

  /// Invoked when a tag is toggled. Used for immediate persistence flows.
  final TagToggleCallback? onTagToggle;

  /// Callback invoked when a tag chip is long-pressed.
  final TagLongPressCallback? onTagLongPress;

  /// Callback that is invoked when the delete icon on a tag is pressed.
  final TagDeletionCallback? onDeleteTag;

  /// Callback to open a creation experience for tags.
  final TagCreationCallback? onCreateTag;

  /// Label for the confirmation button. Defaults to `Save` when [onConfirm]
  /// is provided.
  final String? confirmLabel;

  /// Label for the cancel/close button.
  final String cancelLabel;

  /// Whether to show the cancel button. Defaults to true.
  final bool showCancelButton;

  /// Whether to show the confirm button. Defaults to [onConfirm] != null.
  final bool? showConfirmButton;

  /// Value returned when the dialog is closed via cancel/back.
  final T? cancelResult;

  /// Whether destructive actions (delete icons) should be displayed.
  final bool showDeleteButtons;

  /// Whether the "Create tag" button should be shown.
  final bool showCreateButton;

  /// Selection limit, if any.
  final int? selectionLimit;

  /// Message shown when attempting to exceed [selectionLimit].
  final String? selectionLimitMessage;

  /// Adds an "All" option that clears the selection when tapped.
  final bool showAllOption;

  /// Label used for the "All" option when [showAllOption] is true.
  final String allOptionLabel;

  /// Builds a custom empty state for when no tags are available.
  final WidgetBuilder? emptyStateBuilder;

  /// Controls whether the dialog should pop automatically after confirm.
  final bool popOnConfirm;

  @override
  ConsumerState<TagSelectionDialog<T>> createState() =>
      _TagSelectionDialogState<T>();
}

class _TagSelectionDialogState<T>
    extends ConsumerState<TagSelectionDialog<T>> {
  static const String _allOptionId = '__tag_selection_all__';

  late List<String> _selectedTagIds;
  Future<List<String>>? _initialSelectionFuture;
  bool _initialisedFromFuture = false;
  bool _isProcessing = false;
  String? _errorMessage;
  final Set<String> _inFlightTagIds = <String>{};

  @override
  void initState() {
    super.initState();
    _selectedTagIds = List<String>.from(widget.initialSelectedTagIds);
    if (widget.loadInitialSelection != null) {
      _initialSelectionFuture = widget.loadInitialSelection!().then((value) {
        _selectedTagIds = List<String>.from(value);
        _initialisedFromFuture = true;
        widget.onSelectionChanged?.call(List<String>.from(_selectedTagIds));
        return _selectedTagIds;
      });
    } else {
      _initialisedFromFuture = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialSelectionFuture != null && !_initialisedFromFuture) {
      return FutureBuilder<List<String>>(
        future: _initialSelectionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              title: Text('Loading...'),
              content: SizedBox(
                height: 64,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (snapshot.hasError) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to load current tags: ${snapshot.error}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(widget.cancelResult),
                  child: const Text('Close'),
                ),
              ],
            );
          }

          _initialisedFromFuture = true;
          return _buildDialog(context);
        },
      );
    }

    return _buildDialog(context);
  }

  Widget _buildDialog(BuildContext context) {
    final tagState = ref.watch(tagViewModelProvider);
    final bool showConfirmButton =
        widget.showConfirmButton ?? widget.onConfirm != null;

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
          TagEmpty() => widget.emptyStateBuilder?.call(context) ??
              _buildDefaultEmptyState(context),
        },
      ),
      actions: [
        if (widget.showCancelButton)
          TextButton(
            onPressed: _isProcessing
                ? null
                : () => Navigator.of(context).pop(widget.cancelResult),
            child: Text(widget.cancelLabel),
          ),
        if (showConfirmButton)
          FilledButton(
            onPressed: _isProcessing || widget.onConfirm == null
                ? null
                : () => _handleConfirm(context),
            child: _isProcessing
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.confirmLabel ?? 'Save'),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, List<TagEntity> tags) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.assignmentTargetLabel != null) ...[
          Text(
            widget.assignmentTargetLabel!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (widget.description != null)
          Text(
            widget.description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (widget.showCreateButton)
          Padding(
            padding: EdgeInsets.only(
              top: widget.assignmentTargetLabel != null ||
                      widget.description != null
                  ? 16
                  : 0,
            ),
            child: Row(
              children: [
                const Text(
                  'Tags',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: widget.onCreateTag == null
                      ? null
                      : () => widget.onCreateTag!(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Tag'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (tags.isEmpty)
          widget.emptyStateBuilder?.call(context) ??
              _buildDefaultEmptyState(context)
        else
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.showAllOption)
                    TagChip(
                      tag: TagEntity(
                        id: _allOptionId,
                        name: widget.allOptionLabel,
                        color: theme.colorScheme.outline.value,
                        createdAt: DateTime.now(),
                      ),
                      selected: _selectedTagIds.isEmpty,
                      onTap: _handleAllOptionSelected,
                    ),
                  ...tags.map(
                    (tag) => TagChip(
                      tag: tag,
                      selected: _selectedTagIds.contains(tag.id),
                      onTap: () => _handleTagTapped(context, tag),
                      onLongPress: widget.onTagLongPress == null
                          ? null
                          : () => widget.onTagLongPress!(tag),
                      showDeleteIcon: widget.showDeleteButtons,
                      onDeleted: widget.showDeleteButtons
                          ? () => widget.onDeleteTag?.call(context, tag)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildDefaultEmptyState(BuildContext context) {
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
        ],
      ),
    );
  }

  Future<void> _handleConfirm(BuildContext context) async {
    if (widget.onConfirm == null) {
      if (widget.popOnConfirm) {
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.onConfirm!(List<String>.from(_selectedTagIds));
      if (!mounted) {
        return;
      }
      if (widget.popOnConfirm) {
        Navigator.of(context).pop(result);
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Failed to save tags: $error';
      });
    }
  }

  void _handleAllOptionSelected() {
    if (_selectedTagIds.isEmpty) {
      return;
    }
    setState(() {
      _selectedTagIds.clear();
      _errorMessage = null;
    });
    widget.onSelectionChanged?.call(List<String>.from(_selectedTagIds));
  }

  Future<void> _handleTagTapped(BuildContext context, TagEntity tag) async {
    if (_isProcessing || _inFlightTagIds.contains(tag.id)) {
      return;
    }

    final bool wasSelected = _selectedTagIds.contains(tag.id);

    if (!wasSelected &&
        widget.selectionLimit != null &&
        _selectedTagIds.length >= widget.selectionLimit!) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      final message =
          widget.selectionLimitMessage ?? 'You can only select ${widget.selectionLimit} tags.';
      messenger?.showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    setState(() {
      _errorMessage = null;
      if (wasSelected) {
        _selectedTagIds.remove(tag.id);
      } else {
        _selectedTagIds.add(tag.id);
      }
    });
    widget.onSelectionChanged?.call(List<String>.from(_selectedTagIds));

    if (widget.onTagToggle == null) {
      return;
    }

    setState(() {
      _inFlightTagIds.add(tag.id);
    });

    try {
      await widget.onTagToggle!(tag, !wasSelected);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        // revert
        if (wasSelected) {
          _selectedTagIds.add(tag.id);
        } else {
          _selectedTagIds.remove(tag.id);
        }
        _errorMessage = 'Failed to update tag: $error';
      });
      widget.onSelectionChanged?.call(List<String>.from(_selectedTagIds));
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Failed to update tag: $error')),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _inFlightTagIds.remove(tag.id);
      });
    }
  }
}
