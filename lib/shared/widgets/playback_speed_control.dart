import 'package:flutter/material.dart';

import '../utils/playback_speed_policy.dart';

/// Displays the current playback speed and opens controls for changing it.
class PlaybackSpeedControl extends StatefulWidget {
  const PlaybackSpeedControl({
    super.key,
    required this.playbackSpeed,
    required this.onPlaybackSpeedSelected,
    this.playbackSpeedOptions = PlaybackSpeedPolicy.presets,
    this.enabled = true,
    this.foregroundColor = Colors.white,
    this.activeColor = Colors.blue,
  });

  final double playbackSpeed;
  final ValueChanged<double>? onPlaybackSpeedSelected;
  final List<double> playbackSpeedOptions;
  final bool enabled;
  final Color foregroundColor;
  final Color activeColor;

  @override
  State<PlaybackSpeedControl> createState() => _PlaybackSpeedControlState();
}

class _PlaybackSpeedControlState extends State<PlaybackSpeedControl> {
  final MenuController _menuController = MenuController();
  late double _currentSpeed;

  bool get _isEnabled =>
      widget.enabled && widget.onPlaybackSpeedSelected != null;

  List<double> get _presetSpeeds {
    final speeds =
        widget.playbackSpeedOptions
            .map(PlaybackSpeedPolicy.normalize)
            .whereType<double>()
            .toSet()
            .toList()
          ..sort();
    return speeds.isEmpty
        ? List<double>.of(PlaybackSpeedPolicy.presets)
        : speeds;
  }

  @override
  void initState() {
    super.initState();
    _currentSpeed =
        PlaybackSpeedPolicy.normalize(widget.playbackSpeed) ??
        PlaybackSpeedPolicy.minimum;
  }

  @override
  void didUpdateWidget(PlaybackSpeedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playbackSpeed != oldWidget.playbackSpeed) {
      final normalizedSpeed = PlaybackSpeedPolicy.normalize(
        widget.playbackSpeed,
      );
      if (normalizedSpeed != null && normalizedSpeed != _currentSpeed) {
        _currentSpeed = normalizedSpeed;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveForegroundColor = _isEnabled
        ? widget.foregroundColor
        : widget.foregroundColor.withValues(alpha: 0.38);

    return MenuAnchor(
      controller: _menuController,
      menuChildren: [
        SizedBox(
          width: 304,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Playback speed',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Row(children: _buildPresetButtons()),
                const SizedBox(height: 16),
                Text(
                  '${PlaybackSpeedPolicy.format(_currentSpeed)}x',
                  key: const ValueKey<String>('playback-speed-value'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    IconButton(
                      onPressed:
                          _isEnabled &&
                              _currentSpeed > PlaybackSpeedPolicy.minimum
                          ? _decreaseSpeed
                          : null,
                      icon: const Icon(Icons.remove),
                      tooltip: 'Decrease playback speed',
                    ),
                    Expanded(
                      child: Slider(
                        min: PlaybackSpeedPolicy.minimum,
                        max: PlaybackSpeedPolicy.maximum,
                        divisions: PlaybackSpeedPolicy.sliderDivisions,
                        value: _currentSpeed,
                        label: '${PlaybackSpeedPolicy.format(_currentSpeed)}x',
                        onChanged: _isEnabled ? _applySpeed : null,
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _isEnabled &&
                              _currentSpeed < PlaybackSpeedPolicy.maximum
                          ? _increaseSpeed
                          : null,
                      icon: const Icon(Icons.add),
                      tooltip: 'Increase playback speed',
                    ),
                  ],
                ),
                Text(
                  '${PlaybackSpeedPolicy.format(PlaybackSpeedPolicy.minimum)}x'
                  ' – '
                  '${PlaybackSpeedPolicy.format(PlaybackSpeedPolicy.maximum)}x',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, child) {
        return Tooltip(
          message: 'Playback speed',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isEnabled
                  ? () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    }
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: effectiveForegroundColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.speed, color: effectiveForegroundColor),
                    const SizedBox(width: 6),
                    Text(
                      '${PlaybackSpeedPolicy.format(_currentSpeed)}x',
                      style: TextStyle(
                        color: effectiveForegroundColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildPresetButtons() {
    final buttons = <Widget>[];
    for (final speed in _presetSpeeds) {
      if (buttons.isNotEmpty) {
        buttons.add(const SizedBox(width: 8));
      }
      buttons.add(
        Expanded(
          child: ChoiceChip(
            label: Text('${PlaybackSpeedPolicy.format(speed)}x'),
            selected: speed == _currentSpeed,
            selectedColor: widget.activeColor.withValues(alpha: 0.25),
            onSelected: _isEnabled
                ? (_) {
                    _menuController.close();
                    _applySpeed(speed);
                  }
                : null,
          ),
        ),
      );
    }
    return buttons;
  }

  void _decreaseSpeed() {
    _applySpeed(_currentSpeed - PlaybackSpeedPolicy.step);
  }

  void _increaseSpeed() {
    _applySpeed(_currentSpeed + PlaybackSpeedPolicy.step);
  }

  void _applySpeed(double speed) {
    final normalizedSpeed = PlaybackSpeedPolicy.normalize(speed);
    if (!_isEnabled ||
        normalizedSpeed == null ||
        normalizedSpeed == _currentSpeed) {
      return;
    }

    setState(() {
      _currentSpeed = normalizedSpeed;
    });
    widget.onPlaybackSpeedSelected?.call(normalizedSpeed);
  }
}
