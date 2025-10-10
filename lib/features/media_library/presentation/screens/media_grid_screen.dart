import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/ui_constants.dart';
import '../../../../shared/providers/grid_columns_provider.dart';

import '../../../full_screen/presentation/screens/full_screen_viewer_screen.dart';
import '../../../tagging/presentation/widgets/tag_filter_chips.dart';
import '../../../tagging/presentation/widgets/tag_management_dialog.dart';
import '../../domain/entities/media_entity.dart';
import '../view_models/media_grid_view_model.dart';
import '../view_models/library_sort_option.dart';
import '../widgets/media_grid_item.dart';
import '../widgets/column_selector_popup.dart';
import '../widgets/library_sort_menu_button.dart';

/// Screen for displaying media in a customizable grid layout.
class MediaGridScreen extends ConsumerStatefulWidget {
  const MediaGridScreen({
    super.key,
    required this.directoryPath,
    required this.directoryName,
    this.bookmarkData,
  });

  final String directoryPath;
  final String directoryName;
  final String? bookmarkData;

  @override
  ConsumerState<MediaGridScreen> createState() => _MediaGridScreenState();
}

class _MediaGridScreenState extends ConsumerState<MediaGridScreen> {
  MediaViewModelParams? _params;
  MediaViewModel? _viewModel;

