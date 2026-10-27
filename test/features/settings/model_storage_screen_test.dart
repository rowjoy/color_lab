import 'dart:io';
import 'package:color_lab/features/settings/presentation/model_storage_screen.dart';
import 'package:color_lab/features/room_studio/models/room_model_store.dart';
import 'package:color_lab/features/room_studio/application/room_model_download_providers.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/failing_model_removal_io.dart';

void main() {
  Future<void> finishIO(WidgetTester tester) async {
    for (
      var i = 0;
      i < 50 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  }

  testWidgets(
    'partial removal explains risk and preserves last inventory until explicit refresh',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('model-removal-error-'),
      ))!;
      final paths = [
        for (final artifact in roomModelArtifacts)
          '${root.path}/room_models/${artifact.sha256}/${artifact.name}',
      ];
      await tester.runAsync(() async {
        for (final path in paths) {
          final file = File(path);
          await file.parent.create(recursive: true);
          await file.writeAsString('model');
        }
      });
      final store = RoomModelStore(directory: () async => root);
      final failure = FailingModelRemovalIO(
        ownedPaths: paths.toSet(),
        failOn: paths[1],
      );
      addTearDown(() async {
        IOOverrides.global = null;
        await store.close();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [roomModelStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ModelStorageScreen(),
          ),
        ),
      );
      await finishIO(tester);
      expect(find.text('2 model files · 10 bytes'), findsOneWidget);
      IOOverrides.global = failure;
      await tester.tap(find.text('Remove downloaded models'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Remove downloaded models'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await finishIO(tester);
      expect(failure.deletedPaths, [paths[0]]);
      expect(
        find.textContaining(
          'Some downloaded model files may already have been removed',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Refresh storage'), findsWidgets);
      expect(find.textContaining('private'), findsNothing);
      expect(find.textContaining(root.path), findsNothing);
      expect(find.text('2 model files · 10 bytes'), findsOneWidget);
      expect(find.text('Room models removed.'), findsNothing);
      await tester.tap(find.text('Refresh storage'));
      await tester.pump();
      await finishIO(tester);
      expect(find.text('1 model files · 5 bytes'), findsOneWidget);
      failure.enabled = false;
      await tester.tap(find.text('Remove downloaded models'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Remove downloaded models'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await finishIO(tester);
      expect(find.text('No downloaded models.'), findsOneWidget);
      expect(find.text('Room models removed.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'opening model storage inventories without downloading or creating directories',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('model-settings-'),
      ))!;
      var requests = 0;
      final store = RoomModelStore(
        directory: () async => root,
        clientFactory: () {
          requests++;
          throw StateError('network');
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [roomModelStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ModelStorageScreen(),
          ),
        ),
      );
      for (
        var i = 0;
        i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(requests, 0);
      expect(
        await tester.runAsync(
          () => Directory('${root.path}/room_models').exists(),
        ),
        false,
      );
      expect(store.progress.stage, RoomModelDownloadStage.idle);
      await tester.pumpWidget(const SizedBox());
      await store.close();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
}
