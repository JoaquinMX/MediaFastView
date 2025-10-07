import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/media_library/presentation/view_models/file_operations_view_model.dart';

/// Widget for showing operation progress
class OperationProgressIndicator extends ConsumerWidget {
  const OperationProgressIndicator({
    super.key,
    this.message,
    this.showText = true,
  });

  final String? message;
  final bool showText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fileOperationsViewModelProvider);

    return switch (state) {
      FileOperationsLoading() => _buildLoadingIndicator(context),
      FileOperationsSuccess() => _buildSuccessIndicator(context, state.message),
      FileOperationsError() => _buildErrorIndicator(context, state.message),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        if (showText) ...[
          const SizedBox(width: 8),
          Text(
            message ?? 'Processing...',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildSuccessIndicator(BuildContext context, String message) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 16),
        if (showText) ...[
          const SizedBox(width: 8),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.green),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorIndicator(BuildContext context, String message) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error, color: Colors.red, size: 16),
        if (showText) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.red),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
