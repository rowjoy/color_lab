import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/color_test/domain/matching_game.dart';
import 'package:flutter_test/flutter_test.dart';

List<RgbColor> _targets() => [
  RgbColor(255, 0, 0),
  RgbColor(0, 255, 0),
  RgbColor(0, 0, 255),
  RgbColor(0, 0, 0),
  RgbColor(255, 255, 255),
];

void main() {
  group('MatchingAttempt', () {
    test('scores actual display RGB using independent CIE76 fixtures', () {
      final redGreen = MatchingAttempt(
        target: RgbColor(255, 0, 0),
        guess: RgbColor(0, 255, 0),
      );
      expect(redGreen.deltaE, closeTo(170.565242, .000001));
      expect(redGreen.score, 0);
      expect(redGreen.isExact, isFalse);
      final blackWhite = MatchingAttempt(
        target: RgbColor(0, 0, 0),
        guess: RgbColor(255, 255, 255),
      );
      expect(blackWhite.deltaE, closeTo(100, .000001));
      expect(blackWhite.score, 0);
    });

    test(
      'RGB equality alone determines exactness even when score rounds to 100',
      () {
        final exact = MatchingAttempt(
          target: RgbColor(255, 0, 0),
          guess: RgbColor(255, 0, 0),
        );
        expect(exact.deltaE, 0);
        expect(exact.score, 100);
        expect(exact.isExact, isTrue);
        final close = MatchingAttempt(
          target: RgbColor(255, 0, 0),
          guess: RgbColor(254, 0, 0),
        );
        expect(close.deltaE, closeTo(.373043, .00001));
        expect(close.score, 100);
        expect(close.isExact, isFalse);
      },
    );
  });

  group('MatchingGame', () {
    test('starts at independent neutral coordinates without an attempt', () {
      final game = MatchingGame.start(_targets());
      expect(game.phase, MatchingPhase.editing);
      expect(game.roundIndex, 0);
      expect(game.roundNumber, 1);
      expect(game.target.hex, '#FF0000');
      expect((game.hue, game.saturation, game.lightness), (0, 0, .5));
      expect(game.guess.hex, '#808080');
      expect(game.attempts, isEmpty);
      expect(game.currentAttempt, isNull);
      expect(game.totalScore, 0);
      expect(game.averageScore, 0);
    });

    test('requires exactly five distinct target RGB values', () {
      for (final targets in [
        <RgbColor>[],
        _targets().take(4),
        [..._targets(), RgbColor(1, 2, 3)],
        [..._targets().take(4), RgbColor(255, 0, 0)],
      ]) {
        expect(() => MatchingGame.start(targets), throwsArgumentError);
      }
    });

    test(
      'captures a single-use target iterable once in an immutable snapshot',
      () {
        final source = _targets();
        final game = MatchingGame.start(_SingleUseTargets(source));
        source[0] = RgbColor(1, 2, 3);
        source.clear();
        expect(game.target.hex, '#FF0000');
        expect(game.targets.length, 5);
        expect(() => game.targets.clear(), throwsUnsupportedError);
        expect(
          () => game.attempts.add(
            MatchingAttempt(
              target: RgbColor(0, 0, 0),
              guess: RgbColor(0, 0, 0),
            ),
          ),
          throwsUnsupportedError,
        );
      },
    );

    // Catches re-deriving hue/saturation from an achromatic rendered RGB.
    test(
      'retains independent hue and saturation across neutral and endpoints',
      () {
        final initial = MatchingGame.start(_targets());
        var game = initial.setHue(240);
        expect(game.hue, 240);
        expect(game.guess.hex, '#808080');
        game = game.setSaturation(1);
        expect(game.guess.hex, '#0000FF');
        game = game.setSaturation(0).setSaturation(1);
        expect(game.guess.hex, '#0000FF');
        game = game.setLightness(0);
        expect((game.hue, game.saturation), (240, 1));
        expect(game.guess.hex, '#000000');
        game = game.setLightness(.5);
        expect(game.guess.hex, '#0000FF');
        game = game.setLightness(1);
        expect((game.hue, game.saturation), (240, 1));
        expect(game.guess.hex, '#FFFFFF');
        expect(game.setLightness(.5).guess.hex, '#0000FF');
        expect(initial.guess.hex, '#808080');
      },
    );

    test('validates every slider input before phase guards', () {
      final editing = MatchingGame.start(_targets());
      final feedback = editing.submit();
      var complete = editing;
      for (var round = 0; round < 5; round++) {
        complete = complete.submit().advance();
      }
      for (final game in [editing, feedback, complete]) {
        for (final invalid in [
          -1.0,
          double.nan,
          double.infinity,
          double.negativeInfinity,
        ]) {
          expect(() => game.setHue(invalid), throwsArgumentError);
          expect(() => game.setSaturation(invalid), throwsArgumentError);
          expect(() => game.setLightness(invalid), throwsArgumentError);
        }
        expect(() => game.setHue(360), throwsArgumentError);
        expect(() => game.setSaturation(1.01), throwsArgumentError);
        expect(() => game.setLightness(1.01), throwsArgumentError);
      }
      expect(editing.setHue(359.999).hue, 359.999);
    });

    test(
      'submit freezes one actual attempt without advancing or live scoring',
      () {
        final editing = MatchingGame.start(_targets()).setSaturation(1);
        expect(editing.attempts, isEmpty);
        expect(editing.advance(), same(editing));
        final feedback = editing.submit();
        final attempt = feedback.currentAttempt!;
        expect(feedback.phase, MatchingPhase.feedback);
        expect(feedback.roundNumber, 1);
        expect(feedback.attempts.length, 1);
        expect(attempt.target.hex, '#FF0000');
        expect(attempt.guess.hex, '#FF0000');
        expect(attempt.score, 100);
        expect(feedback.submit(), same(feedback));
        expect(feedback.setHue(240), same(feedback));
        expect(feedback.setSaturation(0), same(feedback));
        expect(feedback.setLightness(0), same(feedback));
        expect(feedback.currentAttempt, same(attempt));
        expect(editing.attempts, isEmpty);
        expect(() => feedback.attempts.clear(), throwsUnsupportedError);
      },
    );

    test(
      'plays exactly five rounds with frozen snapshots, totals and final guards',
      () {
        var game = MatchingGame.start(_targets());
        final feedbackSnapshots = <MatchingGame>[];
        // Literal target sequence: exact red, green, blue, then opposite B/W.
        final coordinates = <(double, double, double)>[
          (0, 1, .5),
          (120, 1, .5),
          (240, 1, .5),
          (0, 0, 1),
          (240, 1, 0),
        ];
        for (var round = 0; round < 5; round++) {
          final (hue, saturation, lightness) = coordinates[round];
          game = game
              .setHue(hue)
              .setSaturation(saturation)
              .setLightness(lightness);
          game = game.submit();
          feedbackSnapshots.add(game);
          expect(game.roundIndex, round);
          expect(game.attempts.length, round + 1);
          expect(game.currentAttempt, same(game.attempts.last));
          expect(game.currentAttempt!.score, [100, 100, 100, 0, 0][round]);
          game = game.advance();
          if (round < 4) {
            expect(game.phase, MatchingPhase.editing);
            expect(game.roundNumber, round + 2);
            expect(game.guess.hex, '#808080');
            expect((game.hue, game.saturation, game.lightness), (0, 0, .5));
            expect(game.currentAttempt, isNull);
            expect(game.advance(), same(game));
          }
        }
        expect(game.phase, MatchingPhase.complete);
        expect(game.roundNumber, 5);
        expect(game.attempts.length, 5);
        expect(game.totalScore, 300);
        expect(game.averageScore, 60);
        expect(game.currentAttempt, isNull);
        expect(game.guess.hex, '#000000');
        expect((game.hue, game.saturation, game.lightness), (240, 1, 0));
        expect(game.submit(), same(game));
        expect(game.advance(), same(game));
        expect(game.setHue(120), same(game));
        expect(game.setSaturation(0), same(game));
        expect(game.setLightness(1), same(game));
        expect(feedbackSnapshots.first.attempts.length, 1);
        expect(feedbackSnapshots.first.totalScore, 100);
        expect(feedbackSnapshots[3].averageScore, 75);
        expect(feedbackSnapshots.first.currentAttempt!.guess.hex, '#FF0000');
      },
    );
  });
}

class _SingleUseTargets extends Iterable<RgbColor> {
  _SingleUseTargets(this.values);
  final List<RgbColor> values;
  bool used = false;
  @override
  Iterator<RgbColor> get iterator {
    if (used) throw StateError('Targets were iterated twice');
    used = true;
    return values.iterator;
  }
}
