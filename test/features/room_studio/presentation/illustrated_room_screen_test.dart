import 'dart:async';
import 'dart:typed_data';

import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/core/widgets/buttons.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_artwork_encoder.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_export_controller.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/application/room_gallery_writer.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_controls.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_screen.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_room_design_repository.dart';
import '../../../support/in_memory_color_history_repository.dart';

final class _EditorHarness {
  const _EditorHarness(this.container);

  final ProviderContainer container;

  IllustratedRoomDraft get studyDraft =>
      container.read(illustratedRoomProvider).draftFor('study')!;
}

final class _TestArtworkEncoder implements IllustratedRoomArtworkEncoder {
  _TestArtworkEncoder({this.failure});

  final Object? failure;
  int calls = 0;

  @override
  Future<Uint8List> encodePng(IllustratedRoomDraft draft) async {
    calls++;
    if (failure case final error?) throw error;
    return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  }
}

final class _TestGalleryWriter implements RoomGalleryWriter {
  _TestGalleryWriter({this.failure, this.onSave});

  final Object? failure;
  final Future<void> Function()? onSave;
  int calls = 0;

  @override
  Future<void> savePng({
    required Uint8List pngBytes,
    required String fileName,
  }) async {
    calls++;
    if (failure case final error?) throw error;
    await onSave?.call();
  }
}

Future<_EditorHarness> _pumpEditor(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  double keyboardInset = 0,
  EdgeInsets padding = EdgeInsets.zero,
  bool disableAnimations = false,
  ThemeMode themeMode = ThemeMode.light,
  String templateId = 'study',
  IllustratedRoomArtworkEncoder? artworkEncoder,
  RoomGalleryWriter? galleryWriter,
  RoomGallerySettings? gallerySettings,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = InMemoryRoomDesignRepository(
    clock: () => DateTime.utc(2026, 10, 25, 4),
  );
  addTearDown(repository.close);
  final historyRepository = InMemoryColorHistoryRepository();
  addTearDown(historyRepository.close);
  final container = ProviderContainer(
    overrides: [
      colorHistoryRepositoryProvider.overrideWith(
        (ref) async => historyRepository,
      ),
      roomDesignRepositoryProvider.overrideWith((ref) async => repository),
      roomDesignClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 10, 25, 4),
      ),
      roomExportClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 10, 25, 4),
      ),
      if (artworkEncoder != null)
        illustratedRoomArtworkEncoderProvider.overrideWithValue(artworkEncoder),
      if (galleryWriter != null)
        roomGalleryWriterProvider.overrideWithValue(galleryWriter),
      if (gallerySettings != null)
        roomGallerySettingsProvider.overrideWithValue(gallerySettings),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              padding: padding,
              viewPadding: padding,
              viewInsets: EdgeInsets.only(bottom: keyboardInset),
              disableAnimations: disableAnimations,
            ),
            child: IllustratedRoomScreen(templateId: templateId),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _EditorHarness(container);
}

Finder _key(String value, {bool skipOffstage = false}) =>
    find.byKey(ValueKey(value), skipOffstage: skipOffstage);