  @override
  Widget build(BuildContext context) {
    debugPrint('MediaGridScreen: Building for ${widget.directoryName}, screen size: ${MediaQuery.of(context).size}');
    _params = MediaViewModelParams(
      directoryPath: widget.directoryPath,
      directoryName: widget.directoryName,
      bookmarkData: widget.bookmarkData,
      navigateToDirectory: (path, name, bookmarkData) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MediaGridScreen(
              directoryPath: path,
              directoryName: name,
              bookmarkData: bookmarkData,
            ),
          ),
        );
      },
      onPermissionRecoveryNeeded: () async {
        return await FilePicker.platform.getDirectoryPath();
      },
    );
    final state = ref.watch(mediaViewModelProvider(_params!));
    _viewModel = ref.read(mediaViewModelProvider(_params!).notifier);
    final sortOption = state is MediaLoaded
        ? state.sortOption
        : LibrarySortOption.nameAscending;
    final isSortEnabled = state is MediaLoaded;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.directoryName),
        actions: [
             LibrarySortMenuButton(
               selectedOption: sortOption,
               onSelected: _viewModel!.changeSortOption,
               enabled: isSortEnabled,
             ),
             IconButton(
               icon: const Icon(Icons.tag),
               tooltip: 'Manage Tags',
               onPressed: () => TagManagementDialog.show(context),
             ),
             IconButton(
               icon: const Icon(Icons.view_module),
               onPressed: () => _showColumnSelector(context),
             ),
           ],
      ),
      body: Column(
        children: [
          _buildTagFilter(_viewModel!, state),
          Expanded(
            child: switch (state) {
              MediaLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              MediaLoaded(:final media, :final columns) => _buildGrid(
                media,
                columns,
                _viewModel!,
              ),
              MediaPermissionRevoked(:final directoryPath, :final directoryName) =>
                _buildPermissionRevoked(directoryPath, directoryName, _viewModel!),
              MediaError(:final message) => _buildError(message, _viewModel!),
              MediaEmpty() => _buildEmpty(_viewModel!),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTagFilter(MediaViewModel viewModel, MediaState state) {
    final selectedTagIds = state is MediaLoaded
        ? state.selectedTagIds
        : const <String>[];

    return Container(
      padding: UiSpacing.tagFilterPadding,
      child: TagFilterChips(
        selectedTagIds: selectedTagIds,
        onSelectionChanged: viewModel.filterByTags,
        maxChipsToShow: UiGrid.maxFilterChips, // Limit to prevent overflow
      ),
    );
  }

  Widget _buildGrid(
    List<MediaEntity> media,
    int columns,
    MediaViewModel viewModel,
  ) {
    debugPrint('MediaGridScreen: Building grid with ${media.length} items, $columns columns, screen size: ${MediaQuery.of(context).size}');
    return GridView.builder(
      padding: UiSpacing.gridPadding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: UiGrid.crossAxisSpacing,
        mainAxisSpacing: UiGrid.mainAxisSpacing,
        childAspectRatio: UiGrid.childAspectRatio,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final mediaItem = media[index];
        return MediaGridItem(
          media: mediaItem,
          onTap: () => _onMediaTap(context, mediaItem),
          onDoubleTap: () => _onMediaDoubleTap(context, mediaItem),
          onLongPress: () => _onMediaLongPress(context, mediaItem),
          onSecondaryTap: () => _onMediaSecondaryTap(context, mediaItem),
          onOperationComplete: () =>
              viewModel.loadMedia(), // Refresh after delete
        );
      },
    );
  }

  Widget _buildError(String message, MediaViewModel viewModel) {
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
            onPressed: viewModel.loadMedia,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(MediaViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: UiSizing.iconHuge,
            color: UiColors.grey,
          ),
          SizedBox(height: UiSpacing.verticalGap),
          const Text('No media files found in this directory'),
          SizedBox(height: UiSpacing.verticalGap),
          ElevatedButton(
            onPressed: viewModel.loadMedia,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRevoked(
    String directoryPath,
    String directoryName,
    MediaViewModel viewModel,
  ) {
    return Center(
      child: Container(
        padding: UiSpacing.dialogPadding,
        margin: UiSpacing.dialogMargin,
        decoration: BoxDecoration(
          color: UiColors.white,
          borderRadius: BorderRadius.circular(UiSizing.borderRadiusMedium),
          border: Border.all(color: UiColors.orange, width: UiSizing.borderWidth),
          boxShadow: [UiShadows.standard],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock,
              size: UiSizing.iconHuge,
              color: UiColors.orange,
            ),
            SizedBox(height: UiSpacing.verticalGap),
            const Text(
              'Access to this directory has been revoked',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: UiSpacing.smallGap),
            Text(
              'The permissions for "$directoryName" are no longer available.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            SizedBox(height: UiSpacing.smallGap),
            const Text(
              'This can happen when security-scoped bookmarks expire or when directory permissions change.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: UiSpacing.verticalGap * 1.5),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await viewModel.recoverPermissions();
                  // Show success feedback
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Permissions recovered successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  // Show error feedback
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to recover permissions: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('Re-select Directory'),
              style: ElevatedButton.styleFrom(
                backgroundColor: UiColors.orange,
                foregroundColor: UiColors.white,
                padding: UiSpacing.buttonPadding,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => viewModel.loadMedia(), // Try refreshing without recovery
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
            SizedBox(height: UiSpacing.verticalGap),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  void _showColumnSelector(BuildContext context) {
    final currentColumns = ref.read(gridColumnsProvider);
    showDialog(
      context: context,
      builder: (context) => ColumnSelectorPopup(
        currentColumns: currentColumns,
        onColumnsSelected: (columns) {
          _viewModel?.setColumns(columns);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _onMediaTap(BuildContext context, MediaEntity media) {
    if (media.type == MediaType.directory) {
      _viewModel!.navigateToDirectory(media.path, media.name, bookmarkData: media.bookmarkData);
    } else {
      // Open full-screen viewer
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullScreenViewerScreen(
            directoryPath: widget.directoryPath,
            initialMediaId: media.id,
            bookmarkData: widget.bookmarkData,
          ),
        ),
      );
    }
  }

  void _onMediaDoubleTap(BuildContext context, MediaEntity media) {
    // Double-tap opens full-screen viewer
    _onMediaTap(context, media);
  }

  void _onMediaLongPress(BuildContext context, MediaEntity media) {
    // Long-press shows media info
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(media.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Path: ${media.path}'),
            Text('Type: ${media.type.name}'),
            Text('Size: ${_formatFileSize(media.size)}'),
            Text('Modified: ${_formatDate(media.lastModified)}'),
            if (media.tagIds.isNotEmpty) Text('Tags: ${media.tagIds.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _onMediaSecondaryTap(BuildContext context, MediaEntity media) {
    // Right-click shows context menu
    showMenu(
      context: context,
      position: UiPosition.contextMenu,
      items: [
        PopupMenuItem(
          child: const Text('Open'),
          onTap: () => _onMediaTap(context, media),
        ),
        PopupMenuItem(
          child: const Text('Info'),
          onTap: () => _onMediaLongPress(context, media),
        ),
        // Delete option is handled by FileOperationButton
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < AppConfig.kbBytes) {
      return '$bytes ${AppConfig.byteSuffix}';
    }
    if (bytes < AppConfig.mbBytes) {
      return '${(bytes / AppConfig.kbBytes).toStringAsFixed(AppConfig.fileSizeDecimalPlaces)} ${AppConfig.kbSuffix}';
    }
    if (bytes < AppConfig.gbBytes) {
      return '${(bytes / AppConfig.mbBytes).toStringAsFixed(AppConfig.fileSizeDecimalPlaces)} ${AppConfig.mbSuffix}';
    }
    return '${(bytes / AppConfig.gbBytes).toStringAsFixed(AppConfig.fileSizeDecimalPlaces)} ${AppConfig.gbSuffix}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

}
