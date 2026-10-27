import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_plan_coverage.dart';

void main() {
  group('checkPlanCoverage', () {
    late Directory fixtureRoot;
    late StringBuffer out;
    late StringBuffer err;

    setUp(() async {
      fixtureRoot = await Directory.systemTemp.createTemp(
        'tintatlas-plan-coverage-',
      );
      out = StringBuffer();
      err = StringBuffer();
    });

    tearDown(() => fixtureRoot.delete(recursive: true));

    File fixture(String name, String contents) =>
        File('${fixtureRoot.path}/$name')..writeAsStringSync(contents);

    int run(File spec, List<File> plans, {List<String> allowed = const []}) {
      return checkPlanCoverage(
        [
          spec.path,
          for (final id in allowed) ...['--allow', id],
          ...plans.map((plan) => plan.path),
        ],
        out: out,
        err: err,
      );
    }

    test('counts duplicate requirement references only once', () {
      final spec = fixture('spec.md', '''
# Scope

BASE-01 is introduced here and repeated in the checklist.

- [ ] **BASE-01 Preserve the working tree.**
- [ ] **DATA-01 Create a schema registry.**
''');
      final plan = fixture('plan.md', '''
# Plan

Implement BASE-01, mention BASE-01 again, and cover DATA-01.
''');

      expect(run(spec, [plan]), 0);
      expect(
        out.toString(),
        contains('2 unique requirement IDs; 0 explicitly allowed omissions'),
      );
      expect(err.toString(), isEmpty);
    });

    test('reports a missing launch requirement by ID and exits nonzero', () {
      final spec = fixture('spec.md', '''
- [ ] **BASE-01 Preserve the working tree.**
- [ ] **BASE-02 Establish a truthful baseline.**
''');
      final plan = fixture('plan.md', 'The plan covers BASE-01.');

      expect(run(spec, [plan]), 1);
      expect(err.toString(), contains('Missing Launch requirement IDs'));
      expect(err.toString(), contains('BASE-02'));
      expect(out.toString(), isEmpty);
    });

    test('recognizes all 161 IDs in the approved spec and master plan', () {
      final spec = File(
        'docs/superpowers/specs/'
        '2026-10-27-tintatlas-full-product-design.md',
      );
      final plan = File(
        'docs/superpowers/plans/2026-10-27-tintatlas-master.md',
      );

      expect(run(spec, [plan]), 0);
      expect(
        out.toString(),
        contains('161 unique requirement IDs; 0 explicitly allowed omissions'),
      );
      expect(err.toString(), isEmpty);
    });

    test('allows only explicitly Post-launch or Deferred omissions', () {
      final spec = fixture('spec.md', '''
- [ ] **BASE-01 Preserve the working tree.**
- [ ] **SHELL-06 Replace onboarding.** Explain the deferred Room AI download.
- [ ] **MASK-02 [Conditional v1] Add Smart Remove MVP.**
- [ ] **LEARN-09 [Post-launch] Add advanced tracks.**
- [ ] **COLOR-15 [Deferred] Add freehand brushes.**
''');
      final plan = fixture('plan.md', 'The launch plan covers BASE-01.');

      expect(run(spec, [plan], allowed: ['LEARN-09', 'COLOR-15']), 1);
      expect(err.toString(), contains('MASK-02'));

      out.clear();
      err.clear();
      expect(
        run(spec, [plan], allowed: ['MASK-02', 'LEARN-09', 'COLOR-15']),
        64,
      );
      expect(
        err.toString(),
        contains(
          '--allow may only exempt Post-launch or Deferred requirement IDs',
        ),
      );
      expect(err.toString(), contains('MASK-02 (Conditional v1)'));

      out.clear();
      err.clear();
      expect(run(spec, [plan], allowed: ['BASE-01']), 64);
      expect(err.toString(), contains('BASE-01 (Launch)'));

      out.clear();
      err.clear();
      expect(run(spec, [plan], allowed: ['SHELL-06']), 64);
      expect(err.toString(), contains('SHELL-06 (Launch)'));
    });
  });
}
