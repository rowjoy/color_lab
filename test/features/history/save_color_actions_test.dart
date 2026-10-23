import 'dart:async';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:color_lab/features/history/presentation/save_color_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_color_history_repository.dart';

void main() {
  Future<ProviderContainer> launch(
    WidgetTester tester,
    InMemoryColorHistoryRepository repository,
  ) async {
    final container = ProviderContainer(
      overrides: [
        colorHistoryRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SaveColorActions(
              color: RgbColor(255, 0, 0),
              name: 'Red',
              source: ColorSource.lab,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('saves a color with its source and persists favorite changes', (
    tester,
  ) async {
    final container = await launch(tester, InMemoryColorHistoryRepository());
    await tester.tap(find.text('Save color'));
    await tester.pumpAndSettle();
    expect(find.text('Saved to library'), findsOneWidget);
    expect(
      container.read(colorHistoryProvider).requireValue.single.source,
      ColorSource.lab,
    );
    await tester.tap(find.text('Add to favorites'));
    await tester.pumpAndSettle();
    expect(find.text('In your favorites'), findsOneWidget);
    expect(
      container.read(colorHistoryProvider).requireValue.single.isFavorite,
      isTrue,
    );
  });

  testWidgets('failed save shows friendly feedback and can be retried', (
    tester,
  ) async {
    final repository = InMemoryColorHistoryRepository()..failWrites = true;
    final container = await launch(tester, repository);
    await tester.tap(find.text('Save color'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save this color. Try again."), findsOneWidget);
    expect(find.textContaining('private storage'), findsNothing);
    expect(container.read(colorHistoryProvider).requireValue, isEmpty);
    repository.failWrites = false;
    await tester.tap(find.text('Save color'));
    await tester.pumpAndSettle();
    expect(find.text('Saved to library'), findsOneWidget);
  });

  testWidgets('unavailable storage offers retry before saving', (tester) async {
    final repository = InMemoryColorHistoryRepository()..failLoad = true;
    await launch(tester, repository);
    expect(find.text('Retry storage'), findsOneWidget);
    repository.failLoad = false;
    await tester.tap(find.text('Retry storage'));
    await tester.pumpAndSettle();
    expect(find.text('Save color'), findsOneWidget);
  });

  testWidgets('save safely finishes after its widget is dismissed', (
    tester,
  ) async {
    final repository = InMemoryColorHistoryRepository()
      ..writeGate = Completer<void>();
    final container = await launch(tester, repository);
    await tester.tap(find.text('Save color'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    repository.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      container.read(colorHistoryProvider).requireValue.single.hex,
      '#FF0000',
    );
  });

  testWidgets('unavailable haptics do not report a durable save as failed', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        throw PlatformException(code: 'haptics-unavailable');
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final container = await launch(tester, InMemoryColorHistoryRepository());
    await tester.tap(find.text('Save color'));
    await tester.pumpAndSettle();
    expect(find.text('Saved to library'), findsOneWidget);
    expect(find.text("Couldn't save this color. Try again."), findsNothing);
    expect(
      container.read(colorHistoryProvider).requireValue.single.hex,
      '#FF0000',
    );
  });
}
