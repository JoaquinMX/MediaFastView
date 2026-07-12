import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/tag_cache_refresher.dart';
import '../../domain/entities/tag_entity.dart';
import '../../domain/tag_validation.dart';
import '../view_models/tag_management_view_model.dart';
import 'tag_color_picker.dart';

/// A dialog for renaming a tag and changing its colour.
///
/// The tag keeps its id, so every media item stays tagged — an edit rewrites one
/// row and nothing else.
class TagEditDialog extends ConsumerStatefulWidget {
  const TagEditDialog({super.key, required this.tag});

  final TagEntity tag;

  static Future<void> show(BuildContext context, TagEntity tag) {
    return showDialog(
      context: context,
      builder: (context) => TagEditDialog(tag: tag),
    );
  }

  @override
  ConsumerState<TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends ConsumerState<TagEditDialog> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();
  late int _selectedColor;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tag.name);
    // Seeded from the tag even if it is not one of the picker's swatches: a
    // stored colour need not come from the palette, and snapping it to a default
    // would silently change a colour the user never touched.
    _selectedColor = widget.tag.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the provider alive during the dialog lifecycle.
    ref.watch(tagViewModelProvider);
    final tagViewModel = ref.read(tagViewModelProvider.notifier);
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Edit Tag'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tag Name',
                hintText: 'Enter tag name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => _validateName(value, tagViewModel),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 24),
            TagColorPicker(
              selectedColor: _selectedColor,
              onColorSelected: (color) {
                setState(() {
                  _selectedColor = color;
                });
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
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
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : () => _saveTag(tagViewModel),
          child: const Text('Save'),
        ),
      ],
    );
  }

  String? _validateName(String? value, TagViewModel tagViewModel) {
    final name = value?.trim() ?? '';

    try {
      validateTagName(name);
    } on TagValidationException catch (error) {
      return error.message;
    }

    // Excluding this tag is what lets an unchanged name — or a case-only fix —
    // through, instead of colliding with the tag's own row.
    if (tagViewModel.tagNameExists(name, excludingId: widget.tag.id)) {
      return 'A tag with this name already exists';
    }

    return null;
  }

  Future<void> _saveTag(TagViewModel tagViewModel) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final refresher = ref.read(tagCacheRefresherProvider);
    final name = _nameController.text.trim();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await tagViewModel.updateTag(
        widget.tag,
        name: name,
        color: _selectedColor,
      );
    } on TagValidationException catch (error) {
      // The form validator should have caught this; the use case is the
      // authority, so surface whatever it says rather than failing silently.
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = error.message;
        });
      }
      return;
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to update tag: $error';
        });
      }
      return;
    }

    // Every surface that shows a tag name or colour reads from a cache of some
    // kind, including the app-lifetime TagLookup behind the full-screen and
    // slideshow overlays. Without this they keep the old name until restart.
    await refresher.refresh();

    messenger.showSnackBar(
      SnackBar(
        content: Text('Tag "$name" updated'),
        duration: const Duration(seconds: 2),
      ),
    );
    navigator.pop();
  }
}
