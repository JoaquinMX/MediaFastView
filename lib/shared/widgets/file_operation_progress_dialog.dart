import 'package:flutter/material.dart';

/// Dialog for showing file operation progress
class FileOperationProgressDialog extends StatelessWidget {
  const FileOperationProgressDialog({
    super.key,
    required this.title,
    required this.message,
    this.progress,
    this.isIndeterminate = true,
  });

  final String title;
  final String message;
  final double? progress;
  final bool isIndeterminate;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 16),
          if (isIndeterminate)
            const CircularProgressIndicator()
          else
            LinearProgressIndicator(value: progress),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  /// Shows the progress dialog
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    double? progress,
    bool isIndeterminate = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FileOperationProgressDialog(
        title: title,
        message: message,
        progress: progress,
        isIndeterminate: isIndeterminate,
      ),
    );
  }
}
