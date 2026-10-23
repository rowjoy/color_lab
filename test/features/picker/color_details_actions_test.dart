import 'package:color_lab/app.dart';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/picker/application/color_share_service.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:color_lab/features/room_studio/application/room_color_provider.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_color_history_repository.dart';
import '../../support/in_memory_app_preferences_repository.dart';
import '../../support/in_memory_acquisition_intent_store.dart';

class RecordingShare implements ColorShareService {
  RgbColor? color;
  Rect? origin;
  bool fail = false;
  @override
  Future<void> shareColor({
    required RgbColor color,
    String? name,
    required Rect origin,
  }) async {
    if (fail) throw StateError('native error must not leak');
    this.color = color;
    this.origin = origin;
  }
}

void main() {
  Future<ProviderContainer> open(
    WidgetTester tester,
    RecordingShare share,
  ) async {
    final container = ProviderContainer(
      overrides: [
        acquisitionIntentStoreProvider.overrideWith(
          (ref) async => InMemoryAcquisitionIntentStore(),
        ),
        appPreferencesRepositoryProvider.overrideWith(
          (ref) async => InMemoryAppPreferencesRepository(),
        ),
        colorShareServiceProvider.overrideWithValue(share),
        colorNamerProvider.overrideWith(
          (ref) async => ColorNamer([NamedColor('Red', RgbColor(255, 0, 0))]),
        ),
        colorHistoryRepositoryProvider.overrideWith(
          (ref) async => InMemoryColorHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ColorLabApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Explore a color'));
    await tester.tap(find.text('Explore a color'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('hex-input')), '#FF0000');
    await tester.tap(find.text('View color'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('shares sampled color with a nonempty popover anchor', (
    tester,
  ) async {
    final share = RecordingShare();
    await open(tester, share);
    await tester.ensureVisible(find.text('Share color'));
    await tester.tap(find.text('Share color'));
    await tester.pumpAndSettle();
    expect(share.color?.hex, '#FF0000');
    expect(share.origin!.width, greaterThan(0));
    expect(share.origin!.height, greaterThan(0));
  });

  testWidgets('share failure is friendly and retry stays available', (
    tester,
  ) async {
    final share = RecordingShare()..fail = true;
    await open(tester, share);
    await tester.ensureVisible(find.text('Share color'));
    await tester.tap(find.text('Share color'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not share this color. Please try again.'),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Could not share this color. Please try again.'),
        matching: find.byType(ColorDetails),
      ),
      findsOneWidget,
    );
    share.fail = false;
    await tester.tap(find.text('Share color'));
    await tester.pumpAndSettle();
    expect(share.color?.hex, '#FF0000');
  });

  testWidgets(
    'harmony replaces details and Use in Room sets the illustrated wall shade',
    (tester) async {
      final container = await open(tester, RecordingShare());
      await tester.ensureVisible(find.byKey(const ValueKey('harmony-#00FFFF')));
      await tester.tap(find.byKey(const ValueKey('harmony-#00FFFF')));
      await tester.pumpAndSettle();
      expect(find.byType(ColorDetails), findsOneWidget);
      await tester.ensureVisible(find.text('Use in Room'));
      await tester.tap(find.text('Use in Room'));
      await tester.pumpAndSettle();
      expect(container.read(roomColorProvider).hex, '#00FFFF');
      expect(find.byKey(const ValueKey('screen-Room')), findsOneWidget);
    },
  );
}
