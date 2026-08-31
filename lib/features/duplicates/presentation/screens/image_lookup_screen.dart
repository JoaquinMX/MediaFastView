import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../../../../core/constants/media_extensions.dart';
import '../../../../core/models/media_lookup_mode.dart';
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../../../shared/widgets/app_bar.dart';
import '../../../../shared/widgets/finder_media_actions.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../domain/entities/image_lookup_match.dart';
import '../../domain/entities/duplicate_sensitivity.dart';
import '../../domain/entities/image_lookup_result.dart';
import '../../domain/entities/image_lookup_session.dart';
import '../../domain/entities/image_lookup_source.dart';
import '../view_models/image_lookup_view_model.dart';
import '../widgets/duplicate_thumbnail.dart';
import '../widgets/sensitivity_selector.dart';

/// Read-only lookup of selected visual media against the active profile.
class ImageLookupScreen extends ConsumerStatefulWidget {
  const ImageLookupScreen({super.key});

  @override
  ConsumerState<ImageLookupScreen> createState() => _ImageLookupScreenState();
}

class _ImageLookupScreenState extends ConsumerState<ImageLookupScreen> {
  bool _isDragging = false;
  final Set<String> _expandedQueries = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(imageLookupViewModelProvider.notifier).markForeground();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageLookupViewModelProvider);
    final viewModel = ref.read(imageLookupViewModelProvider.notifier);
    final phase = state.phase;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Find Media Matches',
        actions: <Widget>[
          IconButton(
            tooltip: 'Lookup history',
            onPressed: () => _showHistory(context, state, viewModel),
            icon: Badge(
              isLabelVisible: state.history.isNotEmpty,
              label: Text('${state.history.length}'),
              child: const Icon(Icons.history),
            ),
          ),
          IconButton(
            tooltip: state.lookupMode == MediaLookupMode.videoFromFrame
                ? 'Choose image frames'
                : 'Choose images or videos',
            onPressed: () => unawaited(viewModel.pickMedia()),
            icon: const Icon(Icons.perm_media_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: <Widget>[
          _LookupModeBar(
            mode: state.lookupMode,
            enabled: !state.isBusy,
            onChanged: (mode) => unawaited(viewModel.setLookupMode(mode)),
          ),
          Expanded(
            child: DropTarget(
              onDragEntered: (_) => setState(() => _isDragging = true),
              onDragExited: (_) => setState(() => _isDragging = false),
              onDragDone: (details) {
                setState(() => _isDragging = false);
                final paths = details.files
                    .map((file) => file.path)
                    .toList(growable: false);
                if (state.lookupMode == MediaLookupMode.videoFromFrame) {
                  final ignored = paths
                      .where((path) => !isSupportedImagePath(path))
                      .length;
                  if (ignored > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Ignored $ignored non-image '
                          '${ignored == 1 ? 'file' : 'files'}.',
                        ),
                      ),
                    );
                  }
                }
                unawaited(viewModel.startFromPaths(paths));
              },
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  switch (phase) {
                    ImageLookupIdle() => _IdleView(
                      mode: state.lookupMode,
                      onChoose: () => unawaited(viewModel.pickMedia()),
                    ),
                    ImageLookupPreparing() => _PreparingView(
                      phase: phase,
                      mode: state.lookupMode,
                      onSkip: viewModel.skipPreparation,
                      onCancel: () => unawaited(viewModel.cancel()),
                      onBackground: () => _runInBackground(context, viewModel),
                    ),
                    ImageLookupSearching() => _SearchingView(
                      phase: phase,
                      onCancel: () => unawaited(viewModel.cancel()),
                      onBackground: () => _runInBackground(context, viewModel),
                    ),
                    ImageLookupResults() => _ResultsView(
                      phase: phase,
                      state: state,
                      expandedQueries: _expandedQueries,
                      onSensitivityChanged: (value) =>
                          unawaited(viewModel.setSensitivity(value)),
                      onChoose: () => unawaited(viewModel.pickMedia()),
                      onToggleExpanded: (path) {
                        setState(() {
                          if (!_expandedQueries.add(path)) {
                            _expandedQueries.remove(path);
                          }
                        });
                      },
                    ),
                    ImageLookupFailure(:final message) => _FailureView(
                      message: message,
                      onChoose: () => unawaited(viewModel.pickMedia()),
                    ),
                  },
                  if (_isDragging) _DropOverlay(mode: state.lookupMode),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _runInBackground(BuildContext context, ImageLookupViewModel viewModel) {
    viewModel.runInBackground();
    Navigator.of(context).maybePop();
  }

  Future<void> _showHistory(
    BuildContext context,
    ImageLookupViewState state,
    ImageLookupViewModel viewModel,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _HistoryDialog(
        state: state,
        onOpen: (session) async {
          Navigator.of(dialogContext).pop();
          await viewModel.openHistory(session);
        },
        onDelete: viewModel.deleteHistory,
        onClear: viewModel.clearHistory,
      ),
    );
  }
}

class _LookupModeBar extends StatelessWidget {
  const _LookupModeBar({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final MediaLookupMode mode;
  final bool enabled;
  final ValueChanged<MediaLookupMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: <Widget>[
            Text('Lookup mode', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 16),
            SegmentedButton<MediaLookupMode>(
              segments: const <ButtonSegment<MediaLookupMode>>[
                ButtonSegment<MediaLookupMode>(
                  value: MediaLookupMode.mediaMatches,
                  icon: Icon(Icons.perm_media_outlined),
                  label: Text('Media matches'),
                ),
                ButtonSegment<MediaLookupMode>(
                  value: MediaLookupMode.videoFromFrame,
                  icon: Icon(Icons.video_file_outlined),
                  label: Text('Video from frame'),
                ),
              ],
              selected: <MediaLookupMode>{mode},
              onSelectionChanged: enabled
                  ? (selection) => onChanged(selection.single)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({required this.mode, required this.onChoose});

  final MediaLookupMode mode;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.perm_media_outlined,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                mode == MediaLookupMode.videoFromFrame
                    ? 'Find a video from one of its frames'
                    : 'Check images or videos against your library',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                mode == MediaLookupMode.videoFromFrame
                    ? 'Choose one or more image frames. The app compares them '
                          'with frames sampled at 10%, 30%, 50%, 70%, and 90% '
                          'of every indexed video in the active profile.'
                    : 'Choose one or more images or videos, or drop them '
                          'anywhere in this window. Videos are compared using a '
                          'generated frame near 10% of each video. Results use '
                          'media already indexed for the active profile.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onChoose,
                icon: const Icon(Icons.perm_media_outlined),
                label: Text(
                  mode == MediaLookupMode.videoFromFrame
                      ? 'Choose Image Frames'
                      : 'Choose Media',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreparingView extends StatelessWidget {
  const _PreparingView({
    required this.phase,
    required this.mode,
    required this.onSkip,
    required this.onCancel,
    required this.onBackground,
  });

  final ImageLookupPreparing phase;
  final MediaLookupMode mode;
  final VoidCallback onSkip;
  final VoidCallback onCancel;
  final VoidCallback onBackground;

  @override
  Widget build(BuildContext context) {
    final progress = phase.progress;
    return _OperationView(
      icon: Icons.photo_library_outlined,
      title: 'Preparing Library',
      description: progress.total == 0
          ? 'Checking indexed media…'
          : 'Processed ${progress.processed} of ${progress.total} '
                '${mode == MediaLookupMode.videoFromFrame ? 'videos' : 'media items'}'
                '${progress.reused > 0 ? ' · ${progress.reused} reused' : ''}',
      progress: progress.total == 0 ? null : progress.fraction,
      actions: <Widget>[
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
        OutlinedButton(onPressed: onSkip, child: const Text('Skip')),
        FilledButton.icon(
          onPressed: onBackground,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Run in Background'),
        ),
      ],
    );
  }
}

class _SearchingView extends StatelessWidget {
  const _SearchingView({
    required this.phase,
    required this.onCancel,
    required this.onBackground,
  });

  final ImageLookupSearching phase;
  final VoidCallback onCancel;
  final VoidCallback onBackground;

  @override
  Widget build(BuildContext context) {
    return _OperationView(
      icon: Icons.manage_search,
      title: 'Finding Matches',
      description: phase.total == 0
          ? 'Preparing selected media…'
          : 'Processed ${phase.processed} of ${phase.total} queries',
      progress: phase.total == 0 ? null : phase.fraction,
      actions: <Widget>[
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: onBackground,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Run in Background'),
        ),
      ],
    );
  }
}

class _OperationView extends StatelessWidget {
  const _OperationView({
    required this.icon,
    required this.title,
    required this.description,
    required this.progress,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String description;
  final double? progress;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 12),
              Text(description, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.message, required this.onChoose});

  final String message;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onChoose,
              icon: const Icon(Icons.perm_media_outlined),
              label: const Text('Choose Media'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.phase,
    required this.state,
    required this.expandedQueries,
    required this.onSensitivityChanged,
    required this.onChoose,
    required this.onToggleExpanded,
  });

  final ImageLookupResults phase;
  final ImageLookupViewState state;
  final Set<String> expandedQueries;
  final ValueChanged<DuplicateSensitivity> onSensitivityChanged;
  final VoidCallback onChoose;
  final ValueChanged<String> onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final session = phase.session;
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: SensitivitySelector(
                  value: state.sensitivity,
                  enabled: !phase.isHistorySnapshot,
                  onChanged: onSensitivityChanged,
                ),
              ),
              const SizedBox(width: 20),
              FilledButton.icon(
                onPressed: onChoose,
                icon: const Icon(Icons.perm_media_outlined),
                label: const Text('New Lookup'),
              ),
            ],
          ),
        ),
        if (session.hasPartialCoverage)
          Container(
            width: double.infinity,
            color: theme.colorScheme.tertiaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              'Library preparation was skipped. These results cover '
              '${session.searchedLibraryImages} currently hashed media items and '
              'may be incomplete.',
              style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
            ),
          ),
        if (phase.isHistorySnapshot)
          Container(
            width: double.infinity,
            color: theme.colorScheme.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              'Saved result snapshot from ${_formatDateTime(session.createdAt)}.',
              style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: session.results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 18),
            itemBuilder: (context, index) {
              final result = session.results[index];
              return _LookupResultRow(
                result: result,
                isExpanded: expandedQueries.contains(result.source.path),
                onToggleExpanded: () => onToggleExpanded(result.source.path),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LookupResultRow extends StatelessWidget {
  const _LookupResultRow({
    required this.result,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  static const int _initialMatchCount = 10;

  final ImageLookupResult result;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final shownMatches = isExpanded
        ? result.matches
        : result.matches.take(_initialMatchCount).toList(growable: false);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final query = SizedBox(
              width: constraints.maxWidth < 780 ? double.infinity : 260,
              child: _QueryCard(result: result),
            );
            final matches = Expanded(
              child: _MatchArea(
                result: result,
                shownMatches: shownMatches,
                isExpanded: isExpanded,
                onToggleExpanded: onToggleExpanded,
              ),
            );
            if (constraints.maxWidth < 780) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  query,
                  const SizedBox(height: 16),
                  _MatchArea(
                    result: result,
                    shownMatches: shownMatches,
                    isExpanded: isExpanded,
                    onToggleExpanded: onToggleExpanded,
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[query, const SizedBox(width: 18), matches],
            );
          },
        ),
      ),
    );
  }
}

