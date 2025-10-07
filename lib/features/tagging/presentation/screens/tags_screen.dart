import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../favorites/presentation/screens/slideshow_screen.dart';
import '../../../favorites/presentation/view_models/favorites_view_model.dart';
import '../../../favorites/presentation/widgets/favorite_toggle_button.dart';
import '../../../full_screen/presentation/screens/full_screen_viewer_screen.dart';
import '../../../media_library/domain/entities/directory_entity.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/presentation/screens/media_grid_screen.dart';
import '../../../media_library/presentation/widgets/media_grid_item.dart';
import '../view_models/tags_view_model.dart';

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(tagsViewModelProvider.notifier).loadTags();
      await ref.read(favoritesViewModelProvider.notifier).loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tagsViewModelProvider);
    final viewModel = ref.read(tagsViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload tags',
            onPressed: viewModel.loadTags,
          ),
        ],
      ),
      body: switch (state) {
        TagsLoading() => const Center(child: CircularProgressIndicator()),
        TagsLoaded(:final sections) => _buildSections(sections, viewModel),
        TagsEmpty() => _buildEmpty(viewModel),
        TagsError(:final message) => _buildError(message, viewModel),
      },
    );
  }

  Widget _buildSections(List<TagSection> sections, TagsViewModel viewModel) {
    return RefreshIndicator(
      onRefresh: viewModel.loadTags,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        itemBuilder: (context, index) => _buildSection(sections[index]),
      ),
    );
  }

  Widget _buildSection(TagSection section) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(section),
            const SizedBox(height: 12),
            if (section.directories.isNotEmpty)
              ...section.directories
                  .map((directory) => _buildDirectoryTile(section, directory)),
            if (section.media.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildMediaGrid(section, section.media),
              ),
            if (section.directories.isEmpty && section.media.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  section.isFavorites
                      ? 'Mark media files as favorites to see them here.'
                      : 'No media assigned to this tag yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(TagSection section) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!section.isFavorites && section.color != null)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: section.color,
              shape: BoxShape.circle,
            ),
          ),
        Expanded(
          child: Text(
            section.name,
            style: theme.textTheme.titleMedium,
          ),
        ),
        Text(
          '${section.itemCount} item${section.itemCount == 1 ? '' : 's'}',
          style: theme.textTheme.bodySmall,
        ),
        if (section.allMedia.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.slideshow),
            tooltip: 'Start slideshow',
            onPressed: () => _startSlideshow(section.allMedia),
          ),
      ],
    );
  }

  Widget _buildDirectoryTile(
    TagSection section,
    TagDirectoryContent directoryContent,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        leading: _buildDirectoryPreview(directoryContent),
        title: Text(directoryContent.directory.name),
        subtitle: Text(
          '${directoryContent.media.length} item${directoryContent.media.length == 1 ? '' : 's'}',
        ),
        children: [
          if (directoryContent.media.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'No media with this tag in this directory.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _buildMediaGrid(section, directoryContent.media),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openDirectory(directoryContent.directory),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open directory'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectoryPreview(TagDirectoryContent content) {
    final theme = Theme.of(context);
    final previewPath = content.directory.thumbnailPath ??
        (content.media.isNotEmpty ? content.media.first.path : null);

    if (previewPath != null) {
      final file = File(previewPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          ),
        );
      }
    }

    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.folder,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildMediaGrid(TagSection section, List<MediaEntity> media) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final mediaItem = media[index];
        return _buildMediaTile(section, mediaItem);
      },
    );
  }

  Widget _buildMediaTile(TagSection section, MediaEntity media) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MediaGridItem(
          media: media,
          onTap: () => _openFullScreen(section, media),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: FavoriteToggleButton(
            media: media,
            onToggle: (_) =>
                ref.read(tagsViewModelProvider.notifier).refreshFavorites(),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message, TagsViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $message'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: viewModel.loadTags,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(TagsViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.label_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No tags or favorites found yet'),
          const SizedBox(height: 8),
          const Text(
            'Create tags or favorite media items to organize your library.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: viewModel.loadTags,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  void _openFullScreen(TagSection section, MediaEntity media) {
    final directoryPath = p.dirname(media.path);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenViewerScreen(
          directoryPath: directoryPath,
          initialMediaId: media.id,
          mediaList: section.allMedia,
        ),
      ),
    );
  }

  void _openDirectory(DirectoryEntity directory) {
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

  void _startSlideshow(List<MediaEntity> media) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SlideshowScreen(mediaList: media),
      ),
    );
  }
}
