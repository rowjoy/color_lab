import 'dart:async';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/data/storage/local_data_manager.dart';
import 'package:color_lab/features/settings/application/local_data_providers.dart';
import 'package:color_lab/features/settings/presentation/data_management_screen.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class TestManager implements LocalDataManager {
  int deletes = 0;
  int attempts = 0;
  Completer<void>? gate;
  bool fail = false;
  @override
  Future<DataDeletionPreview> preview(
    Set<LocalDataCategory> categories,
  ) async => DataDeletionPreview(
    categories: categories,
    recordCount: 3,
    estimatedBytes: 123,
  );
  @override
  Future<void> delete(Set<LocalDataCategory> categories) async {
    attempts++;
    await gate?.future;
    if (fail) throw StateError('private/path');
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
                find.byKey(const ValueKey('category-roomProjects')),
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
