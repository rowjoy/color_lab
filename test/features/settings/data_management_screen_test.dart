import 'dart:async';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/data/storage/local_data_manager.dart';
import 'package:color_lab/features/settings/application/local_data_providers.dart';
import 'package:color_lab/features/settings/presentation/data_management_screen.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import '../../support/in_memory_color_history_repository.dart';

class TestManager implements LocalDataManager {
  int records = 3;
  int revisions = 0;
  int deletes = 0;
  int attempts = 0;
  Completer<void>? gate;
  Future<void> Function()? afterDelete;
  bool fail = false;
  @override
  Future<DataDeletionPreview> preview(
    Set<LocalDataCategory> categories,
  ) async => DataDeletionPreview(
    categories: categories,
    recordCount: records,
    estimatedBytes: 123,
    revisionCount: revisions,
  );
  @override
  Future<void> delete(Set<LocalDataCategory> categories) async {
    attempts++;
    await gate?.future;
    if (fail) throw StateError('private/path');
    await afterDelete?.call();
    deletes++;
  }
}

void main() {
  Future<void> launch(WidgetTester tester, TestManager manager) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [localDataManagerProvider.overrideWithValue(manager)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.highContrastDark,
            home: const DataManagementScreen(),
          ),
        ),
      );
  Future<void> frame(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> review(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('category-savedColors')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('preview-data')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('preview-data')));
    await frame(tester);
  }

  testWidgets('Room projects are selectable and revisions appear as detail', (
    tester,
  ) async {
    final manager = TestManager()
      ..records = 1
      ..revisions = 2;
    await launch(tester, manager);
    await tester.tap(find.byKey(const ValueKey('category-roomProjects')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('preview-data')));
    await tester.tap(find.byKey(const ValueKey('preview-data')));
    await frame(tester);
    expect(find.text('1 records · approximately 123 bytes'), findsOneWidget);
    expect(find.text('2 room project revisions'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(manager.attempts, 0);
  });

  testWidgets('cancel each confirmation retains selection and never deletes', (
    tester,
  ) async {
    final manager = TestManager();
    await launch(tester, manager);
    await review(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(manager.attempts, 0);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('category-savedColors')),
          )
          .value,
      true,
    );
    await tester.tap(find.byKey(const ValueKey('preview-data')));
    await frame(tester);
    await tester.tap(find.byKey(const ValueKey('review-data')));
    await frame(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(manager.attempts, 0);
    await tester.ensureVisible(
      find.byKey(const ValueKey('category-savedColors')),
    );
    await tester.tap(find.byKey(const ValueKey('category-savedColors')));
    await tester.pump();
    expect(find.textContaining('123'), findsNothing);
  });

  testWidgets(
    'delete error retains selection and preview without raw exception text',
    (tester) async {
      final manager = TestManager()..fail = true;
      await launch(tester, manager);
      await review(tester);
      await tester.tap(find.byKey(const ValueKey('review-data')));
      await frame(tester);
      await tester.tap(find.byKey(const ValueKey('confirm-data')));
      await tester.pumpAndSettle();
      expect(manager.deletes, 0);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('category-savedColors')),
            )
            .value,
        true,
      );
      expect(find.textContaining('123'), findsOneWidget);
      expect(find.textContaining('private/path'), findsNothing);
      expect(find.textContaining('Unable to complete'), findsOneWidget);
    },
  );

  testWidgets('busy deletion disables repeated commands and category changes', (
    tester,
  ) async {
    final gate = Completer<void>();
    final manager = TestManager()..gate = gate;
    await launch(tester, manager);
    await review(tester);
    await tester.tap(find.byKey(const ValueKey('review-data')));
    await frame(tester);
    await tester.tap(find.byKey(const ValueKey('confirm-data')));
    await frame(tester);
    expect(manager.attempts, 1);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('preview-data')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('category-savedColors')),
          )
          .onChanged,
      isNull,
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(manager.deletes, 1);
  });

  testWidgets(
    'Back waits for deletion and affected provider refresh before leaving',
    (tester) async {
      final gate = Completer<void>();
      final repository = InMemoryColorHistoryRepository();
      final saved = await repository.save(
        color: RgbColor.fromHex('#123456'),
        name: 'Saved',
        source: ColorSource.manual,
      );
      final manager = TestManager()
        ..gate = gate
        ..afterDelete = () => repository.delete(saved.id);
      final container = ProviderContainer(
        overrides: [
          localDataManagerProvider.overrideWithValue(manager),
          colorHistoryRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
        ],
      );
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/settings/data',
            builder: (_, _) => const DataManagementScreen(),
          ),
        ],
      );
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
        router.dispose();
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      expect(await container.read(colorHistoryProvider.future), hasLength(1));
      unawaited(router.push('/settings/data'));
      await tester.pumpAndSettle();
      await review(tester);
      await tester.tap(find.byKey(const ValueKey('review-data')));
      await frame(tester);
      await tester.tap(find.byKey(const ValueKey('confirm-data')));
      await frame(tester);
      expect(manager.attempts, 1);
      await tester.tap(find.byTooltip('Back'));
      await frame(tester);
      expect(
        router.state.uri.path,
        '/settings/data',
        reason: 'App-bar Back must not dispose completion handling.',
      );
      await tester.binding.handlePopRoute();
      await frame(tester);
      expect(
        router.state.uri.path,
        '/settings/data',
        reason: 'System Back must wait for refresh.',
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(await container.read(colorHistoryProvider.future), isEmpty);
      expect(find.text('Selected data deleted.'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/home');
    },
  );

  testWidgets(
    'both confirmations and their content and actions work in short landscape at 200 percent',
    (tester) async {
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final manager = TestManager();
      await launch(tester, manager);
      await tester.ensureVisible(
        find.byKey(const ValueKey('category-savedColors')),
      );
      await review(tester);
      final dialog = find.byType(AlertDialog);
      await tester.ensureVisible(
        find.descendant(of: dialog, matching: find.textContaining('123')),
      );
      await frame(tester);
      expect(
        find
            .descendant(of: dialog, matching: find.textContaining('123'))
            .hitTestable(),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.descendant(of: dialog, matching: find.text('Cancel')),
      );
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Cancel')),
      );
      await tester.pumpAndSettle();
      expect(manager.attempts, 0);
      await tester.ensureVisible(find.byKey(const ValueKey('preview-data')));
      await tester.tap(find.byKey(const ValueKey('preview-data')));
      await frame(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('review-data')));
      await tester.tap(find.byKey(const ValueKey('review-data')));
      await frame(tester);
      final explanation = find.descendant(
        of: dialog,
        matching: find.textContaining('This cannot be undone'),
      );
      await Scrollable.ensureVisible(
        tester.element(explanation),
        alignment: .5,
      );
      await frame(tester);
      expect(explanation.hitTestable(), findsOneWidget);
      await tester.ensureVisible(
        find.descendant(of: dialog, matching: find.text('Cancel')),
      );
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Cancel')),
      );
      await tester.pumpAndSettle();
      expect(manager.attempts, 0);
      await tester.ensureVisible(find.byKey(const ValueKey('preview-data')));
      await tester.tap(find.byKey(const ValueKey('preview-data')));
      await frame(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('review-data')));
      await tester.tap(find.byKey(const ValueKey('review-data')));
      await frame(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('confirm-data')));
      await tester.tap(find.byKey(const ValueKey('confirm-data')));
      await tester.pumpAndSettle();
      expect(manager.deletes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets(
      'data controls fit $size at doubled text in high contrast dark',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await launch(tester, TestManager());
        await tester.ensureVisible(find.byKey(const ValueKey('preview-data')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('category-coloringProjects')),
              )
              .onChanged,
          isNull,
        );
      },
    );
  }
  testWidgets(
    'no initial selection; review and destructive confirmation both required',
    (tester) async {
      final manager = TestManager();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [localDataManagerProvider.overrideWithValue(manager)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DataManagementScreen(),
          ),
        ),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('preview-data')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('category-savedColors')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('preview-data')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('preview-data')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('123'), findsOneWidget);
      expect(manager.deletes, 0);
      await tester.tap(find.byKey(const ValueKey('review-data')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(manager.deletes, 0);
      await tester.tap(find.byKey(const ValueKey('confirm-data')));
      await tester.pumpAndSettle();
      expect(manager.deletes, 1);
    },
  );
}
