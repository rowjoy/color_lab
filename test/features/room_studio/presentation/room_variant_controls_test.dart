import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:color_lab/features/room_studio/application/room_mask_controller.dart';
import 'package:color_lab/features/room_studio/application/room_project_session_controller.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_service.dart';
import 'package:color_lab/features/room_studio/application/room_variant_controller.dart';
import 'package:color_lab/features/room_studio/domain/room_project.dart';
import 'package:color_lab/features/room_studio/presentation/room_variant_controls.dart';
import 'package:color_lab/features/room_studio/recolor/room_photo_recolorer.dart';
import 'package:color_lab/features/room_studio/recolor/room_recolor_frame.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_layer_colors.dart';
import 'package:color_lab/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_room_project_repository.dart';
import '../../../support/controlled_room_recolor_worker.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_provider.dart';
import '../../../support/room_project_fixtures.dart';

class _Renderer {
  Future<RoomRecolorFrame> render({
    required RoomRecolorKey key,
    required PreparedPhoto photo,
    required MaskBitmap masks,
    required RoomLayerColors colors,
  }) async =>
      recolorRoomPhoto(key: key, photo: photo, masks: masks, colors: colors);
}

Future<ProviderContainer> mount(
  WidgetTester tester, {
  Size size = const Size(840, 800),
  double scale = 1,
  bool original = false,
  RoomProjectSnapshot? project,
  double keyboardInset = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var n = 0;
  final repo = InMemoryRoomProjectRepository(
    initial: [project ?? roomProjectFixture(revision: 1)],
  );
  final c = ProviderContainer(
    overrides: [
      roomProjectRepositoryProvider.overrideWith((ref) async => repo),
      roomProjectIdFactoryProvider.overrideWithValue(() => 'new-${n++}'),
      roomRecolorWorkerFactoryProvider.overrideWithValue(
        () => CallbackRecolorWorker(
          (input) => _Renderer().render(
            key: input.key,
            photo: input.photo,
            masks: input.masks,
            colors: input.colors,
          ),
        ),
      ),
    ],
  );
  var opened = false;
  c
      .read(roomMaskProvider.notifier)
      .openProject('project-1')
      .then((value) => opened = value);
  for (var i = 0; i < 100 && !opened; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  expect(opened, isTrue);
  c.read(roomRecolorCoordinatorProvider.notifier).attachOwner();
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const RoomVariantControls(),
                RoomComparisonPreview(showOriginal: original),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

Future<void> tap(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  RoomProjectSnapshot threeVariants() {
    final source = roomProjectFixture(revision: 1);
    return source.copyWith(
      variants: [
        ...source.variants,
        RoomColorVariant(
          id: 'variant-c',
          name: 'Evening',
          colors: const RoomLayerColors(),
        ),
      ],
    );
  }

  testWidgets(
    'delete names target and retained assets; Cancel and confirmation save zero then one',
    (tester) async {
      final source = threeVariants();
      final c = await mount(tester, project: source);
      final before = c.read(roomProjectSessionProvider)!;
      await tap(tester, 'room-variant-delete-variant-c');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete “Evening”?'), findsOneWidget);
      expect(
        find.text(
          'This removes the “Evening” color alternative. The project photo, masks, and other variants remain.',
        ),
        findsOneWidget,
      );
      expect(identical(c.read(roomProjectSessionProvider), before), isTrue);
      await tap(tester, 'room-variant-delete-cancel');
      expect(identical(c.read(roomProjectSessionProvider), before), isTrue);
      await tap(tester, 'room-variant-delete-variant-c');
      await tap(tester, 'room-variant-delete-confirm');
      final after = c.read(roomProjectSessionProvider)!;
      expect(after.durable!.revision, 2);
      expect(after.variants.map((v) => v.id), ['variant-a', 'variant-b']);
      expect(after.activeVariantId, 'variant-a');
      expect(after.comparisonBaselineVariantId, 'variant-b');
      expect(after.durable!.photoPng, source.photoPng);
      expect(after.durable!.maskBytes, source.maskBytes);
      expect(after.durable!.aiMaskBytes, source.aiMaskBytes);
      expect(after.variants.first.colors, source.variants.first.colors);
      expect(after.variants.last.colors, source.variants[1].colors);
    },
  );

  for (final dismissal in ['back', 'outside']) {
    testWidgets('delete $dismissal dismissal is zero mutations', (
      tester,
    ) async {
      final c = await mount(tester);
      final before = c.read(roomProjectSessionProvider)!;
      await tap(tester, 'room-variant-delete-variant-b');
      expect(find.byType(AlertDialog), findsOneWidget);
      if (dismissal == 'back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tapAt(const Offset(2, 2));
      }
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(identical(c.read(roomProjectSessionProvider), before), isTrue);
    });
  }

  for (final target in ['active', 'baseline', 'both']) {
    testWidgets(
      'delete $target discloses and applies exact selection baseline consequences',
      (tester) async {
        final source = roomProjectFixture(revision: 1);
        final project = target == 'both'
            ? source.copyWith(comparisonBaselineVariantId: 'variant-a')
            : source;
        final c = await mount(tester, project: project);
        final id = target == 'baseline' ? 'variant-b' : 'variant-a';
        await tap(tester, 'room-variant-delete-$id');
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text('The selected variant will switch to “B”.'),
          target == 'baseline' ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('This is the pinned baseline. Comparison will be cleared.'),
          target == 'active' ? findsNothing : findsOneWidget,
        );
        await tap(tester, 'room-variant-delete-confirm');
        final after = c.read(roomProjectSessionProvider)!;
        expect(after.durable!.revision, 2);
        expect(
          after.activeVariantId,
          target == 'baseline' ? 'variant-a' : 'variant-b',
        );
        expect(
          after.comparisonBaselineVariantId,
          target == 'active' ? 'variant-b' : null,
        );
        expect(
          tester
              .widget<TextButton>(
                find.byKey(
                  ValueKey('room-variant-delete-${after.activeVariantId}'),
                ),
              )
              .onPressed,
          isNull,
        );
      },
    );
  }

  for (final change in [
    'target rename',
    'target colors',
    'target removal',
    'selection',
    'reopen same project',
    'other project',
  ]) {
    testWidgets('delete revalidates $change and never saves stale confirmation', (
      tester,
    ) async {
      final c = await mount(tester, project: threeVariants());
      await tap(tester, 'room-variant-delete-variant-a');
      expect(find.byType(AlertDialog), findsOneWidget);
      final controller = c.read(roomVariantProvider.notifier);
      if (change == 'target rename') {
        controller.renameVariant('variant-a', 'Changed');
      } else if (change == 'target colors') {
        controller.updateVariantColors(const RoomLayerColors());
      } else if (change == 'target removal') {
        controller.deleteVariant('variant-a');
      } else if (change == 'selection') {
        controller.selectVariant('variant-b');
      } else {
        final repo =
            c.read(roomProjectRepositoryProvider).requireValue
                as InMemoryRoomProjectRepository;
        var opened = false;
        if (change == 'other project') {
          repo
              .save(
                threeVariants().copyWith(projectId: 'other'),
                expectedRevision: 0,
              )
              .then(
                (_) => c.read(roomMaskProvider.notifier).openProject('other'),
              )
              .then((value) => opened = value);
        } else {
          c
              .read(roomMaskProvider.notifier)
              .openProject('project-1')
              .then((value) => opened = value);
        }
        for (var i = 0; i < 100 && !opened; i++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
        }
        expect(opened, isTrue);
        c.read(roomRecolorCoordinatorProvider.notifier).attachOwner();
      }
      await tester.pumpAndSettle();
      final changed = c.read(roomProjectSessionProvider)!;
      await tap(tester, 'room-variant-delete-confirm');
      expect(identical(c.read(roomProjectSessionProvider), changed), isTrue);
      expect(
        find.text(
          'The project or variants changed while this confirmation was open. Review the variant and try again.',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'repeated delete confirmation while save waits captures one intent',
    (tester) async {
      final c = await mount(tester, project: threeVariants());
      final repo =
          c.read(roomProjectRepositoryProvider).requireValue
              as InMemoryRoomProjectRepository;
      final gate = Completer<void>();
      repo.beforeSave = () => gate.future;
      await tap(tester, 'room-variant-delete-variant-c');
      final confirm = find.byKey(const ValueKey('room-variant-delete-confirm'));
      expect(confirm, findsOneWidget);
      await tester.ensureVisible(confirm);
      final confirmAgain = tester.widget<FilledButton>(confirm).onPressed!;
      await tester.tap(confirm);
      // The first activation removes the route from hit testing immediately.
      // Exercise an already-dispatched second activation on the same callback.
      confirmAgain();
      await tester.pump();
      expect(c.read(roomProjectSessionProvider)!.pendingSaveCount, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(c.read(roomProjectSessionProvider)!.durable!.revision, 2);
      expect(c.read(roomProjectSessionProvider)!.variants, hasLength(2));
      expect(find.byType(RoomVariantControls), findsOneWidget);
    },
  );

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets(
      'delete confirmation fits $size at 200 percent text with keyboard inset',
      (tester) async {
        final source = roomProjectFixture(revision: 1);
        final c = await mount(
          tester,
          project: source.copyWith(comparisonBaselineVariantId: 'variant-a'),
          size: size,
          scale: 2,
          keyboardInset: 100,
        );
        await tap(tester, 'room-variant-delete-variant-a');
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tap(tester, 'room-variant-delete-cancel');
        expect(c.read(roomProjectSessionProvider)!.durable!.revision, 1);
        await tap(tester, 'room-variant-delete-variant-a');
        await tap(tester, 'room-variant-delete-confirm');
        expect(c.read(roomProjectSessionProvider)!.durable!.revision, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'repeated rename Apply while save waits creates only one intent',
    (tester) async {
      final c = await mount(tester);
      final repo =
          c.read(roomProjectRepositoryProvider).requireValue
              as InMemoryRoomProjectRepository;
      final gate = Completer<void>();
      repo.beforeSave = () => gate.future;
      await tap(tester, 'room-variant-rename-variant-a');
      await tester.enterText(
        find.byKey(const ValueKey('room-variant-name')),
        'Renamed',
      );
      final apply = find.byKey(const ValueKey('room-variant-submit'));
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.tap(apply);
      await tester.pump();
      expect(c.read(roomProjectSessionProvider)!.pendingSaveCount, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(c.read(roomProjectSessionProvider)!.durable!.revision, 2);
    },
  );
  testWidgets(
    'A/B buttons select colors and create rename delete pin clear persist',
    (tester) async {
      final c = await mount(tester);
      await tap(tester, 'room-variant-select-variant-b');
      expect(c.read(roomProjectSessionProvider)!.activeVariantId, 'variant-b');
      await tap(tester, 'room-variant-create');
      await tester.enterText(
        find.byKey(const ValueKey('room-variant-name')),
        'Evening',
      );
      await tap(tester, 'room-variant-submit');
      expect(c.read(roomProjectSessionProvider)!.variants.last.name, 'Evening');
      await tap(tester, 'room-variant-rename-new-0');
      await tester.enterText(
        find.byKey(const ValueKey('room-variant-name')),
        'Night',
      );
      await tap(tester, 'room-variant-submit');
      await tap(tester, 'room-variant-pin-variant-a');
      expect(
        c.read(roomProjectSessionProvider)!.comparisonBaselineVariantId,
        'variant-a',
      );
      await tap(tester, 'room-comparison-clear');
      expect(
        c.read(roomProjectSessionProvider)!.comparisonBaselineVariantId,
        isNull,
      );
      await tap(tester, 'room-variant-delete-new-0');
      await tap(tester, 'room-variant-delete-confirm');
      expect(c.read(roomProjectSessionProvider)!.activeVariantId, 'variant-a');
      expect(
        c.read(roomProjectSessionProvider)!.durable!.variants,
        hasLength(2),
      );
      expect(c.read(roomProjectSessionProvider)!.durable!.revision, 7);
    },
  );
  testWidgets('name error is safe and keeps dialog editable', (tester) async {
    final c = await mount(tester);
    await tap(tester, 'room-variant-create');
    await tester.enterText(
      find.byKey(const ValueKey('room-variant-name')),
      ' a ',
    );
    await tap(tester, 'room-variant-submit');
    expect(
      find.text('Choose a different name. Each variant needs a unique name.'),
      findsOneWidget,
    );
    expect(c.read(roomProjectSessionProvider)!.durable!.revision, 1);
    await tester.enterText(
      find.byKey(const ValueKey('room-variant-name')),
      'Valid',
    );
    await tap(tester, 'room-variant-submit');
    expect(c.read(roomProjectSessionProvider)!.variants, hasLength(3));
  });
  testWidgets(
    'real split images and drag keyboard semantics never mutate project',
    (tester) async {
      final c = await mount(tester);
      final semantics = tester.ensureSemantics();
      final before = c.read(roomProjectSessionProvider)!;
      expect(
        find.byKey(const ValueKey('room-comparison-active-image')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('room-comparison-baseline-image')),
        findsOneWidget,
      );
      final slider = find.byKey(const ValueKey('room-comparison-divider'));
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      await tester.drag(slider, const Offset(100, 0));
      await tester.pump();
      final value = tester.widget<Slider>(slider).value;
      expect(value, isNot(.5));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(tester.widget<Slider>(slider).value, lessThan(value));
      final node = tester.getSemantics(slider);
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.increase),
        isTrue,
      );
      node.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pump();
      expect(identical(c.read(roomProjectSessionProvider), before), isTrue);
      semantics.dispose();
    },
  );
  testWidgets(
    'temporary original comparison renders source without metadata changes',
    (tester) async {
      final c = await mount(tester, original: true);
      expect(
        find.byKey(const ValueKey('room-comparison-original-image')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('room-comparison-active-image')),
        findsNothing,
      );
      expect(c.read(roomProjectSessionProvider)!.durable!.revision, 1);
      expect(c.read(roomProjectSessionProvider)!.activeVariantId, 'variant-a');
      expect(
        c.read(roomProjectSessionProvider)!.comparisonBaselineVariantId,
        'variant-b',
      );
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(568, 320),
    const Size(840, 800),
    const Size(1200, 800),
  ]) {
    testWidgets('comparison actions reachable at $size and 200 percent text', (
      tester,
    ) async {
      final c = await mount(tester, size: size, scale: 2);
      expect(tester.takeException(), isNull);
      await tap(tester, 'room-variant-select-variant-b');
      await tap(tester, 'room-variant-pin-variant-a');
      await tester.ensureVisible(
        find.byKey(const ValueKey('room-comparison-divider')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tap(tester, 'room-comparison-clear');
      expect(
        c.read(roomProjectSessionProvider)!.comparisonBaselineVariantId,
        isNull,
      );
      await tap(tester, 'room-variant-create');
      await tester.enterText(
        find.byKey(const ValueKey('room-variant-name')),
        'Evening',
      );
      await tap(tester, 'room-variant-submit');
      await tap(tester, 'room-variant-rename-new-0');
      await tester.enterText(
        find.byKey(const ValueKey('room-variant-name')),
        'Night',
      );
      await tap(tester, 'room-variant-submit');
      await tap(tester, 'room-variant-delete-new-0');
      await tap(tester, 'room-variant-delete-confirm');
      expect(c.read(roomProjectSessionProvider)!.variants, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  }
}
