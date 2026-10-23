import 'dart:math';

import 'vision_plate.dart';

enum VisionStage { introduction, active, complete }

/// A response snapshot, including an explicit nullable Not sure answer.
final class VisionResponse {
  VisionResponse({required this.plate, required this.answer}) {
    _validateDigit(answer);
  }

  final VisionPlate plate;
  final int? answer;

  bool get matches => answer == plate.number;
}

/// An immutable, six-response activity held only for the app session.
final class VisionSession {
  factory VisionSession.initial(Iterable<VisionPlate> plates) {
    final snapshot = List<VisionPlate>.unmodifiable(plates);
    if (snapshot.length != 6 ||
        snapshot.map((plate) => plate.id).toSet().length != 6) {
      throw ArgumentError.value(
        plates,
        'plates',
        'Expected six unique plate IDs',
      );
    }
    return VisionSession._(
      plates: snapshot,
      responses: const [],
      stage: VisionStage.introduction,
      draft: null,
    );
  }

  const VisionSession._({
    required this.plates,
    required this.responses,
    required this.stage,
    required this.draft,
  });

  final List<VisionPlate> plates;
  final List<VisionResponse> responses;
  final VisionStage stage;
  final int? draft;

  int get currentIndex => min(responses.length, 5);
  VisionPlate get currentPlate => plates[currentIndex];
  int get plateNumber => currentIndex + 1;
  int get matchedCount =>
      responses.where((response) => response.matches).length;
  int get notSureCount =>
      responses.where((response) => response.answer == null).length;

  VisionSession start() => stage == VisionStage.introduction
      ? VisionSession._(
          plates: plates,
          responses: responses,
          stage: VisionStage.active,
          draft: draft,
        )
      : this;

  VisionSession withDraft(int? value) {
    _validateDigit(value);
    if (stage != VisionStage.active) return this;
    return VisionSession._(
      plates: plates,
      responses: responses,
      stage: stage,
      draft: value,
    );
  }

  VisionSession respond({required String plateId, required int? answer}) {
    _validateDigit(answer);
    if (stage != VisionStage.active || plateId != currentPlate.id) return this;
    final snapshot = List<VisionResponse>.unmodifiable([
      ...responses,
      VisionResponse(plate: currentPlate, answer: answer),
    ]);
    return VisionSession._(
      plates: plates,
      responses: snapshot,
      stage: snapshot.length == 6 ? VisionStage.complete : VisionStage.active,
      draft: null,
    );
  }
}

void _validateDigit(int? value) {
  if (value != null && (value < 0 || value > 9)) {
    throw ArgumentError.value(
      value,
      'answer',
      'Must be null or a digit in [0, 9]',
    );
  }
}
