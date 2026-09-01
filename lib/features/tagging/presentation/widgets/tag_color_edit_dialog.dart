import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/tag_cache_refresher.dart';
import '../view_models/tag_management_view_model.dart';
import 'tag_color_picker.dart';
import '../../domain/entities/tag_entity.dart';

/// Dialog for updating the color of an existing tag.
class TagColorEditDialog extends ConsumerStatefulWidget {
  const TagColorEditDialog({
    super.key,
    required this.tag,
  });

  final TagEntity tag;

  static Future<bool?> show(BuildContext context, {required TagEntity tag}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => TagColorEditDialog(tag: tag),
    );
  }

  @override
  ConsumerState<TagColorEditDialog> createState() => _TagColorEditDialogState();
}

class _TagColorEditDialogState extends ConsumerState<TagColorEditDialog> {
  late int _selectedColor = widget.tag.color;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Edit "${widget.tag.name}" color'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adjust the color used for this tag and any shortcut assignments.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TagColorPicker(
              selectedColor: _selectedColor,
              onColorSelected: (color) => setState(() {
                _selectedColor = color;
              }),
            ),
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
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_selectedColor == widget.tag.color) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updatedTag = widget.tag.copyWith(color: _selectedColor);
      await ref.read(tagViewModelProvider.notifier).updateTag(updatedTag);
      await ref.read(tagCacheRefresherProvider).refresh();

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
        _errorMessage = 'Failed to update tag color: $error';
      });
    }
  }
}
