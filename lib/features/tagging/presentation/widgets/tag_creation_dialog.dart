import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the provider alive during the dialog lifecycle
    ref.watch(tagViewModelProvider);
    final tagViewModel = ref.read(tagViewModelProvider.notifier);

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
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Tag name is required';
                }
                if (value.trim().length < 2) {
                  return 'Tag name must be at least 2 characters';
                }
                if (tagViewModel.tagNameExists(value.trim())) {
                  return 'A tag with this name already exists';
                }
                return null;
              },
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => _createTag(context, tagViewModel),
          child: const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createTag(BuildContext context, TagViewModel tagViewModel) async {
    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameController.text.trim();
      await tagViewModel.createTag(name, _selectedColor);

      // Delay UI operations to avoid device update conflicts
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag "$name" created successfully'),
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.of(context).pop();
      });
    }
  }
}
