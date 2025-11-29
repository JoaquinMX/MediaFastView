import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that controls whether delete operations remove files from the
/// original source on disk.
final deleteFromSourceProvider =
    StateNotifierProvider<DeleteFromSourceNotifier, bool>((ref) {
  return DeleteFromSourceNotifier();
});

/// Manages the persisted preference for deleting files from their source.
class DeleteFromSourceNotifier extends StateNotifier<bool> {
  DeleteFromSourceNotifier() : super(false);

  void setDeleteFromSource(bool enabled) {
    debugPrint(
      'DeleteFromSourceProvider: Updating preference from $state to $enabled',
    );
    state = enabled;
    debugPrint(
      'DeleteFromSourceProvider: Preference updated with value $enabled',
    );
  }
}