class _QueryCard extends StatelessWidget {
  const _QueryCard({required this.result});

  final ImageLookupResult result;

  @override
  Widget build(BuildContext context) {
    final source = result.source;
    final media = _mediaFromSource(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('Query', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            _SourceActions(source: source),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showPreview(context, media),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  DuplicateThumbnail(media: media),
                  if (media.type == MediaType.video)
                    const _VideoThumbnailBadge(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          source.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 3),
        Text(
          result.query == null
              ? '${_mediaTypeName(source.mediaType)} · '
                    '${formatFileSize(source.size)} · '
                    'unavailable dimensions'
              : source.mediaType == MediaType.video
              ? 'Video miniature · ${result.query!.width} × '
                    '${result.query!.height} · ${formatFileSize(source.size)} '
                    '· ${_extension(source.path)}'
              : 'Image · ${result.query!.width} × ${result.query!.height} · '
                    '${formatFileSize(source.size)} · ${_extension(source.path)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          p.dirname(source.path),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MatchArea extends StatelessWidget {
  const _MatchArea({
    required this.result,
    required this.shownMatches,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final ImageLookupResult result;
  final List<ImageLookupMatch> shownMatches;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (result.hasError) {
      return _InlineMessage(
        icon: Icons.broken_image_outlined,
        message: result.errorMessage!,
      );
    }
    if (result.matches.isEmpty) {
      return const _InlineMessage(
        icon: Icons.search_off,
        message: 'No matches found in the currently indexed library.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${result.matches.length} match${result.matches.length == 1 ? '' : 'es'}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            for (final match in shownMatches)
              SizedBox(width: 220, child: _MatchCard(match: match)),
          ],
        ),
        if (result.matches.length > _LookupResultRow._initialMatchCount) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onToggleExpanded,
            icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
            label: Text(
              isExpanded
                  ? 'Show closest 10'
                  : 'Show all ${result.matches.length} matches',
            ),
          ),
        ],
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final ImageLookupMatch match;

  @override
  Widget build(BuildContext context) {
    final candidate = match.candidate;
    final media = candidate.media;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            GestureDetector(
              onTap: () => _showPreview(
                context,
                media,
                startAt: match.matchedVideoFrame?.timestamp,
              ),
              child: SizedBox(
                height: 170,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    DuplicateThumbnail(
                      media: media,
                      videoPositionFraction:
                          match.matchedVideoFrame?.positionPercent == null
                          ? null
                          : match.matchedVideoFrame!.positionPercent / 100,
                    ),
                    if (media.type == MediaType.video)
                      const _VideoThumbnailBadge(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          media.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          media.type == MediaType.video
                              ? 'Video miniature · ${candidate.width} × '
                                    '${candidate.height} · '
                                    '${formatFileSize(media.size)}'
                              : 'Image · ${candidate.width} × '
                                    '${candidate.height} · '
                                    '${formatFileSize(media.size)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (match.matchedVideoFrame case final frame?)
                          Text(
                            'Matched around ${_formatDuration(frame.timestamp)} '
                            '· ${frame.positionPercent}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        Text(
                          _formatDate(media.lastModified),
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          p.dirname(media.path),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _MediaActions(
                    media: media,
                    startAt: match.matchedVideoFrame?.timestamp,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaActions extends StatelessWidget {
  const _MediaActions({required this.media, this.startAt});

  final MediaEntity media;
  final Duration? startAt;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Read-only actions',
      onSelected: (value) {
        switch (value) {
          case 'preview':
            _showPreview(context, media, startAt: startAt);
          case 'reveal':
            unawaited(revealMediaInFinder(context, media));
          case 'copy':
            unawaited(copyMediaPath(context, media));
        }
      },
      itemBuilder: (context) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'preview', child: Text('Preview')),
        PopupMenuItem<String>(value: 'reveal', child: Text('Reveal in Finder')),
        PopupMenuItem<String>(value: 'copy', child: Text('Copy Path')),
      ],
    );
  }
}

class _SourceActions extends StatelessWidget {
  const _SourceActions({required this.source});

  final ImageLookupSource source;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Read-only actions',
      onSelected: (value) async {
        switch (value) {
          case 'preview':
            _showPreview(context, _mediaFromSource(source));
          case 'reveal':
            try {
              await BookmarkService.instance.revealInFinder(
                source.path,
                bookmarkData: source.bookmarkData,
              );
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not reveal image: $error')),
                );
              }
            }
          case 'copy':
            await Clipboard.setData(ClipboardData(text: source.path));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Path copied')));
            }
        }
      },
      itemBuilder: (context) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'preview', child: Text('Preview')),
        PopupMenuItem<String>(value: 'reveal', child: Text('Reveal in Finder')),
        PopupMenuItem<String>(value: 'copy', child: Text('Copy Path')),
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 42, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _UnavailableImage extends StatelessWidget {
  const _UnavailableImage();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.broken_image_outlined, size: 42),
            SizedBox(height: 8),
            Text('Unavailable'),
          ],
        ),
      ),
    );
  }
}

