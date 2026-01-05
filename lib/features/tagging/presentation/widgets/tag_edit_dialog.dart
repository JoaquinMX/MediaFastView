import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/tag_shortcut_preferences_provider.dart';
import '../../../../shared/utils/tag_shortcut_preferences.dart';
import '../../../../shared/utils/tag_usage_ranker.dart';
import '../../domain/entities/tag_entity.dart';
import '../view_models/tag_management_view_model.dart';
import 'tag_color_picker.dart';

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
  static const int _noShortcut = -1;

  late int _selectedColor;
  int _selectedShortcutSlot = _noShortcut;
  bool _isSaving = false;
  List<String> _storedShortcutIds = const <String>[];
  Map<String, String> _tagNamesById = const <String, String>{};

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.tag.color;
    _loadShortcutState();
  }

  Future<void> _loadShortcutState() async {
    final shortcutPreferences = ref.read(tagShortcutPreferencesProvider);
    final tagViewModel = ref.read(tagViewModelProvider.notifier);

    final shortcuts = await shortcutPreferences.loadShortcutTagIds();
    final slotIndex = shortcuts.indexOf(widget.tag.id);
    final tagNames = {
      for (final tag in tagViewModel.getAllTags()) tag.id: tag.name,
    };

    if (!mounted) {
      return;
    }

    setState(() {
      _storedShortcutIds = shortcuts;
      _selectedShortcutSlot = slotIndex == -1 ? _noShortcut : slotIndex + 1;
      _tagNamesById = tagNames;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Tag'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.tag.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TagColorPicker(
            selectedColor: _selectedColor,
            onColorSelected: (color) => setState(() => _selectedColor = color),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _selectedShortcutSlot,
            decoration: const InputDecoration(
              labelText: 'Keyboard shortcut',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<int>(
                value: _noShortcut,
                child: Text('No shortcut'),
              ),
              ...List<DropdownMenuItem<int>>.generate(
                TagUsageRanker.defaultLimit,
                (index) {
                  final slot = index + 1;
                  final occupant = _slotLabel(slot);
                  return DropdownMenuItem<int>(
                    value: slot,
                    child: Text(occupant),
                  );
                },
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedShortcutSlot = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : () => _saveTag(context),
          child: _isSaving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  String _slotLabel(int slot) {
    final slotIndex = slot - 1;
    final occupantId =
        slotIndex < _storedShortcutIds.length ? _storedShortcutIds[slotIndex] : null;

    if (occupantId != null && occupantId.isNotEmpty && occupantId != widget.tag.id) {
      final occupantName = _tagNamesById[occupantId];
      if (occupantName != null) {
        return '$slot – $occupantName';
      }
    }
    return '$slot';
  }

  Future<void> _saveTag(BuildContext context) async {
    setState(() {
      _isSaving = true;
    });

    final tagViewModel = ref.read(tagViewModelProvider.notifier);
    final shortcutPreferences = ref.read(tagShortcutPreferencesProvider);
    final updatedTag = widget.tag.copyWith(color: _selectedColor);

    try {
      await tagViewModel.updateTag(updatedTag);

      final updatedShortcuts = List<String>.from(_storedShortcutIds)
        ..removeWhere((id) => id == widget.tag.id);

      if (_selectedShortcutSlot > 0) {
        final targetIndex = _selectedShortcutSlot - 1;
        while (updatedShortcuts.length <= targetIndex) {
          updatedShortcuts.add('');
        }
        updatedShortcuts[targetIndex] = widget.tag.id;
      }

      while (updatedShortcuts.isNotEmpty && updatedShortcuts.last.isEmpty) {
        updatedShortcuts.removeLast();
      }

      await shortcutPreferences.saveShortcutTagIds(updatedShortcuts);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated "${widget.tag.name}"')),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update tag: $error')),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
    }
  }
}
