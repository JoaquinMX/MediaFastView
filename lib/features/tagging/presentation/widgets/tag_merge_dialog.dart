import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/utils/tag_cache_refresher.dart';
import '../../domain/entities/tag_entity.dart';
import '../../domain/entities/tag_usage.dart';
import '../../domain/tag_validation.dart';
import '../../domain/use_cases/merge_tags_use_case.dart';
import '../states/tag_state.dart';
import '../view_models/tag_management_view_model.dart';

/// Folds [source] into another tag: everything carrying it ends up carrying the
/// tag you pick instead, and [source] is deleted.
///
/// The direction is fixed and stated everywhere: the tag you opened this from is
/// the one that disappears. Merging is irreversible, so it confirms first.
class TagMergeDialog extends ConsumerStatefulWidget {
  const TagMergeDialog({super.key, required this.source});

  final TagEntity source;

  static Future<void> show(BuildContext context, TagEntity source) {
    return showDialog(
      context: context,
      builder: (context) => TagMergeDialog(source: source),
    );
  }

  @override
  ConsumerState<TagMergeDialog> createState() => _TagMergeDialogState();
}

class _TagMergeDialogState extends ConsumerState<TagMergeDialog> {
  TagEntity? _target;
  String? _errorMessage;
  bool _isMerging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(tagViewModelProvider);
    final usage = ref.watch(tagUsageProvider).valueOrNull;

    final candidates = switch (state) {
      TagLoaded(:final tags) =>
        tags.where((tag) => tag.id != widget.source.id).toList(),
      _ => const <TagEntity>[],
    };

    final target = _target;

    return AlertDialog(
      title: Text('Merge "${widget.source.name}" into…'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final tag in candidates)
                      ListTile(
                        key: ValueKey<String>('merge_target_${tag.id}'),
                        selected: target?.id == tag.id,
                        selectedTileColor:
                            theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.4,
                        ),
                        onTap: _isMerging
                            ? null
                            : () => setState(() => _target = tag),
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: Color(tag.color),
                        ),
                        title: Text(tag.name),
                        subtitle: _usageLabel(theme, usage?[tag.id]),
                        trailing: target?.id == tag.id
                            ? Icon(Icons.check, color: theme.colorScheme.primary)
                            : null,
                      ),
                  ],
                ),
              ),
            ),
            if (target != null) ...[
              const SizedBox(height: 12),
              Text(
                _describeConsequences(target, usage?[widget.source.id]),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isMerging ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: target == null || _isMerging ? null : () => _merge(target),
          child: const Text('Merge'),
        ),
      ],
    );
  }

  Widget? _usageLabel(ThemeData theme, TagUsage? usage) {
    if (usage == null) {
      return null;
    }
    return Text(
      usage.isUnused ? 'Unused' : usage.describe(),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// Spells out both halves of the trade before it happens.
  String _describeConsequences(TagEntity target, TagUsage? sourceUsage) {
    final moved = sourceUsage == null || sourceUsage.isUnused
        ? 'Nothing'
        : sourceUsage.describe();
    return '$moved will move to "${target.name}". '
        '"${widget.source.name}" will be deleted. This cannot be undone.';
  }

  Future<void> _merge(TagEntity target) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final mergeTags = ref.read(mergeTagsUseCaseProvider);
    final refresher = ref.read(tagCacheRefresherProvider);

    setState(() {
      _isMerging = true;
      _errorMessage = null;
    });

    final TagMergeResult result;
    try {
      result = await mergeTags(source: widget.source, target: target);
    } on TagValidationException catch (error) {
      if (mounted) {
        setState(() {
          _isMerging = false;
          _errorMessage = error.message;
        });
      }
      return;
    } catch (error) {
      if (mounted) {
        setState(() {
          _isMerging = false;
          _errorMessage = 'Failed to merge tags: $error';
        });
      }
      return;
    }

    // The source tag is deliberately left alive when anything failed, so the
    // merge can just be run again. Say so rather than reporting success.
    if (result.hasFailures) {
      if (mounted) {
        setState(() {
          _isMerging = false;
          _errorMessage =
              '${result.failureReasons.length} item(s) could not be updated, so '
              '"${widget.source.name}" was kept. Try again.';
        });
      }
      return;
    }

    await refresher.refresh();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Merged "${widget.source.name}" into "${target.name}" '
          '(${result.itemsMoved} item${result.itemsMoved == 1 ? '' : 's'} moved)',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    navigator.pop();
  }
}