class _VideoThumbnailBadge extends StatelessWidget {
  const _VideoThumbnailBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.videocam_outlined, size: 16, color: Colors.white),
            SizedBox(width: 4),
            Text('Video', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay({required this.mode});

  final MediaLookupMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.primary.withValues(alpha: 0.18),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.primary, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.add_photo_alternate_outlined, size: 56),
              const SizedBox(height: 12),
              Text(
                mode == MediaLookupMode.videoFromFrame
                    ? 'Drop image frames to search indexed videos'
                    : 'Drop images or videos to start a new lookup',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryDialog extends StatefulWidget {
  const _HistoryDialog({
    required this.state,
    required this.onOpen,
    required this.onDelete,
    required this.onClear,
  });

  final ImageLookupViewState state;
  final ValueChanged<ImageLookupSession> onOpen;
  final Future<void> Function(String sessionId) onDelete;
  final Future<void> Function() onClear;

  @override
  State<_HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<_HistoryDialog> {
  late final List<ImageLookupSession> _history = List<ImageLookupSession>.from(
    widget.state.history,
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lookup History'),
      content: SizedBox(
        width: 560,
        height: 440,
        child: widget.state.isHistoryLoading
            ? const Center(child: CircularProgressIndicator())
            : _history.isEmpty
            ? const Center(child: Text('No saved lookup sessions.'))
            : ListView.separated(
                itemCount: _history.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final session = _history[index];
                  return ListTile(
                    leading: const Icon(Icons.perm_media_outlined),
                    title: Text(
                      '${session.queryCount} quer${session.queryCount == 1 ? 'y' : 'ies'} · '
                      '${session.matchCount} match${session.matchCount == 1 ? '' : 'es'}',
                    ),
                    subtitle: Text(
                      '${_formatDateTime(session.createdAt)} · '
                      '${session.lookupMode.label} · '
                      '${session.sensitivity.label}'
                      '${session.hasPartialCoverage ? ' · partial' : ''}',
                    ),
                    onTap: () => widget.onOpen(session),
                    trailing: IconButton(
                      tooltip: 'Delete history entry',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await widget.onDelete(session.id);
                        if (mounted) {
                          setState(() => _history.removeAt(index));
                        }
                      },
                    ),
                  );
                },
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _history.isEmpty
              ? null
              : () async {
                  await widget.onClear();
                  if (mounted) {
                    setState(_history.clear);
                  }
                },
          child: const Text('Clear All'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _VideoPreviewDialog extends StatefulWidget {
  const _VideoPreviewDialog({required this.media, this.startAt});

  final MediaEntity media;
  final Duration? startAt;

  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.media.path));
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    final startAt = widget.startAt;
    if (startAt == null) {
      return;
    }
    final duration = _controller.value.duration;
    final target = startAt > duration ? duration : startAt;
    await _controller.seekTo(target);
    await _controller.play();
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.black,
      child: Stack(
        children: <Widget>[
          Center(
            child: FutureBuilder<void>(
              future: _initialization,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const CircularProgressIndicator();
                }
                if (snapshot.hasError || !_controller.value.isInitialized) {
                  return const _UnavailableImage();
                }
                return AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      VideoPlayer(_controller),
                      IconButton.filled(
                        iconSize: 42,
                        tooltip: _controller.value.isPlaying ? 'Pause' : 'Play',
                        onPressed: () async {
                          if (_controller.value.isPlaying) {
                            await _controller.pause();
                          } else {
                            await _controller.play();
                          }
                          if (mounted) {
                            setState(() {});
                          }
                        },
                        icon: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(
              tooltip: 'Close preview',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}

MediaEntity _mediaFromSource(ImageLookupSource source) {
  return MediaEntity(
    id: source.path,
    path: source.path,
    name: source.name,
    type: source.mediaType,
    size: source.size,
    lastModified: source.lastModified,
    tagIds: const <String>[],
    directoryId: p.dirname(source.path),
    bookmarkData: source.bookmarkData,
  );
}

void _showPreview(
  BuildContext context,
  MediaEntity media, {
  Duration? startAt,
}) {
  if (media.type == MediaType.video) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (context) => _VideoPreviewDialog(media: media, startAt: startAt),
    );
    return;
  }
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: Stack(
        children: <Widget>[
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 8,
            child: Center(
              child: Image.file(
                File(media.path),
                errorBuilder: (_, __, ___) => const _UnavailableImage(),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(
              tooltip: 'Close preview',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    ),
  );
}

String _extension(String path) {
  final extension = p.extension(path);
  return extension.isEmpty ? 'FILE' : extension.substring(1).toUpperCase();
}

String _mediaTypeName(MediaType mediaType) {
  return mediaType == MediaType.video ? 'Video' : 'Image';
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime date) {
  final local = date.toLocal();
  return '${_formatDate(local)} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
