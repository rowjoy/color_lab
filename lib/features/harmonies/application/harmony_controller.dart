import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_engine.dart';

typedef HarmonyDraft = ({RgbColor base, HarmonyMode mode});

/// Retains the session selection until its application container is disposed.
final harmonyDraftProvider = NotifierProvider<HarmonyController, HarmonyDraft>(
  HarmonyController.new,
);

class HarmonyController extends Notifier<HarmonyDraft> {
  @override
  HarmonyDraft build() =>
      (base: RgbColor.fromHex('#B2A4D4'), mode: HarmonyMode.complementary);

  void setBase(RgbColor base) => state = (base: base, mode: state.mode);

  void setMode(HarmonyMode mode) => state = (base: state.base, mode: mode);

  void setSelection({required RgbColor base, required HarmonyMode mode}) =>
      state = (base: base, mode: mode);
}
