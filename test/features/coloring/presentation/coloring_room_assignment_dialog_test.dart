import 'package:color_lab/l10n/l10n.dart';
import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/coloring/presentation/coloring_room_assignment_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('room handoff requires four explicit surface assignments', (
    tester,
  ) async {
    final colors = [
      RgbColor.fromHex('#112233'),
      RgbColor.fromHex('#445566'),
      RgbColor.fromHex('#778899'),
      RgbColor.fromHex('#AABBCC'),
    ];
    List<RgbColor>? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showColoringRoomAssignmentDialog(
                  context,
                  colors,
                );
              },
              child: const Text('Assign'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('coloring-room-assign-confirm')),
          )
          .onPressed,
      isNull,
    );
    for (var index = 0; index < colors.length; index++) {
      await tester.tap(find.byKey(ValueKey('coloring-room-surface-$index')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(colors[index].hex).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(
      find.byKey(const ValueKey('coloring-room-assign-confirm')),
    );
    await tester.pumpAndSettle();

    expect(result, colors);
  });
}