Future<void> _tapKey(WidgetTester tester, String value) async {
  final finder = _key(value);
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _ensureColorToolsVisible(WidgetTester tester) async {
  final show = _key('room-show-color-tools').hitTestable();
  if (show.evaluate().isEmpty) return;
  await tester.tap(show);
  await tester.pumpAndSettle();
}

Future<void> _prepareGalleryTap(WidgetTester tester) async {
  await _ensureColorToolsVisible(tester);
  final gallery = _key('room-save-gallery');
  expect(gallery, findsOneWidget);
  await tester.ensureVisible(gallery);
  await tester.pumpAndSettle();
}

Future<void> _tapGalleryAndShowFeedback(WidgetTester tester) async {
  await _prepareGalleryTap(tester);
  await tester.tap(_key('room-save-gallery'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'phone starts with full-width scene and hidden rail then toggles tools',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pumpEditor(
          tester,
          size: const Size(390, 844),
          disableAnimations: true,
        );

        final scene = _key('room-scene');
        final sceneRect = tester.getRect(scene);
        expect(sceneRect, const Rect.fromLTWH(0, 0, 390, 844));
        expect(_key('room-color-rail').hitTestable(), findsNothing);
        expect(find.bySemanticsLabel('Looks'), findsNothing);
        expect(_key('room-show-color-tools').hitTestable(), findsOneWidget);
        expect(
          tester.getSize(_key('room-show-color-tools')).shortestSide,
          greaterThanOrEqualTo(48),
        );

        await _tapKey(tester, 'room-show-color-tools');
        expect(_key('room-color-rail').hitTestable(), findsOneWidget);
        expect(_key('room-hide-color-tools').hitTestable(), findsOneWidget);
        expect(find.bySemanticsLabel('Hide color tools'), findsOneWidget);
        expect(tester.getRect(scene), sceneRect);

        await _tapKey(tester, 'room-rail-looks');
        expect(_key('room-flyout'), findsOneWidget);
        await _tapKey(tester, 'room-hide-color-tools');

        expect(_key('room-color-rail').hitTestable(), findsNothing);
        expect(find.bySemanticsLabel('Looks'), findsNothing);
        expect(_key('room-flyout'), findsNothing);
        expect(_key('room-show-color-tools').hitTestable(), findsOneWidget);
        expect(tester.getRect(scene), sceneRect);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('tablet starts with rail visible and can hide and show it', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      size: const Size(1024, 768),
      disableAnimations: true,
    );
    final scene = _key('room-scene');
    final sceneRect = tester.getRect(scene);

    expect(_key('room-color-rail').hitTestable(), findsOneWidget);
    expect(_key('room-show-color-tools').hitTestable(), findsNothing);
    await _tapKey(tester, 'room-hide-color-tools');
    expect(_key('room-color-rail').hitTestable(), findsNothing);
    expect(_key('room-show-color-tools').hitTestable(), findsOneWidget);
    expect(tester.getRect(scene), sceneRect);

    await _tapKey(tester, 'room-show-color-tools');
    expect(_key('room-color-rail').hitTestable(), findsOneWidget);
    expect(_key('room-show-color-tools').hitTestable(), findsNothing);
    expect(tester.getRect(scene), sceneRect);
  });

  testWidgets('explicit rail choice survives crossing the 720dp breakpoint', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      size: const Size(719, 768),
      disableAnimations: true,
    );
    expect(_key('room-color-rail').hitTestable(), findsNothing);

    tester.view.physicalSize = const Size(720, 768);
    await tester.pumpAndSettle();
    expect(_key('room-color-rail').hitTestable(), findsOneWidget);

    await _tapKey(tester, 'room-hide-color-tools');
    tester.view.physicalSize = const Size(719, 768);
    await tester.pumpAndSettle();
    expect(_key('room-color-rail').hitTestable(), findsNothing);

    tester.view.physicalSize = const Size(720, 768);
    await tester.pumpAndSettle();
    expect(_key('room-color-rail').hitTestable(), findsNothing);

    tester.view.physicalSize = const Size(719, 768);
    await tester.pumpAndSettle();
    await _tapKey(tester, 'room-show-color-tools');
    tester.view.physicalSize = const Size(720, 768);
    await tester.pumpAndSettle();
    expect(_key('room-color-rail').hitTestable(), findsOneWidget);

    tester.view.physicalSize = const Size(719, 768);
    await tester.pumpAndSettle();
    expect(_key('room-color-rail').hitTestable(), findsOneWidget);
  });

  testWidgets('responsive auto-hide clears an open flyout', (tester) async {
    await _pumpEditor(
      tester,
      size: const Size(720, 768),
      disableAnimations: true,
    );
    await _tapKey(tester, 'room-rail-looks');
    expect(_key('room-flyout'), findsOneWidget);

    tester.view.physicalSize = const Size(719, 768);
    await tester.pumpAndSettle();
    expect(_key('room-flyout'), findsNothing);
    expect(_key('room-show-color-tools').hitTestable(), findsOneWidget);

    await _tapKey(tester, 'room-show-color-tools');
    expect(_key('room-flyout'), findsNothing);
    expect(
      tester
          .widget<IllustratedRoomColorRail>(
            find.byType(IllustratedRoomColorRail),
          )
          .activeTool,
      isNull,
    );
  });

  testWidgets(
    'Focus preserves responsive defaults and explicit hidden choice',
    (tester) async {
      await _pumpEditor(
        tester,
        size: const Size(719, 768),
        disableAnimations: true,
      );

      await _tapKey(tester, 'room-focus-preview');
      await _tapKey(tester, 'room-exit-focus-preview');
      expect(_key('room-color-rail').hitTestable(), findsNothing);

      tester.view.physicalSize = const Size(720, 768);
      await tester.pumpAndSettle();
      expect(_key('room-color-rail').hitTestable(), findsOneWidget);

      await _tapKey(tester, 'room-hide-color-tools');
      await _tapKey(tester, 'room-focus-preview');
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(_key('room-exit-focus-preview'), findsNothing);
      expect(_key('room-color-rail').hitTestable(), findsNothing);

      tester.view.physicalSize = const Size(719, 768);
      await tester.pumpAndSettle();
      expect(_key('room-color-rail').hitTestable(), findsNothing);
      tester.view.physicalSize = const Size(720, 768);
      await tester.pumpAndSettle();
      expect(_key('room-color-rail').hitTestable(), findsNothing);
    },
  );

  testWidgets(
    'Focus Preview hides chrome and restores rail fit and exact draft',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final harness = await _pumpEditor(
          tester,
          size: const Size(390, 844),
          disableAnimations: true,
        );
        harness.container
            .read(illustratedRoomProvider.notifier)
            .applyPalette('soft-botanical');
        await tester.pumpAndSettle();
        final before = harness.studyDraft;

        await _tapKey(tester, 'room-show-color-tools');
        await _tapKey(tester, 'room-view-full');
        expect(
          tester
              .widget<IllustratedRoomSvg>(find.byType(IllustratedRoomSvg))
              .fit,
          BoxFit.contain,
        );

        await _tapKey(tester, 'room-focus-preview');

        for (final key in [
          'room-editor-back',
          'room-editor-title',
          'room-view-fill',
          'room-view-full',
          'room-color-rail',
          'room-flyout',
        ]) {
          expect(_key(key).hitTestable(), findsNothing, reason: key);
        }
        for (final label in [
          'Back',
          'Fill screen',
          'See whole room',
          'Looks',
        ]) {
          expect(find.bySemanticsLabel(label), findsNothing, reason: label);
        }
        expect(_key('room-exit-focus-preview').hitTestable(), findsOneWidget);
        expect(
          tester.getSize(_key('room-exit-focus-preview')).shortestSide,
          greaterThanOrEqualTo(48),
        );
        expect(harness.studyDraft, same(before));
        expect(
          tester
              .widget<IllustratedRoomSvg>(find.byType(IllustratedRoomSvg))
              .fit,
          BoxFit.contain,
        );

        await _tapKey(tester, 'room-exit-focus-preview');

        expect(_key('room-color-rail').hitTestable(), findsOneWidget);
        expect(_key('room-view-full').hitTestable(), findsOneWidget);
        expect(harness.studyDraft, same(before));
        expect(
          tester
              .widget<IllustratedRoomSvg>(find.byType(IllustratedRoomSvg))
              .fit,
          BoxFit.contain,
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'Back exits focus then flyout then compact rail before dirty exit',
    (tester) async {
      final harness = await _pumpEditor(
        tester,
        size: const Size(390, 844),
        disableAnimations: true,
      );
      harness.container
          .read(illustratedRoomProvider.notifier)
          .applyPalette('warm-natural');
      await tester.pumpAndSettle();
      final before = harness.studyDraft;

      await _tapKey(tester, 'room-show-color-tools');
      await _tapKey(tester, 'room-focus-preview');
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(_key('room-exit-focus-preview'), findsNothing);
      expect(_key('room-color-rail').hitTestable(), findsOneWidget);
      expect(harness.studyDraft, same(before));
      expect(find.text('Keep this draft?'), findsNothing);

      await _tapKey(tester, 'room-rail-looks');
      expect(_key('room-flyout'), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(_key('room-flyout'), findsNothing);
      expect(_key('room-color-rail').hitTestable(), findsOneWidget);
      expect(harness.studyDraft, same(before));
      expect(find.text('Keep this draft?'), findsNothing);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(_key('room-color-rail').hitTestable(), findsNothing);
      expect(_key('room-show-color-tools').hitTestable(), findsOneWidget);
      expect(harness.studyDraft, same(before));
      expect(find.text('Keep this draft?'), findsNothing);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Keep this draft?'), findsOneWidget);
      expect(harness.studyDraft, same(before));
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('scene tap closes a compact rail and its flyout', (tester) async {
    final harness = await _pumpEditor(
      tester,
      size: const Size(390, 844),
      disableAnimations: true,
    );
    final before = harness.studyDraft;

    await _tapKey(tester, 'room-show-color-tools');
    await _tapKey(tester, 'room-rail-looks');
    expect(_key('room-flyout'), findsOneWidget);

    await tester.tapAt(const Offset(20, 240));
    await tester.pumpAndSettle();

    expect(_key('room-flyout'), findsNothing);
    expect(_key('room-color-rail').hitTestable(), findsNothing);
    expect(_key('room-show-color-tools').hitTestable(), findsOneWidget);
    expect(harness.studyDraft, same(before));
  });

  testWidgets(
    '320dp phone at 2x text keeps controls reachable without overflow',
    (tester) async {
      await _pumpEditor(
        tester,
        size: const Size(320, 568),
        textScale: 2,
        disableAnimations: true,
      );

      for (final key in [
        'room-editor-back',
        'room-view-fill',
        'room-view-full',
        'room-focus-preview',
        'room-show-color-tools',
      ]) {
        expect(_key(key).hitTestable(), findsOneWidget, reason: key);
        expect(
          tester.getSize(_key(key)).shortestSide,
          greaterThanOrEqualTo(48),
        );
      }
      await _tapKey(tester, 'room-show-color-tools');
      expect(_key('room-hide-color-tools').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('640x360 landscape keeps rail scrollable and hide reachable', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      size: const Size(640, 360),
      padding: const EdgeInsets.only(left: 24, right: 44),
      disableAnimations: true,
    );
    const safeRight = 640.0 - 44;
    expect(
      tester.getRect(_key('room-editor-back')).left,
      greaterThanOrEqualTo(32),
    );
    expect(
      tester.getRect(_key('room-show-color-tools')).right,
      lessThanOrEqualTo(safeRight),
    );
    await _tapKey(tester, 'room-show-color-tools');

    expect(_key('room-color-rail-scroll'), findsOneWidget);
    expect(tester.getRect(_key('room-color-rail')).right, safeRight);
    expect(_key('room-hide-color-tools').hitTestable(), findsOneWidget);
    await tester.ensureVisible(_key('room-save-gallery'));
    await tester.pumpAndSettle();
    expect(_key('room-save-gallery').hitTestable(), findsOneWidget);
    await tester.ensureVisible(_key('room-hide-color-tools'));
    await tester.pumpAndSettle();
    expect(_key('room-hide-color-tools').hitTestable(), findsOneWidget);

    await _tapKey(tester, 'room-focus-preview');
    expect(
      tester.getRect(_key('room-exit-focus-preview')).right,
      lessThanOrEqualTo(safeRight),
    );
    expect(tester.takeException(), isNull);
  });

  for (final scenario
      in <({String name, Size size, double scale, double inset})>[
        (name: 'small phone', size: const Size(320, 568), scale: 1, inset: 0),
        (
          name: 'phone at 2x text',
          size: const Size(390, 844),
          scale: 2,
          inset: 0,
        ),
        (
          name: 'short landscape',
          size: const Size(640, 360),
          scale: 1,
          inset: 0,
        ),
        (name: 'tablet', size: const Size(1024, 768), scale: 1, inset: 0),
        (
          name: 'keyboard inset',
          size: const Size(390, 844),
          scale: 1,
          inset: 300,
        ),
      ]) {
    testWidgets(
      '${scenario.name} keeps a full-bleed scene behind overlay controls',
      (tester) async {
        await _pumpEditor(
          tester,
          size: scenario.size,
          textScale: scenario.scale,
          keyboardInset: scenario.inset,
        );

        final scene = _key('room-scene');
        final originalSceneRect = tester.getRect(scene);
        expect(originalSceneRect.topLeft, Offset.zero);
        expect(originalSceneRect.size, scenario.size);
        expect(_key('room-editor-title'), findsOneWidget);

        await _ensureColorToolsVisible(tester);
        final rail = _key('room-color-rail');
        expect(tester.getSize(rail).width, scenario.size.width < 720 ? 68 : 72);
        await _tapKey(tester, 'room-rail-looks');
        expect(_key('room-flyout'), findsOneWidget);
        expect(
          tester.getSize(_key('room-flyout')).width,
          inInclusiveRange(232, 300),
        );
        expect(tester.getRect(scene), originalSceneRect);

        for (final key in [
          'room-editor-back',
          'room-view-fill',
          'room-view-full',
        ]) {
          final target = _key(key);
          expect(target, findsOneWidget);
          expect(tester.getSize(target).shortestSide, greaterThanOrEqualTo(48));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [719.0, 720.0]) {
    testWidgets('rail changes width at ${width.toInt()}dp', (tester) async {
      await _pumpEditor(tester, size: Size(width, 768));
      if (width < 720) await _tapKey(tester, 'room-show-color-tools');
      expect(
        tester.getSize(_key('room-color-rail')).width,
        width < 720 ? 68 : 72,
      );
    });
  }

  testWidgets('starts grayscale with exact looks and disabled save actions', (
    tester,
  ) async {
    final harness = await _pumpEditor(tester);

    expect(harness.studyDraft.mode, IllustratedRoomVisualMode.grayscale);
    expect(find.textContaining('Black & white'), findsWidgets);
    expect(
      tester.widget<IllustratedRoomSvg>(find.byType(IllustratedRoomSvg)).fit,
      BoxFit.cover,
    );
    expect(
      tester
          .widget<IllustratedRoomSvg>(find.byType(IllustratedRoomSvg))
          .alignment,
      const Alignment(0, 0),
    );

    await _ensureColorToolsVisible(tester);
    await _tapKey(tester, 'room-rail-looks');
    for (final palette in IllustratedRoomCatalog.study.palettes) {
      expect(_key('room-palette-${palette.id}'), findsOneWidget);
      expect(find.text(palette.name), findsOneWidget);
    }
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Why these looks?'), findsOneWidget);

    await _tapKey(tester, 'room-open-designs');
    final save = _key('room-save-design');
    expect(save, findsOneWidget);
    expect(tester.widget<PrimaryButton>(save).onPressed, isNull);
    expect(
      tester
          .widget<IllustratedRoomColorRail>(
            find.byType(IllustratedRoomColorRail),
          )
          .onSaveToGallery,
      isNull,
    );
  });

  testWidgets('living room exposes and applies all eight generic looks', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final harness = await _pumpEditor(
        tester,
        templateId: 'living',
        disableAnimations: true,
      );
      await _ensureColorToolsVisible(tester);
      await _tapKey(tester, 'room-rail-looks');

      const paletteIds = [
        'warm-natural',
        'soft-botanical',
        'cool-airy',
        'soft-pink-earthy-neutrals',
        'coral-peach-layers',
        'white-gentle-grey',
        'pink-lavender-pairing',
        'peach-coral-glow',
      ];
      for (final id in paletteIds) {
        expect(_key('room-palette-$id'), findsOneWidget);
      }

      await _tapKey(tester, 'room-palette-peach-coral-glow');
      final draft = harness.container
          .read(illustratedRoomProvider)
          .draftFor('living')!;
      expect(draft.sourcePaletteId, 'peach-coral-glow');
      expect(draft.colors!.wall.hex, '#F1B89B');
      expect(draft.colors!.ceiling.hex, '#F8F4EB');
      expect(draft.colors!.floor.hex, '#C5AD8A');
      expect(draft.colors!.furniture.hex, '#EDA28E');
      expect(
        tester.getSemantics(find.bySemanticsLabel('Peach and Coral Glow')),
        matchesSemantics(
          label: 'Peach and Coral Glow',
          hasSelectedState: true,
          isButton: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );

      await _tapKey(tester, 'room-surface-wall');
      expect(
        find.text('Suggestions come from the complete room looks.'),
        findsOneWidget,
      );
      expect(
        find.text('Suggestions come from the three complete room looks.'),
        findsNothing,
      );
      for (final hex in [
        'E6D8C3',
        'C4D3C1',
        'D3E0E4',
        'E5C8BE',
        'E49473',
        'C8C8C6',
        'DFCAC9',
        'F1B89B',
      ]) {
        expect(_key('room-suggestion-wall-$hex'), findsOneWidget);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'colored Gallery export is single-flight, busy and non-mutating',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final entered = Completer<void>();
        final release = Completer<void>();
        final encoder = _TestArtworkEncoder();
        final writer = _TestGalleryWriter(
          onSave: () async {
            entered.complete();
            await release.future;
          },
        );
        final harness = await _pumpEditor(
          tester,
          artworkEncoder: encoder,
          galleryWriter: writer,
          disableAnimations: true,
        );
        harness.container
            .read(illustratedRoomProvider.notifier)
            .applyPalette('soft-botanical');
        await tester.pumpAndSettle();
        final before = harness.studyDraft;
        await _prepareGalleryTap(tester);

        final gallery = _key('room-save-gallery');
        await tester.tap(gallery);
        await tester.tap(gallery);
        await tester.pump();

        expect(entered.isCompleted, isTrue);
        expect(encoder.calls, 1);
        expect(writer.calls, 1);
        final busyRail = tester.widget<IllustratedRoomColorRail>(
          find.byType(IllustratedRoomColorRail),
        );
        expect(busyRail.exportBusy, isTrue);
        expect(busyRail.onSaveToGallery, isNull);
        expect(
          find.descendant(
            of: gallery,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );

        release.complete();
        await tester.pump();
        final feedback = find.text('Saved to Gallery');
        expect(feedback, findsOneWidget);
        final feedbackElement = feedback.evaluate().single;
        await tester.pump(const Duration(milliseconds: 300));

        expect(feedback, findsOneWidget);
        expect(feedback.evaluate().single, same(feedbackElement));
        expect(find.bySemanticsLabel('Saved to Gallery'), findsOneWidget);
        expect(
          tester.getSemantics(find.bySemanticsLabel('Saved to Gallery')),
          matchesSemantics(
            label: 'Saved to Gallery',
            isLiveRegion: true,
            textDirection: TextDirection.ltr,
          ),
        );
        expect(harness.studyDraft, same(before));
        final idleRail = tester.widget<IllustratedRoomColorRail>(
          find.byType(IllustratedRoomColorRail),
        );
        expect(idleRail.exportBusy, isFalse);
        expect(idleRail.onSaveToGallery, isNotNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('Fill and Full room switch fit without moving the scene', (
    tester,
  ) async {
    await _pumpEditor(tester, size: const Size(640, 360));
    final sceneRect = tester.getRect(_key('room-scene'));

    await _tapKey(tester, 'room-view-full');
    expect(
      tester.widget<IllustratedRoomSvg>(find.byType(IllustratedRoomSvg)).fit,
      BoxFit.contain,
    );
    expect(tester.getRect(_key('room-scene')), sceneRect);

    await _tapKey(tester, 'room-view-fill');
    expect(
      tester.widget<IllustratedRoomSvg>(find.byType(IllustratedRoomSvg)).fit,
      BoxFit.cover,
    );
  });

  testWidgets('Looks apply all four colors and expose contextual semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final harness = await _pumpEditor(tester, disableAnimations: true);
      await _ensureColorToolsVisible(tester);
      await _tapKey(tester, 'room-rail-looks');
      await _tapKey(tester, 'room-palette-warm-natural');

      final colors = harness.studyDraft.colors!;
      expect(colors.wall.hex, '#E2D5BF');
      expect(colors.ceiling.hex, '#F8F4EB');
      expect(colors.floor.hex, '#C5AA84');
      expect(colors.furniture.hex, '#72513D');
      expect(
        find.bySemanticsLabel(
          'Study room. Warm Natural. Wall #E2D5BF. Ceiling #F8F4EB. '
          'Floor #C5AA84. Desk & furniture #72513D.',
        ),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('surface flyout derives suggestions and contextual labels', (
    tester,
  ) async {
    await _pumpEditor(tester);
    await _ensureColorToolsVisible(tester);
    await _tapKey(tester, 'room-surface-furniture');

    expect(find.text('Desk & furniture'), findsWidgets);
    for (final hex in ['72513D', '654A39', '465967']) {
      final suggestion = _key('room-suggestion-furniture-$hex');
      expect(suggestion, findsOneWidget);
      expect(tester.getSize(suggestion).shortestSide, greaterThanOrEqualTo(48));
    }
    expect(_key('room-custom-color'), findsOneWidget);
  });

  testWidgets('first custom color seeds the recommended look', (tester) async {
    final harness = await _pumpEditor(tester);
    await _ensureColorToolsVisible(tester);
    await _tapKey(tester, 'room-surface-ceiling');
    await _tapKey(tester, 'room-custom-color');

    await tester.enterText(
      find.byKey(const ValueKey('mixer-hex-input')),
      '#123456',
    );
    await tester.tap(find.widgetWithText(PrimaryButton, 'Use this color'));
    await tester.pumpAndSettle();

    final colors = harness.studyDraft.colors!;
    expect(colors.wall.hex, '#B7C5B3');
    expect(colors.ceiling.hex, '#123456');
    expect(colors.floor.hex, '#C6AC84');
    expect(colors.furniture.hex, '#654A39');
    expect(harness.studyDraft.visualStateLabel, 'Custom combination');
  });

  testWidgets('market guide explains provenance and physical swatches', (
    tester,
  ) async {
    await _pumpEditor(tester, themeMode: ThemeMode.dark);
    await _ensureColorToolsVisible(tester);
    await _tapKey(tester, 'room-rail-looks');
    await _tapKey(tester, 'room-market-guide');

    expect(find.text('Why these looks?'), findsWidgets);
    expect(
      find.text(IllustratedRoomCatalog.study.paletteReviewLabel),
      findsOneWidget,
    );
    expect(
      find.text(IllustratedRoomCatalog.study.paletteSourceNote),
      findsOneWidget,
    );
    for (final palette in IllustratedRoomCatalog.study.palettes) {
      expect(find.text(palette.name), findsWidgets);
      expect(find.text(palette.provenance!), findsOneWidget);
    }
  });

  for (final scenario
      in <
        ({
          String name,
          Object? encoderFailure,
          Object? writerFailure,
          String message,
          bool settings,
        })
      >[
        (
          name: 'render',
          encoderFailure: const IllustratedRoomRenderException(),
          writerFailure: null,
          message: 'Could not prepare the room image. Try again.',
          settings: false,
        ),
        (
          name: 'access denied',
          encoderFailure: null,
          writerFailure: const RoomGalleryWriteException(
            RoomGalleryFailure.accessDenied,
          ),
          message: 'Allow photo access in Settings to save this room image.',
          settings: true,
        ),
        (
          name: 'storage full',
          encoderFailure: null,
          writerFailure: const RoomGalleryWriteException(
            RoomGalleryFailure.notEnoughSpace,
          ),
          message: 'Not enough device storage to save the room image.',
          settings: false,
        ),
        (
          name: 'unsupported format',
          encoderFailure: null,
          writerFailure: const RoomGalleryWriteException(
            RoomGalleryFailure.unsupportedFormat,
          ),
          message: 'This room image format could not be saved.',
          settings: false,
        ),
        (
          name: 'unsupported platform',
          encoderFailure: null,
          writerFailure: const RoomGalleryWriteException(
            RoomGalleryFailure.unsupportedPlatform,
          ),
          message: 'Saving to Gallery is not available on this device.',
          settings: false,
        ),
        (
          name: 'unexpected',
          encoderFailure: null,
          writerFailure: StateError('private /Users/example/gallery detail'),
          message: 'Could not save the room image. Try again.',
          settings: false,
        ),
      ]) {
    testWidgets('${scenario.name} export has safe distinct feedback', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        var settingsCalls = 0;
        final encoder = _TestArtworkEncoder(failure: scenario.encoderFailure);
        final writer = _TestGalleryWriter(failure: scenario.writerFailure);
        final harness = await _pumpEditor(
          tester,
          artworkEncoder: encoder,
          galleryWriter: writer,
          gallerySettings: () async {
            settingsCalls++;
            return true;
          },
          disableAnimations: true,
        );
        harness.container
            .read(illustratedRoomProvider.notifier)
            .applyPalette('cool-airy');
        await tester.pumpAndSettle();
        final before = harness.studyDraft;

        await _tapGalleryAndShowFeedback(tester);

        expect(find.text(scenario.message), findsOneWidget);
        expect(find.bySemanticsLabel(scenario.message), findsOneWidget);
        expect(
          find.textContaining(RegExp(r'StateError|/Users/example/')),
          findsNothing,
        );
        expect(harness.studyDraft, same(before));
        expect(
          tester
              .widget<IllustratedRoomColorRail>(
                find.byType(IllustratedRoomColorRail),
              )
              .onSaveToGallery,
          isNotNull,
        );

        if (scenario.settings) {
          expect(find.text('Settings'), findsOneWidget);
          await tester.tap(find.text('Settings'));
          await tester.pump();
          expect(settingsCalls, 1);
        } else {
          expect(find.text('Settings'), findsNothing);
          expect(settingsCalls, 0);
        }
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('failed Gallery export can retry without changing the draft', (
    tester,
  ) async {
    final encoder = _TestArtworkEncoder();
    late _TestGalleryWriter writer;
    writer = _TestGalleryWriter(
      onSave: () async {
        if (writer.calls == 1) {
          throw const RoomGalleryWriteException(RoomGalleryFailure.unexpected);
        }
      },
    );
    final harness = await _pumpEditor(
      tester,
      artworkEncoder: encoder,
      galleryWriter: writer,
      disableAnimations: true,
    );
    harness.container
        .read(illustratedRoomProvider.notifier)
        .applyPalette('warm-natural');
    await tester.pumpAndSettle();
    final before = harness.studyDraft;

    await _tapGalleryAndShowFeedback(tester);
    expect(
      find.text('Could not save the room image. Try again.'),
      findsOneWidget,
    );
    expect(harness.studyDraft, same(before));

    await _tapGalleryAndShowFeedback(tester);
    expect(find.text('Saved to Gallery'), findsOneWidget);
    expect(encoder.calls, 2);
    expect(writer.calls, 2);
    expect(harness.studyDraft, same(before));
  });

  testWidgets('dirty Back can cancel or keep the retained draft', (
    tester,
  ) async {
    final harness = await _pumpEditor(tester);
    harness.container
        .read(illustratedRoomProvider.notifier)
        .applyPalette('soft-botanical');
    await tester.pumpAndSettle();

    await _tapKey(tester, 'room-editor-back');
    expect(find.text('Keep this draft?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(
      harness.container.read(illustratedRoomProvider).activeTemplateId,
      'study',
    );

    await _tapKey(tester, 'room-editor-back');
    await tester.tap(find.widgetWithText(TextButton, 'Keep draft'));
    await tester.pumpAndSettle();
    final session = harness.container.read(illustratedRoomProvider);
    expect(session.activeTemplateId, isNull);
    expect(session.draftFor('study')!.colors, isNotNull);
    expect(session.draftFor('study')!.isDirty, isTrue);
  });

  testWidgets('dirty Back can discard to the baseline before closing', (
    tester,
  ) async {
    final harness = await _pumpEditor(tester);
    harness.container
        .read(illustratedRoomProvider.notifier)
        .applyPalette('warm-natural');
    await tester.pumpAndSettle();

    await _tapKey(tester, 'room-editor-back');
    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();

    final session = harness.container.read(illustratedRoomProvider);
    expect(session.activeTemplateId, isNull);
    expect(
      session.draftFor('study')!.mode,
      IllustratedRoomVisualMode.grayscale,
    );
    expect(session.draftFor('study')!.isDirty, isFalse);
  });

  testWidgets('black and white confirms before clearing dirty colors', (
    tester,
  ) async {
    final harness = await _pumpEditor(tester);
    harness.container
        .read(illustratedRoomProvider.notifier)
        .applyPalette('cool-airy');
    await tester.pumpAndSettle();

    await _ensureColorToolsVisible(tester);
    await _tapKey(tester, 'room-black-white');
    expect(find.text('Return to black & white?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await tester.pumpAndSettle();

    expect(harness.studyDraft.mode, IllustratedRoomVisualMode.grayscale);
  });
}
