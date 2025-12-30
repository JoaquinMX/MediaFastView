import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../domain/entities/media_entity.dart';
import '../controllers/media_marquee_controller.dart';
import '../view_models/media_grid_view_model.dart';
import 'media_grid_item.dart';

class MediaGridView extends StatelessWidget {
  const MediaGridView({
    super.key,
    required this.media,
    required this.columns,
    required this.viewModel,
    required this.selectedMediaIds,
    required this.isSelectionMode,
    required this.marqueeController,
    required this.onMediaTap,
    required this.onMediaDoubleTap,
    required this.onMediaLongPress,
    required this.onMediaSecondaryTap,
  });

  final List<MediaEntity> media;
  final int columns;
  final MediaViewModel viewModel;
  final Set<String> selectedMediaIds;
  final bool isSelectionMode;
  final MediaMarqueeController marqueeController;
  final void Function(MediaEntity media) onMediaTap;
  final void Function(MediaEntity media) onMediaDoubleTap;
  final void Function(MediaEntity media) onMediaLongPress;
  final void Function(MediaEntity media) onMediaSecondaryTap;

  @override
  Widget build(BuildContext context) {
    marqueeController.pruneMediaItemKeys(media);
    final gridView = GridView.builder(
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
        final isSelected = selectedMediaIds.contains(mediaItem.id);
        final itemKey = marqueeController.mediaItemKeys.putIfAbsent(
          mediaItem.id,
          () => GlobalKey(),
        );
        return MediaGridItem(
          key: itemKey,
          media: mediaItem,
          onTap: () => onMediaTap(mediaItem),
          onDoubleTap: () => onMediaDoubleTap(mediaItem),
          onLongPress: () => onMediaLongPress(mediaItem),
          onSecondaryTap: () => onMediaSecondaryTap(mediaItem),
          onOperationComplete: () => viewModel.loadMedia(),
          onSelectionToggle: () => viewModel.toggleMediaSelection(mediaItem.id),
          isSelected: isSelected,
          isSelectionMode: isSelectionMode,
        );
      },
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) =>
          marqueeController.handlePointerDown(event, viewModel),
      onPointerMove: (event) {
        if (event is PointerMoveEvent) {
          marqueeController.handlePointerMove(event, viewModel);
        }
      },
      onPointerUp: (_) => marqueeController.endSelection(),
      onPointerCancel: (_) => marqueeController.endSelection(),
      child: Stack(
        key: marqueeController.overlayKey,
        children: [
          Positioned.fill(child: gridView),
          ValueListenableBuilder<Rect?>(
            valueListenable: marqueeController.selectionRectNotifier,
            builder: (context, selectionRect, _) {
              if (selectionRect == null) {
                return const SizedBox.shrink();
              }
              return Positioned.fromRect(
                rect: selectionRect,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: UiSizing.borderWidth,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
