import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/repository_providers.dart';
import '../../domain/entities/saved_filter_entity.dart';
import '../../domain/saved_filter_validation.dart';
import '../../domain/tag_validation.dart';

/// Names and saves the current Tags-tab query.
///
/// Pass [existing] to rename or update a filter in place; omit it to create a
/// new one.
class SaveFilterDialog extends ConsumerStatefulWidget {
  const SaveFilterDialog({
    super.key,
    required this.definition,
    this.existing,
  });

  final SavedFilterDefinition definition;
  final SavedFilterEntity? existing;

  /// Returns the saved filter, or null if the user cancelled.
  static Future<SavedFilterEntity?> show(
    BuildContext context, {
    required SavedFilterDefinition definition,
    SavedFilterEntity? existing,
  }) {
    return showDialog<SavedFilterEntity>(
      context: context,
      builder: (context) => SaveFilterDialog(
        definition: definition,
        existing: existing,
      ),
    );
  }

  @override
  ConsumerState<SaveFilterDialog> createState() => _SaveFilterDialogState();
}

class _SaveFilterDialogState extends ConsumerState<SaveFilterDialog> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;
  bool _isSaving = false;

  bool get _isRename => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_isRename ? 'Rename filter' : 'Save filter'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Filter name',
                hintText: 'e.g. Trips 2024',
                border: OutlineInputBorder(),
              ),
              validator: _validateName,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
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
          onPressed: _isSaving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';

    try {
      validateSavedFilterName(name);
    } on TagValidationException catch (error) {
      return error.message;
    }

    // The use case is the authority; this only saves the user a round trip.
    final filters = ref.read(savedFiltersProvider).valueOrNull ?? const [];
    if (isSavedFilterNameTaken(
      name,
      filters,
      excludingId: widget.existing?.id,
    )) {
      return 'A filter with this name already exists';
    }

    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final navigator = Navigator.of(context);
    final saveFilter = ref.read(saveFilterUseCaseProvider);
    final name = _nameController.text.trim();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final SavedFilterEntity saved;
    try {
      saved = await saveFilter(
        name: name,
        // A rename keeps whatever the filter already matched; only the name
        // changes.
        definition: widget.existing?.definition ?? widget.definition,
        existingId: widget.existing?.id,
      );
    } on TagValidationException catch (error) {
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
          _errorMessage = 'Failed to save filter: $error';
        });
      }
      return;
    }

    ref.invalidate(savedFiltersProvider);
    navigator.pop(saved);
  }
}
