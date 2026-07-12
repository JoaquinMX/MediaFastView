import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/tag_cache_refresher.dart';
import '../../domain/tag_validation.dart';
import '../view_models/tag_management_view_model.dart';
import 'tag_color_picker.dart';

/// A dialog for creating new tags.
/// Allows users to enter a tag name and select a color.
class TagCreationDialog extends ConsumerStatefulWidget {
  const TagCreationDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const TagCreationDialog(),
    );
  }

  @override
  ConsumerState<TagCreationDialog> createState() => _TagCreationDialogState();
}

class _TagCreationDialogState extends ConsumerState<TagCreationDialog> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _selectedColor = 0xFF2196F3; // Default blue color
  String? _errorMessage;
  bool _isSaving = false;

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
      title: const Text('Create New Tag'),
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
          onPressed: _isSaving ? null : () => _createTag(tagViewModel),
          child: const Text('Create'),
        ),
      ],
    );
  }

  /// The same rules the domain enforces, run early so the field can show them
  /// inline. `CreateTagUseCase` remains the authority — this only saves the user
  /// a round trip.
  String? _validateName(String? value, TagViewModel tagViewModel) {
    final name = value?.trim() ?? '';

    try {
      validateTagName(name);
    } on TagValidationException catch (error) {
      return error.message;
    }

    if (tagViewModel.tagNameExists(name)) {
      return 'A tag with this name already exists';
    }

    return null;
  }

  Future<void> _createTag(TagViewModel tagViewModel) async {
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
      await tagViewModel.createTag(name, _selectedColor);
    } on TagValidationException catch (error) {
      // The field validator should have caught this, but the use case is the
      // authority — surface whatever it says rather than failing silently.
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
          _errorMessage = 'Failed to create tag: $error';
        });
      }
      return;
    }

    // Creation used to refresh nothing at all, so a new tag was invisible to the
    // usage counts and to TagLookup until something else happened to invalidate
    // them.
    await refresher.refresh();

    messenger.showSnackBar(
      SnackBar(
        content: Text('Tag "$name" created successfully'),
        duration: const Duration(seconds: 2),
      ),
    );
    navigator.pop();
  }
}
