import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/color_test/application/matching_game_controller.dart';
import 'package:color_lab/features/color_test/application/vision_controller.dart';
import 'package:color_lab/features/color_test/domain/vision_plate.dart';
import 'package:color_lab/features/color_test/domain/vision_session.dart';
import 'package:color_lab/features/formula/application/formula_providers.dart';
import 'package:color_lab/features/harmonies/application/harmony_controller.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/mixer/application/mixer_controller.dart';
import 'package:color_lab/features/room_studio/application/room_color_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

List<VisionPlate> _plates([int offset = 0]) => [
  for (final number in [2, 3, 4, 5, 6, 8])
    VisionPlate(number: number, seed: number + offset),
];

void main() {
  ProviderContainer containerFor(VisionPlateGenerator generator) {
    final container = ProviderContainer(
      overrides: [visionPlateGeneratorProvider.overrideWithValue(generator)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('default generator starts six unique plates at introduction', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = container.read(visionSessionProvider);
    expect(session.stage, VisionStage.introduction);
    expect(session.plates.map((plate) => plate.number).toSet(), {
      2,
      3,
      4,
      5,
      6,
      8,
    });
  });

  test(
    'records six responses, rejects duplicate callbacks and restarts active',
    () {
      var calls = 0;
      final firstSource = _plates();
      final container = containerFor(
        () => ++calls == 1 ? firstSource : _plates(100),
      );
      final controller = container.read(visionSessionProvider.notifier);
      final intro = container.read(visionSessionProvider);
      expect(
        controller.respond(plateId: intro.currentPlate.id, answer: 2),
        isFalse,
      );
      controller.start();
      final firstId = container.read(visionSessionProvider).currentPlate.id;
      controller.setDraft(0);
      expect(controller.respond(plateId: firstId, answer: 0), isTrue);
      controller.setDraft(9);
      expect(controller.respond(plateId: firstId, answer: null), isFalse);
      expect(container.read(visionSessionProvider).draft, 9);
      for (var i = 1; i < 6; i++) {
        final before = container.read(visionSessionProvider);
        expect(
          controller.respond(
            plateId: before.currentPlate.id,
            answer: i == 1 ? null : before.currentPlate.number,
          ),
          isTrue,
        );
      }
      final complete = container.read(visionSessionProvider);
      expect(complete.stage, VisionStage.complete);
      expect(complete.matchedCount, 4);
      expect(complete.notSureCount, 1);
      expect(
        controller.respond(plateId: complete.currentPlate.id, answer: 8),
        isFalse,
      );
      controller.restart();
      final replacement = container.read(visionSessionProvider);
      expect(calls, 2);
      expect(replacement.stage, VisionStage.active);
      expect(replacement.currentIndex, 0);
      expect(replacement.currentPlate.id, '2-roseOlive-102');
      expect(replacement.responses, isEmpty);
      expect(replacement.draft, isNull);
      firstSource.clear();
      expect(complete.plates.length, 6);
      expect(complete.responses.length, 6);
      expect(intro.responses, isEmpty);
    },
  );

  test(
    'session and draft survive losing all listeners without regeneration',
    () async {
      var calls = 0;
      final container = containerFor(() {
        calls++;
        return _plates();
      });
      final listener = container.listen(visionSessionProvider, (_, _) {});
      final controller = container.read(visionSessionProvider.notifier);
      controller.start();
      controller.setDraft(0);
      final before = listener.read();
      listener.close();
      await container.pump();
      final reopened = container.listen(visionSessionProvider, (_, _) {});
      addTearDown(reopened.close);
      expect(reopened.read(), same(before));
      expect(reopened.read().draft, 0);
      expect(container.read(visionSessionProvider.notifier), same(controller));
      expect(calls, 1);
    },
  );

  test(
    'changed generator does not erase state and is read on explicit restart',
    () async {
      final container = containerFor(_plates);
      final controller = container.read(visionSessionProvider.notifier);
      controller.start();
      controller.setDraft(0);
      final before = container.read(visionSessionProvider);
      container.updateOverrides([
        visionPlateGeneratorProvider.overrideWithValue(() => _plates(100)),
      ]);
      await container.pump();
      expect(container.read(visionSessionProvider), same(before));
      controller.restart();
      expect(container.read(visionSessionProvider).currentPlate.seed, 102);
    },
  );

  test(
    'invalid replacement and generator failures preserve the complete current snapshot',
    () {
      var mode = 0;
      final container = containerFor(() {
        if (mode == 1) return [];
        if (mode == 2) return List.filled(6, _plates().first);
        if (mode == 3) throw StateError('generation failed');
        return _plates();
      });
      final controller = container.read(visionSessionProvider.notifier);
      controller.start();
      controller.respond(
        plateId: container.read(visionSessionProvider).currentPlate.id,
        answer: 2,
      );
      controller.setDraft(0);
      final before = container.read(visionSessionProvider);
      for (mode = 1; mode <= 3; mode++) {
        expect(
          controller.restart,
          mode == 3 ? throwsStateError : throwsArgumentError,
        );
        expect(container.read(visionSessionProvider), same(before));
      }
      expect(() => controller.setDraft(10), throwsArgumentError);
      expect(
        () => controller.respond(plateId: 'stale', answer: -1),
        throwsArgumentError,
      );
      expect(container.read(visionSessionProvider), same(before));
    },
  );

  test('containers maintain independent drafts and responses', () {
    final first = containerFor(_plates);
    final second = containerFor(() => _plates(100));
    final controller = first.read(visionSessionProvider.notifier);
    final other = second.read(visionSessionProvider.notifier);
    controller.start();
    other.start();
    other.setDraft(0);
    controller.respond(
      plateId: first.read(visionSessionProvider).currentPlate.id,
      answer: 2,
    );
    controller.restart();
    expect(second.read(visionSessionProvider).draft, 0);
    expect(second.read(visionSessionProvider).responses, isEmpty);
    expect(second.read(visionSessionProvider).currentPlate.seed, 102);
  });

  test(
    'vision restart preserves matching, Lab drafts and history selection',
    () {
      final container = containerFor(_plates);
      final blue = RgbColor(0, 0, 255);
      container.read(mixerProvider.notifier).addColor(blue);
      container.read(harmonyDraftProvider.notifier).setBase(blue);
      container.read(formulaTargetProvider.notifier).setColor(blue);
      container.read(historyFilterProvider.notifier).setQuery('blue');
      container.read(matchingGameProvider.notifier).setSaturation(1);
      container.read(matchingGameProvider.notifier).submit();
      final mixer = container.read(mixerProvider);
      final harmony = container.read(harmonyDraftProvider);
      final formula = container.read(formulaTargetProvider);
      final history = container.read(historyFilterProvider);
      container.read(roomColorProvider.notifier).setColor(blue);
      final matching = container.read(matchingGameProvider);
      final controller = container.read(visionSessionProvider.notifier);
      controller.start();
      controller.setDraft(0);
      controller.restart();
      expect(container.read(mixerProvider), same(mixer));
      expect(container.read(harmonyDraftProvider), harmony);
      expect(container.read(formulaTargetProvider), formula);
      expect(container.read(historyFilterProvider), history);
      expect(container.read(roomColorProvider), blue);
      expect(container.read(matchingGameProvider), same(matching));
    },
  );
}
