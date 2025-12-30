import 'package:flutter/material.dart';

Future<void> showDestructiveConfirmationDialog(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmLabel,
  required Future<void> Function() onConfirm,
  String successMessage = 'Action completed successfully',
  String errorPrefix = 'Action failed',
}) async {
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            try {
              await onConfirm();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(successMessage),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$errorPrefix: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: Text(confirmLabel, style: const TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
