import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {bool reducedMotion = false, double scale = 1}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: reducedMotion,
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets(
    'slider announcements use candidate values despite a display label',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          LabeledSlider(
            label: 'Lightness',
            value: .5,
            divisions: 10,
            valueLabel: '50 percent',
            onChanged: (_) {},
          ),
        ),
      );
      final data = tester.getSemantics(find.byType(Slider)).getSemanticsData();
      expect(data.value, '0.50');
      expect(data.increasedValue, '0.60');
      expect(data.decreasedValue, '0.40');
      expect(find.text('50 percent'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('slider formats each candidate as a percentage', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        LabeledSlider(
          label: 'Lightness',
          value: .5,
          divisions: 10,
          valueLabel: '50%',
          onChanged: (_) {},
          valueFormatter: (v) => '${(v * 100).round()} percent',
        ),
      ),
    );
    final data = tester.getSemantics(find.byType(Slider)).getSemanticsData();
    expect(data.value, '50 percent');
    expect(data.increasedValue, '60 percent');
    expect(data.decreasedValue, '40 percent');
    expect(find.text('50%'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('tapping a displayed value copies it once and shows feedback', (
    tester,
  ) async {
    final copied = <String>[];
    var notifications = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      host(
        ValueRow(
          label: 'HEX',
          value: '#6C5CE7',
          onCopied: () => notifications++,
        ),
      ),
    );
    await tester.tap(find.text('#6C5CE7'));
    await tester.pump();
    expect(copied, ['#6C5CE7']);
    expect(notifications, 1);
    expect(find.text('HEX copied'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy HEX'));
    await tester.pump();
    expect(copied, ['#6C5CE7', '#6C5CE7']);
    expect(notifications, 2);
  });

  testWidgets(
    'primary gradient label stays readable at both gradient ends in either theme',
    (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: PrimaryButton(label: 'Create', onPressed: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.byType(PrimaryButton);
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(of: button, matching: find.byType(DecoratedBox))
              .first,
        );
        final gradient = (box.decoration as BoxDecoration).gradient!;
        final material = tester.widget<Material>(
          find.descendant(of: button, matching: find.byType(Material)).first,
        );
        final foreground = tester
            .widget<Text>(find.text('Create'))
            .style!
            .color!;
        for (final color in gradient.colors) {
          final background = Color.alphaBlend(material.color!, color);
          expect(
            (foreground.computeLuminance() + .05) /
                (background.computeLuminance() + .05),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    },
  );

  testWidgets(
    'interactive palette keeps weighted bar and generous tap targets',
    (tester) async {
      int? selected;
      await tester.pumpWidget(
        host(
          PaletteBar(
            colors: const [Colors.red, Colors.blue],
            weights: const [3, 1],
            onColorTap: (index) => selected = index,
          ),
        ),
      );
      final red = find.byWidgetPredicate(
        (w) => w is Material && w.color == Colors.red,
      );
      final blue = find.byWidgetPredicate(
        (w) => w is Material && w.color == Colors.blue,
      );
      expect(
        tester.getSize(red).width / tester.getSize(blue).width,
        closeTo(3, .01),
      );
      expect(
        tester.getSize(find.byType(ColorChip).last).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.text('Color 2 · 25%'));
      expect(selected, 1);
    },
  );

  testWidgets('sheet scrolls large content and closes with its result', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => PrimaryButton(
            label: 'Open sheet',
            onPressed: () async {
              result = await AppBottomSheet.show<String>(
                context,
                title: 'Color details',
                child: Builder(
                  builder: (sheetContext) => Column(
                    children: [
                      for (var i = 0; i < 20; i++)
                        const ValueRow(
                          label: 'HEX',
                          value: '#6C5CE7',
                          copyable: false,
                        ),
                      PrimaryButton(
                        label: 'Use color',
                        onPressed: () =>
                            Navigator.pop(sheetContext, 'selected'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Color details'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Use color'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Use color'));
    await tester.pumpAndSettle();
    expect(result, 'selected');
  });

  testWidgets('accessible buttons expose tap actions and disabled state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        Column(
          children: [
            PrimaryButton(label: 'Create', onPressed: () {}),
            const SecondaryButton(label: 'Disabled', onPressed: null),
            ColorChip(color: Colors.purple, label: 'Purple', onTap: () {}),
          ],
        ),
      ),
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Create'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Disabled'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Purple'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    handle.dispose();
  });

  testWidgets(
    'buttons invoke callbacks and suppress disabled or loading taps',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        host(
          Column(
            children: [
              PrimaryButton(label: 'Create', onPressed: () => calls++),
              const SecondaryButton(label: 'Disabled', onPressed: null),
              PrimaryButton(
                label: 'Saving',
                isLoading: true,
                onPressed: () => calls++,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Create'));
      await tester.tap(find.text('Disabled'));
      await tester.tap(find.text('Saving'));
      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.getSize(find.byType(PrimaryButton).first).height,
        greaterThanOrEqualTo(48),
      );
    },
  );

  testWidgets('slider reports changes and a swatch responds to taps', (
    tester,
  ) async {
    var tapped = false;
    double value = 0;
    await tester.pumpWidget(
      host(
        Column(
          children: [
            LabeledSlider(
              label: 'Lightness',
              value: 0,
              onChanged: (v) => value = v,
            ),
            ColorSwatchTile(
              color: Colors.purple,
              name: 'Lavender',
              hex: '#6C5CE7',
              onTap: () => tapped = true,
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byType(Slider));
    await tester.tap(find.text('Lavender'));
    expect(value, greaterThan(0));
    expect(tapped, isTrue);
  });

  testWidgets('copyable values put the value on clipboard and show feedback', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      host(const ValueRow(label: 'HEX', value: '#6C5CE7')),
    );
    await tester.tap(find.byTooltip('Copy HEX'));
    await tester.pump();
    expect(copied, '#6C5CE7');
    expect(find.text('HEX copied'), findsOneWidget);
  });

  testWidgets('shared text controls fit a narrow screen at double text size', (
    tester,
  ) async {
    tester.view.reset();
    tester.view.physicalSize = const Size(360, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      host(
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SectionHeader(
                  title: 'Explore your colors',
                  subtitle: 'A thoughtful collection',
                  trailing: Icon(Icons.palette_rounded),
                ),
                PrimaryButton(
                  label: 'Create a beautiful new palette',
                  icon: Icons.add_rounded,
                  onPressed: () {},
                ),
                const SecondaryButton(
                  label: 'Choose a photograph from your gallery',
                  onPressed: null,
                ),
                ColorSwatchTile(
                  color: Colors.purple,
                  name: 'A beautifully descriptive lavender',
                  hex: '#6C5CE7',
                  onTap: () {},
                ),
                const ValueRow(label: 'Color value', value: '#6C5CE7'),
                ColorChip(
                  color: Colors.purple,
                  label: 'Descriptive lavender color',
                  onTap: () {},
                ),
                PaletteBar(
                  colors: const [Colors.purple, Colors.pink],
                  weights: const [9, 1],
                  onColorTap: (_) {},
                ),
                const LabeledSlider(
                  label: 'Color lightness amount',
                  value: .5,
                  valueLabel: '50 percent',
                  onChanged: null,
                ),
                const EmptyState(
                  icon: Icons.palette_rounded,
                  title: 'Your next great palette',
                  message: 'Collect colors from the world around you.',
                ),
              ],
            ),
          ),
        ),
        scale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion shimmer is static and announces loading', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(const LoadingShimmer(width: 200, height: 80), reducedMotion: true),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    semantics.dispose();
  });
}
