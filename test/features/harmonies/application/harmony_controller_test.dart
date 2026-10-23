import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/harmonies/application/harmony_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late HarmonyController controller;
  final red = RgbColor(255, 0, 0);

  setUp(() {
    container = ProviderContainer();
    controller = container.read(harmonyDraftProvider.notifier);
  });
  tearDown(() => container.dispose());

  test('starts with the lavender complementary selection', () {
    final draft = container.read(harmonyDraftProvider);
    expect(draft.base.hex, '#B2A4D4');
    expect(draft.mode, HarmonyMode.complementary);
    expect(
      generateHarmony(draft.base, mode: draft.mode).first,
      same(draft.base),
    );
  });

  test('base edits preserve the selected mode and snapshot earlier drafts', () {
    controller.setMode(HarmonyMode.triadic);
    final before = container.read(harmonyDraftProvider);
    controller.setBase(red);
    final draft = container.read(harmonyDraftProvider);
    expect(draft.base, same(red));
    expect(draft.mode, HarmonyMode.triadic);
    expect(before.base.hex, '#B2A4D4');
    expect(before.mode, HarmonyMode.triadic);
  });

  test('mode edits preserve the exact selected base', () {
    controller.setBase(red);
    controller.setMode(HarmonyMode.monochromatic);
    final draft = container.read(harmonyDraftProvider);
    expect(draft.base, same(red));
    expect(draft.mode, HarmonyMode.monochromatic);
  });

  test('combined selection publishes the chosen base and mode together', () {
    final observed = <HarmonyDraft>[];
    final subscription = container.listen(
      harmonyDraftProvider,
      (_, next) => observed.add(next),
    );
    addTearDown(subscription.close);

    controller.setSelection(base: red, mode: HarmonyMode.splitComplementary);

    expect(observed, hasLength(1));
    expect(observed.single.base, same(red));
    expect(observed.single.mode, HarmonyMode.splitComplementary);
    expect(container.read(harmonyDraftProvider), observed.single);
  });

  test('retains selection after all listeners leave the draft', () async {
    final initialListener = container.listen(harmonyDraftProvider, (_, _) {});
    controller.setSelection(base: red, mode: HarmonyMode.tetradic);
    initialListener.close();
    await container.pump();

    final reopened = container.listen(harmonyDraftProvider, (_, _) {});
    addTearDown(reopened.close);
    expect(reopened.read().base, same(red));
    expect(reopened.read().mode, HarmonyMode.tetradic);
    expect(container.read(harmonyDraftProvider.notifier), same(controller));
  });

  test('new containers start independently of another retained selection', () {
    controller.setSelection(base: red, mode: HarmonyMode.analogous);
    final fresh = ProviderContainer();
    addTearDown(fresh.dispose);

    expect(fresh.read(harmonyDraftProvider).base.hex, '#B2A4D4');
    expect(fresh.read(harmonyDraftProvider).mode, HarmonyMode.complementary);
    fresh.read(harmonyDraftProvider.notifier).setMode(HarmonyMode.triadic);
    expect(container.read(harmonyDraftProvider).base, same(red));
    expect(container.read(harmonyDraftProvider).mode, HarmonyMode.analogous);
  });
}
