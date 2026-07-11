import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// What to do about an item whose name is already taken at the destination.
///
/// There is deliberately no "replace": a transfer never destroys an existing
/// file.
enum ConflictResolution { keepBoth, skip, cancel }

class ConflictChoice {
  const ConflictChoice(this.resolution, {this.applyToAll = false});

  final ConflictResolution resolution;

  /// Apply this answer to every remaining conflict in the batch without asking
  /// again.
  final bool applyToAll;
}

/// Asks what to do about a name collision at the destination.
class TransferConflictDialog extends StatefulWidget {
  const TransferConflictDialog({
    super.key,
    required this.destinationPath,
    required this.suggestedPath,
    this.remaining = 0,
  });

  /// The path that is already taken.
  final String destinationPath;

  /// The name the item would take under "keep both".
  final String suggestedPath;

  /// How many further items are still to be transferred, which is what makes
  /// "apply to all" worth offering.
  final int remaining;

  static Future<ConflictChoice?> show(
    BuildContext context, {
    required String destinationPath,
    required String suggestedPath,
    int remaining = 0,
  }) {
    return showDialog<ConflictChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TransferConflictDialog(
        destinationPath: destinationPath,
        suggestedPath: suggestedPath,
        remaining: remaining,
      ),
    );
  }

  @override
  State<TransferConflictDialog> createState() => _TransferConflictDialogState();
}

class _TransferConflictDialogState extends State<TransferConflictDialog> {
  bool _applyToAll = false;

  @override
  Widget build(BuildContext context) {
    final name = p.basename(widget.destinationPath);
    final folder = p.basename(p.dirname(widget.destinationPath));
    final suggestedName = p.basename(widget.suggestedPath);

    return AlertDialog(
      title: Text('"$name" already exists'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('There is already an item named "$name" in "$folder".'),
          const SizedBox(height: 12),
          Text(
            'Keeping both will save it as "$suggestedName".',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (widget.remaining > 0) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _applyToAll,
              onChanged: (value) =>
                  setState(() => _applyToAll = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('Apply to all ${widget.remaining} remaining'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _pop(ConflictResolution.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => _pop(ConflictResolution.skip),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => _pop(ConflictResolution.keepBoth),
          child: const Text('Keep Both'),
        ),
      ],
    );
  }

  void _pop(ConflictResolution resolution) {
    Navigator.of(context).pop(
      ConflictChoice(
        resolution,
        // Cancelling already covers the whole batch.
        applyToAll: resolution == ConflictResolution.cancel ? false : _applyToAll,
      ),
    );
  }
}
