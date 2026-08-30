import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/shared/widgets/playback_speed_control.dart';

void main() {
  Future<void> pumpControl(
    WidgetTester tester, {
    required double playbackSpeed,
    required ValueChanged<double> onPlaybackSpeedSelected,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PlaybackSpeedControl(
              playbackSpeed: playbackSpeed,
              onPlaybackSpeedSelected: onPlaybackSpeedSelected,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Playback speed'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows requested presets and custom speed range', (tester) async {
    await pumpControl(
      tester,
      playbackSpeed: 1.0,
      onPlaybackSpeedSelected: (_) {},
    );

    await openMenu(tester);

    expect(find.widgetWithText(ChoiceChip, '1x'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '2x'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '3x'), findsOneWidget);
    expect(find.text('2.5x'), findsNothing);
    expect(find.text('4x'), findsNothing);

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 0.5);
    expect(slider.max, 16.0);
    expect(slider.divisions, 31);
  });

  testWidgets('custom changes apply live while menu stays open', (
    tester,
  ) async {
    final selectedSpeeds = <double>[];
    await pumpControl(
      tester,
      playbackSpeed: 1.0,
      onPlaybackSpeedSelected: selectedSpeeds.add,
    );
    await openMenu(tester);

    await tester.tap(find.byTooltip('Increase playback speed'));
    await tester.pump();

    expect(selectedSpeeds, <double>[1.5]);
    expect(find.byType(Slider), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('playback-speed-value')),
      findsOne,
    );
    expect(find.text('1.5x'), findsWidgets);

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged?.call(4.5);
    await tester.pump();

    expect(selectedSpeeds, <double>[1.5, 4.5]);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('4.5x'), findsWidgets);
  });

  testWidgets('preset applies immediately and closes the menu', (tester) async {
    final selectedSpeeds = <double>[];
    await pumpControl(
      tester,
      playbackSpeed: 1.0,
      onPlaybackSpeedSelected: selectedSpeeds.add,
    );
    await openMenu(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, '3x'));
    await tester.pumpAndSettle();

    expect(selectedSpeeds, <double>[3.0]);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('3x'), findsOneWidget);
  });

  testWidgets('increment buttons are disabled at range boundaries', (
    tester,
  ) async {
    await pumpControl(
      tester,
      playbackSpeed: 0.5,
      onPlaybackSpeedSelected: (_) {},
    );
    await openMenu(tester);

    var decreaseButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.remove),
    );
    expect(decreaseButton.onPressed, isNull);

    await tester.tap(find.byTooltip('Playback speed'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PlaybackSpeedControl(
              playbackSpeed: 16.0,
              onPlaybackSpeedSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await openMenu(tester);

    final increaseButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.add),
    );
    expect(increaseButton.onPressed, isNull);

    decreaseButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.remove),
    );
    expect(decreaseButton.onPressed, isNotNull);
  });
}
