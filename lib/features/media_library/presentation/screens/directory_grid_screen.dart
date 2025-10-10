import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/ui_constants.dart';

import '../../../../shared/models/library_sort_option.dart';
import '../../../../shared/providers/grid_columns_provider.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../tagging/domain/entities/tag_entity.dart';
import '../../../tagging/presentation/states/tag_state.dart';
import '../../../tagging/presentation/view_models/tag_management_view_model.dart';
import '../../../tagging/presentation/widgets/tag_creation_dialog.dart';
import '../../domain/entities/directory_entity.dart';
import '../view_models/directory_grid_view_model.dart';
import '../widgets/directory_grid_item.dart';
import '../widgets/directory_search_bar.dart';
import '../widgets/column_selector_popup.dart';
import 'media_grid_screen.dart';

/// Screen for displaying directories in a customizable grid layout.
class DirectoryGridScreen extends ConsumerStatefulWidget {
  const DirectoryGridScreen({super.key});

  @override
  ConsumerState<DirectoryGridScreen> createState() =>
      _DirectoryGridScreenState();
}

class _DirectoryGridScreenState extends ConsumerState<DirectoryGridScreen> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(directoryViewModelProvider);
    final viewModel = ref.read(directoryViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Directories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDirectoryDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.tag),
            onPressed: () => TagCreationDialog.show(context),
          ),
          PopupMenuButton<LibrarySortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: viewModel.sortOption,
            onSelected: viewModel.setSortOption,
            itemBuilder: (context) {
              return LibrarySortOption.values
                  .map(
                    (option) => PopupMenuItem<LibrarySortOption>(
                      value: option,
                      child: Row(
                        children: [
                          if (option == viewModel.sortOption)
                            const Icon(Icons.check, size: 18),
                          if (option == viewModel.sortOption)
                            const SizedBox(width: 8),
                          Text(option.label),
                        ],
                      ),
                    ),
                  )
                  .toList();
            },
          ),
          IconButton(
            icon: const Icon(Icons.view_module),
            onPressed: () => _showColumnSelector(context, ref),
          ),
        ],
      ),
      body: DropTarget(
        onDragDone: (details) => _onDragDone(details, viewModel),
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        child: Stack(
          children: [
            Column(
              children: [
                const DirectorySearchBar(),
                _buildTagFilter(viewModel),
                Expanded(
                  child: switch (state) {
                    DirectoryLoading() => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    DirectoryLoaded(:final directories, :final columns) =>
                      _buildGrid(directories, columns, viewModel),
                    DirectoryPermissionRevoked(
                      :final inaccessibleDirectories,
                      :final accessibleDirectories,
                      :final columns,
                    ) =>
                      _buildPermissionRevokedGrid(
                        accessibleDirectories,
                        inaccessibleDirectories,
                        columns,
                        viewModel,
                      ),
                    DirectoryBookmarkInvalid(
                      :final invalidDirectories,
                      :final accessibleDirectories,
                      :final columns,
                    ) =>
                      _buildBookmarkInvalidGrid(
                        accessibleDirectories,
                        invalidDirectories,
                        columns,
                        viewModel,
                      ),
                    DirectoryError(:final message) => _buildError(
                      message,
                      viewModel,
                    ),
                    DirectoryEmpty() => _buildEmpty(viewModel),
                  },
                ),
              ],
            ),
            if (_isDragging)
              Container(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: UiOpacity.subtle),
                child: Center(
                  child: Container(
                    padding: UiSpacing.dialogPadding,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(UiSizing.borderRadiusMedium),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: UiSizing.borderWidth,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder, size: UiSizing.iconExtraLarge),
                        SizedBox(height: UiSpacing.verticalGap),
                        const Text('Drop directories here to add them'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onDragDone(DropDoneDetails details, DirectoryViewModel viewModel) {
    setState(() => _isDragging = false);

    for (final file in details.files) {
      // Only add directories, not files
      if (file.path.endsWith('/') || !file.path.contains('.')) {
        viewModel.addDirectory(file.path, silent: true);
      }
    }
  }

  Widget _buildTagFilter(DirectoryViewModel viewModel) {
    final tagState = ref.watch(tagViewModelProvider);
    final selectedTagIds = switch (ref.watch(directoryViewModelProvider)) {
      DirectoryLoaded(:final selectedTagIds) => selectedTagIds,
      DirectoryPermissionRevoked(:final selectedTagIds) => selectedTagIds,
      DirectoryBookmarkInvalid(:final selectedTagIds) => selectedTagIds,
      _ => const <String>[],
    };

    // Debug logging for tag filter state
    debugPrint('DirectoryGridScreen: Building tag filter with selectedTagIds: $selectedTagIds');

    final tags = switch (tagState) {
      TagLoaded(:final tags) => tags,
      _ => <TagEntity>[],
    };

    debugPrint('DirectoryGridScreen: Available tags: ${tags.map((t) => t.name).toList()}');

    return Container(
      height: UiSizing.tagFilterHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            label: const Text('All'),
            selected: selectedTagIds.isEmpty,
            onSelected: (_) {
              debugPrint('DirectoryGridScreen: "All" filter chip selected, calling filterByTags with empty list');
              viewModel.filterByTags(const []);
            },
          ),
          SizedBox(width: UiSpacing.smallGap),
          ...tags.map(
            (tag) => Padding(
              padding: UiSpacing.filterChipRight,
              child: FilterChip(
                label: Text(tag.name),
                selected: selectedTagIds.contains(tag.id),
                onSelected: (selected) {
                  debugPrint('DirectoryGridScreen: Tag "${tag.name}" (${tag.id}) chip ${selected ? 'selected' : 'deselected'}');
                  debugPrint('DirectoryGridScreen: Current selectedTagIds before change: $selectedTagIds');
                  final newSelected = List<String>.from(selectedTagIds);
                  if (selected) {
                    newSelected.add(tag.id);
                  } else {
                    newSelected.remove(tag.id);
                  }
                  debugPrint('DirectoryGridScreen: New selectedTagIds: $newSelected');
                  viewModel.filterByTags(newSelected);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    List<DirectoryEntity> directories,
    int columns,
    DirectoryViewModel viewModel,
  ) {
    return GridView.builder(
      padding: UiSpacing.gridPadding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: UiGrid.crossAxisSpacing,
        mainAxisSpacing: UiGrid.mainAxisSpacing,
        childAspectRatio: UiGrid.childAspectRatio,
      ),
      itemCount: directories.length,
      itemBuilder: (context, index) {
        final directory = directories[index];
        return DirectoryGridItem(
          directory: directory,
          onTap: () => _navigateToMediaGrid(context, directory),
          onDelete: () =>
              _showDeleteConfirmation(context, directory, viewModel),
          onAssignTags: (tagIds) => _assignTagsToDirectory(directory, tagIds),
        );
      },
    );
  }

  Widget _buildPermissionRevokedGrid(
    List<DirectoryEntity> accessibleDirectories,
    List<DirectoryEntity> inaccessibleDirectories,
    int columns,
    DirectoryViewModel viewModel,
  ) {
    final allDirectories = [...accessibleDirectories, ...inaccessibleDirectories];

    return Column(
      children: [
        if (inaccessibleDirectories.isNotEmpty)
          Container(
            padding: UiSpacing.gridPadding,
            color: Colors.orange.shade50,
            child: Row(
              children: [
                Icon(Icons.warning, color: UiColors.orange),
                SizedBox(width: UiSpacing.smallGap),
                Expanded(
                  child: Text(
                    '${inaccessibleDirectories.length} directory(ies) are inaccessible due to permission changes. '
                    'Click "Re-grant Permissions" to restore access.',
                    style: TextStyle(color: UiColors.orange),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _showReGrantPermissionsDialog(
                    context,
                    inaccessibleDirectories,
                    viewModel,
                  ),
                  child: const Text('Re-grant Permissions'),
                ),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: UiSpacing.gridPadding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: UiGrid.crossAxisSpacing,
              mainAxisSpacing: UiGrid.mainAxisSpacing,
              childAspectRatio: UiGrid.childAspectRatio,
            ),
            itemCount: allDirectories.length,
            itemBuilder: (context, index) {
              final directory = allDirectories[index];
              final isInaccessible = inaccessibleDirectories.contains(directory);

              return Opacity(
                opacity: isInaccessible ? UiOpacity.disabled : 1.0,
                child: DirectoryGridItem(
                  directory: directory,
                  onTap: isInaccessible
                      ? () {}
                      : () => _navigateToMediaGrid(context, directory),
                  onDelete: () =>
                      _showDeleteConfirmation(context, directory, viewModel),
                  onAssignTags: (tagIds) => _assignTagsToDirectory(directory, tagIds),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBookmarkInvalidGrid(
    List<DirectoryEntity> accessibleDirectories,
    List<DirectoryEntity> invalidDirectories,
    int columns,
    DirectoryViewModel viewModel,
  ) {
    final allDirectories = [...accessibleDirectories, ...invalidDirectories];

    return Column(
      children: [
        if (invalidDirectories.isNotEmpty)
          Container(
            padding: UiSpacing.gridPadding,
            color: Colors.red.shade50,
            child: Row(
              children: [
                Icon(Icons.error, color: UiColors.red),
                SizedBox(width: UiSpacing.smallGap),
                Expanded(
                  child: Text(
                    '${invalidDirectories.length} directory(ies) have invalid bookmarks. '
                    'Click "Recover Bookmarks" to re-select directories.',
                    style: TextStyle(color: UiColors.red),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _showRecoverBookmarksDialog(
                    context,
                    invalidDirectories,
                    viewModel,
                  ),
                  child: const Text('Recover Bookmarks'),
                ),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: UiSpacing.gridPadding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: UiGrid.crossAxisSpacing,
              mainAxisSpacing: UiGrid.mainAxisSpacing,
              childAspectRatio: UiGrid.childAspectRatio,
            ),
            itemCount: allDirectories.length,
            itemBuilder: (context, index) {
              final directory = allDirectories[index];
              final isInvalid = invalidDirectories.contains(directory);

              return Opacity(
                opacity: isInvalid ? UiOpacity.disabled : 1.0,
                child: DirectoryGridItem(
                  directory: directory,
                  onTap: isInvalid
                      ? () {}
                      : () => _navigateToMediaGrid(context, directory),
                  onDelete: () =>
                      _showDeleteConfirmation(context, directory, viewModel),
                  onAssignTags: (tagIds) => _assignTagsToDirectory(directory, tagIds),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message, DirectoryViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error,
            size: UiSizing.iconHuge,
            color: UiColors.red,
          ),
          SizedBox(height: UiSpacing.verticalGap),
          Text('Error: $message'),
          SizedBox(height: UiSpacing.verticalGap),
          ElevatedButton(
            onPressed: viewModel.loadDirectories,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(DirectoryViewModel viewModel) {
    return Consumer(
      builder: (context, ref, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_open,
                size: UiSizing.iconHuge,
                color: UiColors.grey,
              ),
              SizedBox(height: UiSpacing.verticalGap),
              const Text('No directories found'),
              SizedBox(height: UiSpacing.verticalGap),
              ElevatedButton(
                onPressed: () => _showAddDirectoryDialog(context, ref),
                child: const Text('Add Directory'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddDirectoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Directory'),
        content: const Text(
          'You can drag and drop directories onto the screen, or click below to browse and select a directory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final path = await FilePicker.platform.getDirectoryPath();
              if (path != null) {
                final viewModel = ref.read(directoryViewModelProvider.notifier);
                await viewModel.addDirectory(path);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            child: const Text('Browse'),
          ),
        ],
      ),
    );
  }

  void _showColumnSelector(BuildContext context, WidgetRef ref) {
    final currentColumns = ref.read(gridColumnsProvider);
    showDialog(
      context: context,
      builder: (context) => ColumnSelectorPopup(
        currentColumns: currentColumns,
        onColumnsSelected: (columns) {
          ref.read(directoryViewModelProvider.notifier).setColumns(columns);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _navigateToMediaGrid(BuildContext context, DirectoryEntity directory) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaGridScreen(
          directoryPath: directory.path,
          directoryName: directory.name,
          bookmarkData: directory.bookmarkData,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    DirectoryEntity directory,
    DirectoryViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Directory'),
        content: Text(
          'Are you sure you want to remove "${directory.name}" from the library?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              viewModel.removeDirectory(directory.id);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showReGrantPermissionsDialog(
    BuildContext context,
    List<DirectoryEntity> inaccessibleDirectories,
    DirectoryViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-grant Permissions'),
        content: Text(
          'This will re-add ${inaccessibleDirectories.length} directory(ies) to restore access. '
          'You will need to grant permissions again when prompted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              for (final directory in inaccessibleDirectories) {
                await viewModel.reGrantDirectoryPermissions(directory.path);
              }
            },
            child: const Text('Re-grant Permissions'),
          ),
        ],
      ),
    );
  }

  void _showRecoverBookmarksDialog(
    BuildContext context,
    List<DirectoryEntity> invalidDirectories,
    DirectoryViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recover Bookmarks'),
        content: Text(
          'This will prompt you to re-select ${invalidDirectories.length} directory(ies) to recover bookmarks. '
          'You will need to select the same directories again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              for (final directory in invalidDirectories) {
                await viewModel.recoverDirectoryBookmark(directory.id, directory.path);
              }
            },
            child: const Text('Recover Bookmarks'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignTagsToDirectory(
    DirectoryEntity directory,
    List<String> tagIds,
  ) async {
    final assignTagUseCase = ref.read(assignTagUseCaseProvider);

    try {
      await assignTagUseCase.setTagsForDirectory(directory.id, tagIds);
      await ref.read(directoryViewModelProvider.notifier).loadDirectories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign tags: $e')),
        );
      }
      rethrow;
    }
  }
}
