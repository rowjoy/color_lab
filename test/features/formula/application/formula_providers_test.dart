import 'dart:async';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/formula/application/color_formula_service.dart';
import 'package:color_lab/features/formula/application/formula_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final red = RgbColor(255, 0, 0);
  final blue = RgbColor(0, 0, 255);
  final selectedResultProvider = Provider.autoDispose<AsyncValue<ColorFormula>>(
    (ref) => ref.watch(formulaResultProvider(ref.watch(formulaTargetProvider))),
  );

  ProviderContainer containerFor(_ControlledService service) {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [colorFormulaServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'target defaults to lavender and retains edits after navigation',
    () async {
      final container = containerFor(_ControlledService());
      final listener = container.listen(formulaTargetProvider, (_, _) {});
      expect(container.read(formulaTargetProvider).hex, '#B2A4D4');

      container.read(formulaTargetProvider.notifier).setColor(blue);
      expect(listener.read(), blue);
      listener.close();
      await container.pump();

      final reopened = container.listen(formulaTargetProvider, (_, _) {});
      addTearDown(reopened.close);
      expect(reopened.read(), blue);
    },
  );

  test('result calls the service with the exact requested target', () async {
    final service = _ControlledService();
    final container = containerFor(service);
    final key = formulaResultProvider(blue);
    final listener = container.listen(key, (_, _) {});
    addTearDown(listener.close);

    expect(listener.read().isLoading, isTrue);
    expect(service.requests.single.target, blue);
    service.requests.single.result.complete(_endpoint(blue, 'blue'));
    expect((await container.read(key.future)).target, blue);
    expect(listener.read().requireValue.result.hex, '#0000FF');
  });

  for (final oldFails in [false, true]) {
    test(
      'newer target remains visible when old request ${oldFails ? 'fails' : 'completes'} later',
      () async {
        final service = _ControlledService();
        final container = containerFor(service);
        container.read(formulaTargetProvider.notifier).setColor(red);
        final observed = <AsyncValue<ColorFormula>>[];
        final listener = container.listen(
          selectedResultProvider,
          (_, next) => observed.add(next),
          fireImmediately: true,
        );
        addTearDown(listener.close);
        final oldRequest = service.requests.single;

        container.read(formulaTargetProvider.notifier).setColor(blue);
        await container.pump();
        expect(service.requests.map((request) => request.target), [red, blue]);
        service.requests.last.result.complete(_endpoint(blue, 'blue'));
        await container.pump();
        expect(listener.read().requireValue.target, blue);
        final newerNotificationCount = observed.length;

        if (oldFails) {
          oldRequest.result.completeError(StateError('old request failed'));
        } else {
          oldRequest.result.complete(_endpoint(red, 'red'));
        }
        await container.pump();

        expect(listener.read().requireValue.target, blue);
        expect(listener.read().hasError, isFalse);
        expect(observed, hasLength(newerNotificationCount));
      },
    );
  }

  test('invalidating a failed target retries the same target', () async {
    final service = _ControlledService();
    final container = containerFor(service);
    final key = formulaResultProvider(red);
    final listener = container.listen(key, (_, _) {});
    addTearDown(listener.close);
    final rejected = expectLater(container.read(key.future), throwsStateError);
    service.requests.single.result.completeError(StateError('worker failed'));
    await rejected;
    expect(listener.read().hasError, isTrue);

    container.invalidate(key);
    await container.pump();
    expect(service.requests.map((request) => request.target), [red, red]);
    expect(listener.read().isLoading, isTrue);
    service.requests.last.result.complete(_endpoint(red, 'red'));

    expect((await container.read(key.future)).result.hex, '#FF0000');
    expect(listener.read().hasError, isFalse);
  });

  test('finished target results are disposed after listeners detach', () async {
    final service = _ControlledService();
    final container = containerFor(service);
    for (final (target, id) in [(red, 'red'), (blue, 'blue')]) {
      final key = formulaResultProvider(target);
      final listener = container.listen(key, (_, _) {});
      service.requests.last.result.complete(_endpoint(target, id));
      await container.read(key.future);
      listener.close();
      await container.pump();
      expect(container.exists(key), isFalse);
    }

    final reopened = container.listen(formulaResultProvider(red), (_, _) {});
    addTearDown(reopened.close);
    expect(reopened.read().isLoading, isTrue);
    expect(service.requests.map((request) => request.target), [red, blue, red]);
    service.requests.last.result.complete(_endpoint(red, 'red'));
    await container.read(formulaResultProvider(red).future);
  });
}

ColorFormula _endpoint(RgbColor target, String id) => ColorFormula(
  target: target,
  parts: [
    FormulaPart(
      base: FormulaBase(id: id, name: id, color: target),
      percent: 100,
    ),
  ],
);

// Only worker completion is controlled; Riverpod and domain results stay real.
class _ControlledService implements ColorFormulaService {
  final requests = <({RgbColor target, Completer<ColorFormula> result})>[];

  @override
  Future<ColorFormula> find(RgbColor target) {
    final result = Completer<ColorFormula>();
    requests.add((target: target, result: result));
    return result.future;
  }
}
