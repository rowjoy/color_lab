import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/lab_draft.dart';

final labProvider = NotifierProvider<LabController, LabDraft>(
  LabController.new,
);

class LabController extends Notifier<LabDraft> {
  @override
  LabDraft build() => LabDraft.initial();

  void setHue(double value) => state = state.copyWith(hue: value);
  void setSaturation(double value) => state = state.copyWith(saturation: value);
  void setLightness(double value) => state = state.copyWith(lightness: value);
  void restore(LabDraft draft) => state = draft;
}
