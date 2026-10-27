import 'dart:io';
import 'package:color_lab/features/settings/presentation/model_storage_screen.dart';
import 'package:color_lab/features/room_studio/models/room_model_store.dart';
import 'package:color_lab/features/room_studio/application/room_model_download_providers.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
