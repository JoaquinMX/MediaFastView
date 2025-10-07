import 'package:flutter/material.dart';

/// Popup dialog for selecting the number of columns in the grid.
class ColumnSelectorPopup extends StatelessWidget {
  const ColumnSelectorPopup({
    super.key,
    required this.currentColumns,
    required this.onColumnsSelected,
  });

  final int currentColumns;
  final ValueChanged<int> onColumnsSelected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Columns'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int columns = 2; columns <= 12; columns++)
            RadioListTile<int>(
              title: Text('$columns Columns'),
              value: columns,
              groupValue: currentColumns,
              onChanged: (value) {
                if (value != null) {
                  onColumnsSelected(value);
                }
              },
            ),
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
}
