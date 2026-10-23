import 'package:color_lab/features/color_test/domain/vision_plate.dart';
import 'package:color_lab/features/color_test/domain/vision_session.dart';
import 'package:flutter_test/flutter_test.dart';

List<VisionPlate> _plates() => [
  for (final number in [0, 2, 3, 4, 5, 8])
    VisionPlate(number: number, seed: number + 20),
];

void main() {
  test('response distinguishes zero, mismatch and explicit Not sure', () {
    final plate = VisionPlate(number: 0, seed: 0);
    expect(VisionResponse(plate: plate, answer: 0).matches, isTrue);
    expect(VisionResponse(plate: plate, answer: null).matches, isFalse);
    expect(VisionResponse(plate: plate, answer: 1).matches, isFalse);
    for (final invalid in [-1, 10]) {
      expect(
        () => VisionResponse(plate: plate, answer: invalid),
        throwsArgumentError,
      );
    }
  });

  test(
    'initial session snapshots exactly six unique IDs from one iteration',
    () {
      final source = _plates();
      final session = VisionSession.initial(_SingleUsePlates(source));
      source.clear();
      expect(session.plates.length, 6);
      expect(session.stage, VisionStage.introduction);
      expect(session.responses, isEmpty);
      expect(session.draft, isNull);
      expect(session.currentIndex, 0);
      expect(session.plateNumber, 1);
      expect(session.currentPlate.id, '0-roseOlive-20');
      expect(session.matchedCount, 0);
      expect(session.notSureCount, 0);
      expect(() => session.plates.clear(), throwsUnsupportedError);
      expect(() => session.responses.clear(), throwsUnsupportedError);
      for (final invalid in [
        <VisionPlate>[],
        _plates().take(5),
        [..._plates(), VisionPlate(number: 1, seed: 1)],
        [..._plates().take(5), _plates().first],
      ]) {
        expect(() => VisionSession.initial(invalid), throwsArgumentError);
      }
      // Repeated digits are allowed when the full plate IDs differ.
      expect(
        VisionSession.initial([
          for (var seed = 0; seed < 6; seed++)
            VisionPlate(number: 2, seed: seed),
        ]).plates.length,
        6,
      );
    },
  );

  test('introduction guards transitions but still rejects invalid digits', () {
    final intro = VisionSession.initial(_plates());
    expect(intro.withDraft(0), same(intro));
    expect(
      intro.respond(plateId: intro.currentPlate.id, answer: 0),
      same(intro),
    );
    expect(() => intro.withDraft(-1), throwsArgumentError);
    expect(
      () => intro.respond(plateId: 'stale', answer: 10),
      throwsArgumentError,
    );
    final active = intro.start();
    expect(active.stage, VisionStage.active);
    expect(active.start(), same(active));
    expect(intro.stage, VisionStage.introduction);
  });

  test(
    'draft zero and clearing stay immutable and do not record responses',
    () {
      final active = VisionSession.initial(_plates()).start();
      final withZero = active.withDraft(0);
      expect(withZero.draft, 0);
      expect(withZero.responses, isEmpty);
      expect(active.draft, isNull);
      expect(withZero.withDraft(null).draft, isNull);
      expect(withZero.draft, 0);
      for (final invalid in [-1, 10]) {
        expect(() => active.withDraft(invalid), throwsArgumentError);
        expect(
          () =>
              active.respond(plateId: active.currentPlate.id, answer: invalid),
          throwsArgumentError,
        );
      }
    },
  );

  test(
    'captured plate ID prevents a duplicate callback from consuming the next draft',
    () {
      final active = VisionSession.initial(_plates()).start().withDraft(0);
      final id = active.currentPlate.id;
      expect(active.respond(plateId: '', answer: 0), same(active));
      final next = active.respond(plateId: id, answer: 0).withDraft(9);
      expect(next.currentIndex, 1);
      expect(next.plateNumber, 2);
      expect(next.currentPlate.number, 2);
      expect(next.responses.single.answer, 0);
      expect(next.responses.single.plate.id, id);
      expect(next.respond(plateId: id, answer: null), same(next));
      expect(next.draft, 9);
      expect(active.responses, isEmpty);
      expect(active.draft, 0);
    },
  );

  test(
    'six response snapshots advance directly to a frozen summary with exact counts',
    () {
      var session = VisionSession.initial(_plates()).start();
      const answers = [0, null, 9, 4, null, 8];
      final first = session;
      for (var index = 0; index < answers.length; index++) {
        final before = session.withDraft(7);
        session = before.respond(
          plateId: before.currentPlate.id,
          answer: answers[index],
        );
        expect(session.responses.length, index + 1);
        expect(session.draft, isNull);
        expect(
          session.stage,
          index == 5 ? VisionStage.complete : VisionStage.active,
        );
        expect(before.responses.length, index);
      }
      expect(session.currentIndex, 5);
      expect(session.plateNumber, 6);
      expect(session.currentPlate.number, 8);
      expect(session.responses.map((response) => response.answer), answers);
      expect(session.matchedCount, 3);
      expect(session.notSureCount, 2);
      expect(session.start(), same(session));
      expect(session.withDraft(0), same(session));
      expect(
        session.respond(plateId: session.currentPlate.id, answer: 8),
        same(session),
      );
      expect(() => session.withDraft(10), throwsArgumentError);
      expect(
        () => session.respond(plateId: session.currentPlate.id, answer: -1),
        throwsArgumentError,
      );
      expect(() => session.responses.clear(), throwsUnsupportedError);
      expect(first.responses, isEmpty);
    },
  );
}

class _SingleUsePlates extends Iterable<VisionPlate> {
  _SingleUsePlates(this.source);
  final List<VisionPlate> source;
  bool _used = false;

  @override
  Iterator<VisionPlate> get iterator {
    if (_used) throw StateError('The source may only be iterated once');
    _used = true;
    return source.iterator;
  }
}
