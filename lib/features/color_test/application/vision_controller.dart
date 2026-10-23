import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/vision_plate.dart';
import '../domain/vision_session.dart';

typedef VisionPlateGenerator = List<VisionPlate> Function();

final visionPlateGeneratorProvider = Provider<VisionPlateGenerator>(
  (ref) =>
      () => generateVisionPlates(),
);

/// Retains the activity and pending digit for the container's lifetime.
final visionSessionProvider = NotifierProvider<VisionController, VisionSession>(
  VisionController.new,
);

class VisionController extends Notifier<VisionSession> {
  @override
  VisionSession build() =>
      VisionSession.initial(ref.read(visionPlateGeneratorProvider)());

  void start() => state = state.start();

  void setDraft(int? value) => state = state.withDraft(value);

  bool respond({required String plateId, required int? answer}) {
    final next = state.respond(plateId: plateId, answer: answer);
    if (identical(next, state)) return false;
    state = next;
    return true;
  }

  void restart() {
    final replacement = VisionSession.initial(
      ref.read(visionPlateGeneratorProvider)(),
    ).start();
    state = replacement;
  }
}
