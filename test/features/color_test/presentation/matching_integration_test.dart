import 'dart:async';

import 'package:color_lab/app.dart';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/widgets/widgets.dart';
import 'package:color_lab/features/color_test/application/matching_game_controller.dart';
import 'package:color_lab/features/color_test/domain/color_match_level_adapter.dart';
import 'package:color_lab/features/color_test/domain/matching_game.dart';
import 'package:color_lab/features/color_test/presentation/matching_screen.dart';
import 'package:color_lab/features/formula/application/formula_providers.dart';
import 'package:color_lab/features/games/application/game_adapter_registry.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_launch.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_level_catalog.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/game_progression_engine.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:color_lab/features/harmonies/application/harmony_controller.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:color_lab/features/mixer/application/mixer_controller.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:color_lab/features/palette/domain/saved_palette.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:color_lab/features/room_studio/application/room_color_provider.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/settings/domain/app_preferences.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_app_preferences_repository.dart';
import '../../../support/in_memory_acquisition_intent_store.dart';
import '../../../support/in_memory_color_history_repository.dart';
import '../../../support/in_memory_game_profiles_repository.dart';
import '../../../support/in_memory_saved_palette_repository.dart';

void main() {
  final targets = [
    RgbColor(255, 0, 0),
    RgbColor(0, 255, 0),
    RgbColor(0, 0, 255),
    RgbColor(0, 255, 255),
    RgbColor(255, 255, 0),
  ];

  Future<ProviderContainer> launch(
    WidgetTester tester, {
    String path = '/matching',
    bool completed = true,
    ThemeMode theme = ThemeMode.light,
    InMemoryColorHistoryRepository? history,
    InMemorySavedPaletteRepository? palettes,
    MatchingTargetGenerator? generator,
  }) async {
    final container = ProviderContainer(
      overrides: [
        acquisitionIntentStoreProvider.overrideWith(
          (ref) async => InMemoryAcquisitionIntentStore(),
        ),
        appPreferencesRepositoryProvider.overrideWith(
          (ref) async => InMemoryAppPreferencesRepository(
            initial: AppPreferences(
              onboardingCompleted: completed,
              themeMode: theme,
            ),
          ),
        ),
        colorHistoryRepositoryProvider.overrideWith(
          (ref) async => history ?? InMemoryColorHistoryRepository(),
        ),
        savedPaletteRepositoryProvider.overrideWith(
          (ref) async => palettes ?? InMemorySavedPaletteRepository(),
        ),
        colorNamerProvider.overrideWith(
          (ref) async => ColorNamer([NamedColor('Red', RgbColor(255, 0, 0))]),
        ),
        matchingTargetGeneratorProvider.overrideWithValue(
          generator ?? () => targets,
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ColorLabApp(),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(container.read(appRouterProvider).push<void>(path));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> press(WidgetTester tester, String key) async {
    final button = find.byKey(ValueKey(key));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  // Exercise the real shared sliders: replacing their callback with a wrong
  // coordinate must change the displayed RGB and the frozen attempt.
  Future<void> slide(WidgetTester tester, String key, double value) async {
    final slider = find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(Slider),
    );
    await tester.ensureVisible(slider);
    tester.widget<Slider>(slider).onChanged!(value);
    await tester.pumpAndSettle();
  }

  Future<void> completePerfectGame(WidgetTester tester) async {
    for (final hue in [0.0, 120.0, 240.0, 180.0, 60.0]) {
      await slide(tester, 'matching-hue', hue);
      await slide(tester, 'matching-saturation', 1);
      await press(tester, 'matching-submit');
      expect(find.text('Exact match!'), findsOneWidget);
      await press(tester, 'matching-next');
    }
  }

  testWidgets('practice is retained and never opens profile persistence', (
    tester,
  ) async {
    final repository = InMemoryGameProfilesRepository(
      initialState: _emptyProfilesState(),
    );
    final container = ProviderContainer(
      overrides: [
        matchingTargetGeneratorProvider.overrideWithValue(() => targets),
        gameProfilesRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    Future<void> pumpPractice() => tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MatchingScreen()),
      ),
    );

    await pumpPractice();
    await tester.pump();
    await completePerfectGame(tester);
    final completedPractice = container.read(matchingGameProvider);

    expect(completedPractice.won, isTrue);
    expect(repository.readCount, 0);
    expect(repository.writeAttempts, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpPractice();
    await tester.pump();
    expect(container.read(matchingGameProvider), same(completedPractice));
    expect(find.text('500 / 500'), findsOneWidget);
    expect(repository.readCount, 0);
  });

  testWidgets(
    'profile win waits for durability, normalizes, and starts persisted next',
    (tester) async {
      final adapter = _ControlledColorAdapter();
      final fixture = _profileFixture(adapter: adapter);
      var mapOpens = 0;
      final harness = await _pumpProfile(
        tester,
        fixture: fixture,
        adapter: adapter,
        onOpenMap: () => mapOpens++,
      );
      addTearDown(harness.dispose);
      final coinsBefore = harness.repository.durableState.activeProfile!.coins;

      expect(find.text('Level 1 · Easy'), findsOneWidget);
      expect(find.text('Round 1 of 3'), findsOneWidget);
      await tapText(tester, 'Map');
      await tester.pump();
      expect(mapOpens, 1);

      final gate = Completer<void>();
      harness.repository.writeGate = gate;
      await _completeProfilePerfect(tester, fixture.launch);
      await _pumpUntil(tester, () => harness.repository.writeAttempts == 1);

      expect(find.text('Next Level'), findsNothing);
      expect(find.textContaining('+10 coins'), findsNothing);
      expect(_profileProgress(harness.repository).currentLevel, 1);
      expect(adapter.lastOutcome?.averageScore, 100);
      expect(adapter.lastNormalizedScore, 73);

      gate.complete();
      harness.repository.writeGate = null;
      await _pumpUntil(
        tester,
        () => find.text('Next Level').evaluate().isNotEmpty,
      );
      expect(_profileProgress(harness.repository).currentLevel, 2);
      expect(_profileProgress(harness.repository).bestScores[1], 73);
      expect(
        harness.repository.durableState.activeProfile!.coins,
        coinsBefore + 10,
      );
      expect(find.textContaining('+10 coins'), findsOneWidget);

      await tapText(tester, 'Next Level');
      await _pumpUntil(
        tester,
        () => find.text('Level 2 · Easy').evaluate().isNotEmpty,
      );
      expect(_profileProgress(harness.repository).activeAttempt?.level, 2);
    },
  );

  testWidgets('profile chrome and results fit 360dp with doubled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final adapter = _ControlledColorAdapter();
    final fixture = _profileFixture(adapter: adapter);
    var mapOpens = 0;
    final harness = await _pumpProfile(
      tester,
      fixture: fixture,
      adapter: adapter,
      onOpenMap: () => mapOpens++,
    );
    addTearDown(harness.dispose);

    expect(find.text('Level 1 · Easy'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tapText(tester, 'Map');
    expect(mapOpens, 1);
    expect(tester.takeException(), isNull);

    await _completeProfilePerfect(tester, fixture.launch);
    await _pumpUntil(
      tester,
      () => find.text('Level complete!').evaluate().isNotEmpty,
    );
    await tester.ensureVisible(find.text('Level complete!'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile Restart durably replaces the current attempt', (
    tester,
  ) async {
    final adapter = _ControlledColorAdapter();
    final fixture = _profileFixture(adapter: adapter);
    final harness = await _pumpProfile(
      tester,
      fixture: fixture,
      adapter: adapter,
    );
    addTearDown(harness.dispose);
    final originalAttempt = fixture.launch.attemptId;

    await press(tester, 'matching-restart');
    await press(tester, 'confirm-matching-restart');
    await _pumpUntil(
      tester,
      () =>
          _profileProgress(harness.repository).activeAttempt?.attemptId !=
          originalAttempt,
    );

    final replacement = _profileProgress(harness.repository).activeAttempt!;
    expect(replacement.level, fixture.launch.descriptor.level);
    expect(replacement.playKind, GamePlayKind.current);
    expect(replacement.attemptId, isNot(originalAttempt));
  });

  testWidgets('profile loss never settles and Try again is a fresh attempt', (
    tester,
  ) async {
    final adapter = _ControlledColorAdapter(winningAverage: 100);
    final fixture = _profileFixture(adapter: adapter);
    final harness = await _pumpProfile(
      tester,
      fixture: fixture,
      adapter: adapter,
    );
    addTearDown(harness.dispose);
    final oldAttempt = fixture.launch.attemptId;

    await _completeProfileWithCurrentGuess(tester, fixture.launch);
    expect(find.text('Keep practicing to win this level.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(harness.repository.writeAttempts, 0);
    expect(_profileProgress(harness.repository).currentLevel, 1);

    await tapText(tester, 'Try again');
    await _pumpUntil(
      tester,
      () =>
          _profileProgress(harness.repository).activeAttempt?.attemptId !=
          oldAttempt,
    );
    expect(_profileProgress(harness.repository).currentLevel, 1);
    expect(_profileProgress(harness.repository).activeAttempt?.level, 1);
  });

  testWidgets('save failure stays retryable and stale attempts do not retry', (
    tester,
  ) async {
    final adapter = _ControlledColorAdapter();
    final fixture = _profileFixture(adapter: adapter);
    final harness = await _pumpProfile(
      tester,
      fixture: fixture,
      adapter: adapter,
    );
    addTearDown(harness.dispose);
    harness.repository.failWrite = true;

    await _completeProfilePerfect(tester, fixture.launch);
    await _pumpUntil(
      tester,
      () => find.text('Retry save').evaluate().isNotEmpty,
    );
    expect(_profileProgress(harness.repository).currentLevel, 1);
    expect(find.textContaining('+10 coins'), findsNothing);

    harness.repository.failWrite = false;
    await tapText(tester, 'Retry save');
    await _pumpUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );
    expect(_profileProgress(harness.repository).currentLevel, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
    harness.dispose();

    final staleAdapter = _ControlledColorAdapter();
    final staleFixture = _profileFixture(adapter: staleAdapter);
    final staleHarness = await _pumpProfile(
      tester,
      fixture: staleFixture,
      adapter: staleAdapter,
    );
    addTearDown(staleHarness.dispose);
    final replacement = await staleHarness.container
        .read(gameProfilesProvider.notifier)
        .beginCurrentAttempt(
          profileId: staleFixture.launch.profileId,
          gameId: GameId.colorMatch,
        );
    await _completeProfilePerfect(tester, staleFixture.launch);
    await _pumpUntil(
      tester,
      () => find.text('Session changed').evaluate().isNotEmpty,
    );
    expect(find.text('Retry save'), findsNothing);
    expect(find.text('Next Level'), findsNothing);
    expect(
      _profileProgress(staleHarness.repository).activeAttempt?.attemptId,
      replacement.attemptId,
    );
  });

  testWidgets('active profile switch rejects an old-profile Restart', (
    tester,
  ) async {
    final adapter = _ControlledColorAdapter();
    final fixture = _profileFixture(adapter: adapter);
    final harness = await _pumpProfile(
      tester,
      fixture: fixture,
      adapter: adapter,
    );
    addTearDown(harness.dispose);

    await harness.container
        .read(gameProfilesProvider.notifier)
        .createProfile(name: 'Other player');
    final writesAfterSwitch = harness.repository.writeAttempts;
    await press(tester, 'matching-restart');
    await press(tester, 'confirm-matching-restart');

    expect(harness.repository.writeAttempts, writesAfterSwitch);
    expect(find.text('Session changed'), findsOneWidget);
    expect(find.text('Retry save'), findsNothing);
    expect(find.text('Next Level'), findsNothing);
    expect(find.byKey(const ValueKey('matching-submit')), findsNothing);
  });

  testWidgets('duplicate and replay wins suppress all first-clear rewards', (
    tester,
  ) async {
    final duplicateAdapter = _ControlledColorAdapter();
    final duplicate = _profileFixture(
      adapter: duplicateAdapter,
      completedLaunch: true,
    );
    final duplicateHarness = await _pumpProfile(
      tester,
      fixture: duplicate,
      adapter: duplicateAdapter,
    );
    addTearDown(duplicateHarness.dispose);
    final coins = duplicateHarness.repository.durableState.activeProfile!.coins;

    await _completeProfilePerfect(tester, duplicate.launch);
    await _pumpUntil(
      tester,
      () => find.text('Level already saved').evaluate().isNotEmpty,
    );
    expect(find.textContaining('coins'), findsNothing);
    expect(find.textContaining('Badge earned'), findsNothing);
    expect(
      duplicateHarness.repository.durableState.activeProfile!.coins,
      coins,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
    duplicateHarness.dispose();

    final replayAdapter = _ControlledColorAdapter();
    final replay = _profileFixture(adapter: replayAdapter, replay: true);
    final replayHarness = await _pumpProfile(
      tester,
      fixture: replay,
      adapter: replayAdapter,
    );
    addTearDown(replayHarness.dispose);
    final profileBeforeReplay =
        replayHarness.repository.durableState.activeProfile!;
    final replayCoins = profileBeforeReplay.coins;
    final badgeIdsBefore = profileBeforeReplay.badgeIds;
    final milestonesBefore = _profileProgress(
      replayHarness.repository,
    ).badgeMilestones;
    final originalReplayAttempt = replay.launch.attemptId;

    await press(tester, 'matching-restart');
    await press(tester, 'confirm-matching-restart');
    final restartedProgress = _profileProgress(replayHarness.repository);
    expect(restartedProgress.activeAttempt?.playKind, GamePlayKind.replay);
    expect(restartedProgress.activeAttempt?.level, 1);
    expect(
      restartedProgress.activeAttempt?.attemptId,
      isNot(originalReplayAttempt),
    );
    final restartedReplay = GameLaunch(
      profileId: replay.launch.profileId,
      gameId: GameId.colorMatch,
      descriptor: restartedProgress.descriptors[1]!,
      attemptId: restartedProgress.activeAttempt!.attemptId,
      playKind: GamePlayKind.replay,
    );
    await _completeProfilePerfect(tester, restartedReplay);
    await _pumpUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );
    expect(_profileProgress(replayHarness.repository).currentLevel, 2);
    expect(find.textContaining('coins'), findsNothing);
    expect(
      replayHarness.repository.durableState.activeProfile!.coins,
      replayCoins,
    );
    expect(
      replayHarness.repository.durableState.activeProfile!.badgeIds,
      badgeIdsBefore,
    );
    expect(
      _profileProgress(replayHarness.repository).badgeMilestones,
      milestonesBefore,
    );

    await tapText(tester, 'Next Level');
    await _pumpUntil(
      tester,
      () => find.text('Level 2 · Easy').evaluate().isNotEmpty,
    );
    expect(
      _profileProgress(replayHarness.repository).activeAttempt?.playKind,
      GamePlayKind.current,
    );
  });

  testWidgets('failed Next Level keeps a Back-protected persistent retry', (
    tester,
  ) async {
    final adapter = _ControlledColorAdapter();
    final fixture = _profileFixture(adapter: adapter);
    final harness = await _pumpProfile(
      tester,
      fixture: fixture,
      adapter: adapter,
    );
    addTearDown(harness.dispose);
    await _completeProfilePerfect(tester, fixture.launch);
    await _pumpUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );

    harness.repository.failWrite = true;
    await tapText(tester, 'Next Level');
    await _pumpUntil(
      tester,
      () => find.text('Retry Next Level').evaluate().isNotEmpty,
    );
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    expect(find.text('Retry Next Level'), findsOneWidget);

    harness.repository.failWrite = false;
    await tapText(tester, 'Retry Next Level');
    await _pumpUntil(
      tester,
      () => find.text('Level 2 · Easy').evaluate().isNotEmpty,
    );
  });

  testWidgets('launch replacement ignores an older pending completion UI', (
    tester,
  ) async {
    final adapter = _ControlledColorAdapter();
    final fixture = _profileFixture(adapter: adapter);
    final harness = await _pumpProfile(
      tester,
      fixture: fixture,
      adapter: adapter,
    );
    addTearDown(harness.dispose);
    final gate = Completer<void>();
    harness.repository.writeGate = gate;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });

    await _completeProfilePerfect(tester, fixture.launch);
    await _pumpUntil(tester, () => harness.repository.writeAttempts == 1);
    final progress = _profileProgress(harness.repository);
    final replacement = GameLaunch(
      profileId: fixture.launch.profileId,
      gameId: GameId.colorMatch,
      descriptor: progress.descriptors[2]!,
      attemptId: 'profile-1:colorMatch:replacement',
      playKind: GamePlayKind.current,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: MaterialApp(home: MatchingScreen(launch: replacement)),
      ),
    );
    await tester.pump();
    expect(find.text('Level 2 · Easy'), findsOneWidget);

    gate.complete();
    harness.repository.writeGate = null;
    await _pumpUntil(
      tester,
      () => _profileProgress(harness.repository).currentLevel == 2,
    );
    await tester.pump();
    expect(find.text('Level 2 · Easy'), findsOneWidget);
    expect(find.text('Next Level'), findsNothing);
    expect(find.textContaining('+10 coins'), findsNothing);
  });

  testWidgets('Lab opens the retained color matching game', (tester) async {
    await launch(tester, path: '/lab');
    final entry = find.byKey(const ValueKey('open-matching'));
    expect(entry, findsOneWidget);
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-Matching')), findsOneWidget);
    expect(find.text('Round 1 of 5'), findsOneWidget);
  });

  testWidgets('direct matching route respects the onboarding guard', (
    tester,
  ) async {
    final container = await launch(tester, completed: false);
    expect(find.byKey(const ValueKey('screen-Matching')), findsNothing);
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/onboarding',
    );
  });

  testWidgets(
    'editing hides both HEX values and their accessible detail actions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final container = await launch(tester);
        for (final key in ['matching-target', 'matching-guess']) {
          final tile = find.byKey(ValueKey(key));
          final swatch = tester.widget<ColorSwatchTile>(tile);
          expect(swatch.hex, 'Hidden until you submit');
          expect(swatch.onTap, isNull);
          expect(tester.getSemantics(tile).label, isNot(contains('#')));
          await tester.ensureVisible(tile);
          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(find.byType(ColorDetails), findsNothing);
        }
        expect(find.text('#FF0000'), findsNothing);
        expect(find.text('#808080'), findsNothing);
        expect(find.textContaining(RegExp(r'^ΔE ')), findsNothing);
        expect(find.text('Red'), findsNothing);
        expect(container.read(matchingGameProvider).attempts, isEmpty);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'grey submission scores actual display RGB and freezes one attempt',
    (tester) async {
      final container = await launch(tester);
      final submit = tester
          .widget<PrimaryButton>(find.byKey(const ValueKey('matching-submit')))
          .onPressed!;
      final staleSlider = tester
          .widget<Slider>(find.byType(Slider).first)
          .onChanged!;
      await press(tester, 'matching-submit');
      final game = container.read(matchingGameProvider);
      expect(game.attempts.single.guess.hex, '#808080');
      expect(game.attempts.single.target.hex, '#FF0000');
      expect(game.attempts.single.deltaE, closeTo(104.5518, .001));
      expect(find.text('ΔE 104.55'), findsOneWidget);
      expect(find.text('0 / 100 points'), findsOneWidget);
      for (final feedback in [
        find.text('ΔE 104.55'),
        find.text('0 / 100 points'),
      ]) {
        expect(
          tester
              .widgetList<Semantics>(
                find.ancestor(of: feedback, matching: find.byType(Semantics)),
              )
              .any((s) => s.properties.liveRegion == true),
          isTrue,
        );
      }
      expect(find.text('#FF0000'), findsOneWidget);
      expect(find.text('#808080'), findsOneWidget);
      expect(find.byKey(const ValueKey('matching-submit')), findsNothing);
      for (final slider in tester.widgetList<Slider>(find.byType(Slider))) {
        expect(slider.onChanged, isNull);
      }
      submit();
      staleSlider(240);
      await tester.pumpAndSettle();
      expect(container.read(matchingGameProvider), same(game));
      final staleNext = tester
          .widget<PrimaryButton>(find.byKey(const ValueKey('matching-next')))
          .onPressed!;
      await press(tester, 'matching-next');
      staleNext();
      await tester.pumpAndSettle();
      expect(find.text('Round 2 of 5'), findsOneWidget);
      expect(container.read(matchingGameProvider).guess.hex, '#808080');
      expect(find.text('#00FF00'), findsNothing);
    },
  );

  testWidgets(
    'sliders retain neutral hue then score green against red with literal error',
    (tester) async {
      final container = await launch(tester);
      await slide(tester, 'matching-hue', 120);
      expect(container.read(matchingGameProvider).guess.hex, '#808080');
      await slide(tester, 'matching-lightness', 0);
      await slide(tester, 'matching-saturation', 1);
      await slide(tester, 'matching-lightness', .5);
      expect(container.read(matchingGameProvider).guess.hex, '#00FF00');
      expect(
        tester
            .widget<ColorSwatchTile>(
              find.byKey(const ValueKey('matching-guess')),
            )
            .color,
        const Color(0xFF00FF00),
      );
      await press(tester, 'matching-submit');
      expect(find.text('ΔE 170.57'), findsOneWidget);
      expect(find.text('0 / 100 points'), findsOneWidget);
      expect(
        container.read(matchingGameProvider).attempts.single.deltaE,
        closeTo(170.565242, .00001),
      );
    },
  );

  testWidgets('a rounded score of100 does not claim an exact RGB match', (
    tester,
  ) async {
    final container = await launch(
      tester,
      generator: () => [RgbColor(254, 0, 0), ...targets.skip(1)],
    );
    await slide(tester, 'matching-saturation', 1);
    await press(tester, 'matching-submit');
    expect(find.text('100 / 100 points'), findsOneWidget);
    expect(find.text('Exact match!'), findsNothing);
    expect(
      container.read(matchingGameProvider).attempts.single.isExact,
      isFalse,
    );
  });

  testWidgets(
    'both comparison colors stay visible while adjusting Lightness on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await launch(tester);
      await slide(tester, 'matching-hue', 240);
      await slide(tester, 'matching-saturation', 1);
      await slide(tester, 'matching-lightness', .5);
      for (final key in [
        'matching-comparison-target',
        'matching-comparison-guess',
      ]) {
        final swatch = find.byKey(ValueKey(key));
        expect(swatch, findsOneWidget);
        final rect = tester.getRect(swatch);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(800));
      }
      expect(
        tester
            .widget<ColoredBox>(
              find.byKey(const ValueKey('matching-comparison-target')),
            )
            .color,
        const Color(0xFFFF0000),
      );
      expect(
        tester
            .widget<ColoredBox>(
              find.byKey(const ValueKey('matching-comparison-guess')),
            )
            .color,
        const Color(0xFF0000FF),
      );
      expect(find.text('#FF0000'), findsNothing);
      expect(find.text('#0000FF'), findsNothing);
    },
  );

  testWidgets(
    'feedback details save the exact Lab target and Room receives the guess',
    (tester) async {
      final history = InMemoryColorHistoryRepository();
      final container = await launch(tester, history: history);
      await press(tester, 'matching-submit');
      final snapshot = container.read(matchingGameProvider);
      await press(tester, 'matching-target');
      expect(
        tester.widget<ColorDetails>(find.byType(ColorDetails)).color.hex,
        '#FF0000',
      );
      expect(
        tester.widget<ColorDetails>(find.byType(ColorDetails)).source,
        ColorSource.lab,
      );
      await tester.ensureVisible(find.text('Save color'));
      await tester.tap(find.text('Save color'));
      await tester.pumpAndSettle();
      final saved = (await history.load()).single;
      expect(saved.hex, '#FF0000');
      expect(saved.source, ColorSource.lab);
      await tester.ensureVisible(find.byTooltip('Close color details'));
      await tester.tap(find.byTooltip('Close color details'));
      await tester.pumpAndSettle();
      await press(tester, 'matching-guess');
      expect(
        tester.widget<ColorDetails>(find.byType(ColorDetails)).color.hex,
        '#808080',
      );
      expect(
        tester.widget<ColorDetails>(find.byType(ColorDetails)).source,
        ColorSource.lab,
      );
      await tester.ensureVisible(find.text('Use in Room'));
      await tester.tap(find.text('Use in Room'));
      await tester.pumpAndSettle();
      expect(container.read(roomColorProvider).hex, '#808080');
      expect(container.read(matchingGameProvider), same(snapshot));
    },
  );

  testWidgets(
    'five frozen pairs finish with total average and explicit replay',
    (tester) async {
      final container = await launch(tester);
      await completePerfectGame(tester);
      expect(
        container.read(matchingGameProvider).phase,
        MatchingPhase.complete,
      );
      expect(find.text('500 / 500'), findsOneWidget);
      expect(find.text('100.00 / 100'), findsOneWidget);
      expect(find.byKey(const ValueKey('matching-next')), findsNothing);
      for (var i = 0; i < 5; i++) {
        expect(
          find.byKey(ValueKey('matching-result-${i + 1}')),
          findsOneWidget,
        );
        final result = find.byKey(ValueKey('matching-result-${i + 1}'));
        expect(
          find.descendant(of: result, matching: find.text(targets[i].hex)),
          findsNWidgets(2),
        );
        expect(
          find.descendant(of: result, matching: find.text('100 / 100 points')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: result, matching: find.text('ΔE 0.00')),
          findsOneWidget,
        );
      }
      final complete = container.read(matchingGameProvider);
      await tester.pump(const Duration(minutes: 2));
      expect(container.read(matchingGameProvider), same(complete));
      await press(tester, 'matching-play-again');
      expect(find.text('Round 1 of 5'), findsOneWidget);
      expect(container.read(matchingGameProvider).attempts, isEmpty);
    },
  );

  testWidgets(
    'restart cancel and system Back retain draft; confirm replaces game',
    (tester) async {
      var generation = 0;
      final container = await launch(
        tester,
        generator: () {
          generation++;
          return generation == 1 ? targets : targets.reversed.toList();
        },
      );
      await slide(tester, 'matching-hue', 240);
      await slide(tester, 'matching-saturation', 1);
      final draft = container.read(matchingGameProvider);
      await press(tester, 'matching-restart');
      expect(find.text('Restart this game?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(matchingGameProvider), same(draft));
      await press(tester, 'matching-restart');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Restart this game?'), findsNothing);
      expect(container.read(matchingGameProvider), same(draft));
      await press(tester, 'matching-submit');
      await press(tester, 'matching-restart');
      await press(tester, 'confirm-matching-restart');
      expect(container.read(matchingGameProvider).target.hex, '#FFFF00');
      expect(container.read(matchingGameProvider).guess.hex, '#808080');
      expect(container.read(matchingGameProvider).attempts, isEmpty);
      expect(generation, 2);
    },
  );

  testWidgets('results and replay open at the top after phone button taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await launch(tester);
    for (var round = 0; round < 5; round++) {
      await press(tester, 'matching-submit');
      await press(tester, 'matching-next');
    }
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('screen-Matching')),
      matching: find.byType(Scrollable),
    );
    final resultOffset = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    final totalRect = tester.getRect(find.text('Total points'));
    final summaryVisible =
        find.text('Total points').hitTestable().evaluate().isNotEmpty &&
        find.text('Average per round').hitTestable().evaluate().isNotEmpty;
    await press(tester, 'matching-play-again');
    final replayOffset = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    final targetRect = tester.getRect(
      find.byKey(const ValueKey('matching-target')),
    );
    final replayVisible = find
        .byKey(const ValueKey('matching-target'))
        .hitTestable()
        .evaluate()
        .isNotEmpty;
    expect(
      [summaryVisible, replayVisible],
      [true, true],
      reason:
          'Results offset $resultOffset, total rect $totalRect; replay offset $replayOffset, target rect $targetRect. No scrolling to either entry was performed.',
    );
  });

  testWidgets(
    'coordinate theme and feedback retain scroll; confirmed new game resets it',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = await launch(tester);
      await slide(tester, 'matching-lightness', .7);
      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('screen-Matching')),
        matching: find.byType(Scrollable),
      );
      final offset = tester.state<ScrollableState>(scrollable).position.pixels;
      expect(offset, greaterThan(0));
      final slider = find.descendant(
        of: find.byKey(const ValueKey('matching-lightness')),
        matching: find.byType(Slider),
      );
      tester.widget<Slider>(slider).onChanged!(.6);
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(scrollable).position.pixels, offset);
      await container
          .read(appPreferencesProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(scrollable).position.pixels, offset);
      await press(tester, 'matching-restart');
      await press(tester, 'confirm-matching-restart');
      expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
      expect(
        find.byKey(const ValueKey('matching-target')).hitTestable(),
        findsOneWidget,
      );
      expect(container.read(matchingGameProvider).lightness, .5);
      final submit = find.byKey(const ValueKey('matching-submit'));
      await tester.ensureVisible(submit);
      final submitOffset = tester
          .state<ScrollableState>(scrollable)
          .position
          .pixels;
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        submitOffset,
        reason: 'Submitting should retain the controls/feedback viewport.',
      );
    },
  );

  testWidgets(
    'Back reentry theme and completion preserve game and independent drafts',
    (tester) async {
      final existingColor = SavedColor(
        id: '#123456',
        hex: '#123456',
        name: 'Existing color',
        isFavorite: true,
        createdAt: DateTime.utc(2026, 10, 20),
        source: ColorSource.manual,
      );
      final existingPalette = SavedPalette(
        name: 'Existing palette',
        base: RgbColor(255, 0, 0),
        mode: HarmonyMode.complementary,
        colors: [RgbColor(255, 0, 0), RgbColor(0, 255, 255)],
        createdAt: DateTime.utc(2026, 10, 20),
      );
      final container = await launch(
        tester,
        path: '/lab',
        history: InMemoryColorHistoryRepository(colors: [existingColor]),
        palettes: InMemorySavedPaletteRepository(palettes: [existingPalette]),
      );
      tester.widgetList<Slider>(find.byType(Slider)).first.onChanged!(120);
      await tester.pumpAndSettle();
      final hsl = tester
          .widget<ColorSwatchTile>(find.byType(ColorSwatchTile))
          .hex;
      container.read(mixerProvider.notifier).setWeight('color-0', 37);
      container
          .read(formulaTargetProvider.notifier)
          .setColor(RgbColor(1, 2, 3));
      container
          .read(harmonyDraftProvider.notifier)
          .setBase(RgbColor(0, 0, 255));
      final mixer = container.read(mixerProvider);
      final harmony = container.read(harmonyDraftProvider);
      await press(tester, 'open-matching');
      await slide(tester, 'matching-hue', 240);
      final draft = container.read(matchingGameProvider);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ColorSwatchTile>(find.byType(ColorSwatchTile)).hex,
        hsl,
      );
      await press(tester, 'open-matching');
      expect(container.read(matchingGameProvider), same(draft));
      await press(tester, 'matching-submit');
      final feedback = container.read(matchingGameProvider);
      await container
          .read(appPreferencesProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(container.read(matchingGameProvider), same(feedback));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await press(tester, 'open-matching');
      expect(container.read(matchingGameProvider), same(feedback));
      for (var i = 0; i < 5; i++) {
        await press(tester, 'matching-next');
        if (i < 4) await press(tester, 'matching-submit');
      }
      final complete = container.read(matchingGameProvider);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await press(tester, 'open-matching');
      expect(container.read(matchingGameProvider), same(complete));
      expect(container.read(mixerProvider), same(mixer));
      expect(container.read(formulaTargetProvider).hex, '#010203');
      expect(container.read(harmonyDraftProvider), same(harmony));
      await press(tester, 'matching-play-again');
      expect(container.read(mixerProvider), same(mixer));
      expect(container.read(harmonyDraftProvider), same(harmony));
      expect(
        await container
            .read(colorHistoryRepositoryProvider.future)
            .then((r) => r.load()),
        [existingColor],
      );
      expect(await container.read(savedPalettesProvider.future), [
        existingPalette,
      ]);
    },
  );

  testWidgets('history load failure does not block play or results', (
    tester,
  ) async {
    final history = InMemoryColorHistoryRepository()..failLoad = true;
    final container = await launch(tester, history: history);
    await tester.runAsync(() async {
      await expectLater(
        container.read(colorHistoryProvider.future),
        throwsStateError,
      );
    });
    expect(container.read(colorHistoryProvider).hasError, isTrue);
    await completePerfectGame(tester);
    expect(container.read(matchingGameProvider).totalScore, 500);
    expect(find.text('500 / 500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('matching states fit360px2x reduced-motion ${theme.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final container = await launch(tester, theme: theme);
      await slide(tester, 'matching-lightness', .5);
      for (final key in [
        'matching-comparison-target',
        'matching-comparison-guess',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(800));
      }
      expect(tester.takeException(), isNull);
      await press(tester, 'matching-restart');
      for (final key in ['confirm-matching-restart']) {
        final button = find.byKey(ValueKey(key));
        await tester.ensureVisible(button);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await completePerfectGame(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('matching-play-again')),
      );
      expect(
        container.read(matchingGameProvider).phase,
        MatchingPhase.complete,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

final class _ProfileFixture {
  const _ProfileFixture({required this.state, required this.launch});

  final GameProfilesState state;
  final GameLaunch launch;
}

final class _ProfileHarness {
  _ProfileHarness({required this.container, required this.repository});

  final ProviderContainer container;
  final InMemoryGameProfilesRepository repository;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    container.dispose();
  }
}

final class _ControlledColorAdapter implements GameLevelAdapter {
  _ControlledColorAdapter({this.winningAverage});

  final int? winningAverage;
  final ColorMatchLevelAdapter _delegate = ColorMatchLevelAdapter();
  ColorMatchOutcome? lastOutcome;
  int? lastNormalizedScore;

  @override
  GameId get gameId => GameId.colorMatch;

  @override
  int get currentGeneratorVersion => 1;

  @override
  bool supportsVersion(int version) => version == 1;

  @override
  ColorMatchLevelLayout build(GameLevelDescriptor descriptor) {
    final layout = _delegate.build(descriptor);
    final threshold = winningAverage;
    if (threshold == null) return layout;
    return ColorMatchLevelLayout(
      level: layout.level,
      rules: MatchingRules(
        roundCount: layout.rules.roundCount,
        winningAverage: threshold,
      ),
      targets: layout.targets,
      minimumSaturation: layout.minimumSaturation,
      requestedMinimumHueSeparation: layout.requestedMinimumHueSeparation,
      minimumHueSeparation: layout.minimumHueSeparation,
    );
  }

  @override
  int normalizeScore(GameLevelOutcome outcome) {
    if (outcome is! ColorMatchOutcome) {
      throw ArgumentError.value(outcome, 'outcome');
    }
    _delegate.normalizeScore(outcome);
    lastOutcome = outcome;
    lastNormalizedScore = 73;
    return 73;
  }
}

final class _ColorRegistry implements GameLevelAdapterRegistry {
  const _ColorRegistry(this.adapter);

  final GameLevelAdapter adapter;

  @override
  GameLevelAdapter adapterFor(GameId gameId) {
    if (gameId != GameId.colorMatch) {
      throw StateError('Unexpected game: $gameId');
    }
    return adapter;
  }
}

GameProfilesState _emptyProfilesState() => GameProfilesState(
  activeProfileId: null,
  profiles: const {},
  legacyMigrationComplete: true,
);

_ProfileFixture _profileFixture({
  required _ControlledColorAdapter adapter,
  bool completedLaunch = false,
  bool replay = false,
}) {
  final engine = GameProgressionEngine(
    catalog: GameLevelCatalog(registry: _ColorRegistry(adapter)),
  );
  var tick = 0;
  DateTime now() =>
      DateTime.utc(2026, 10, 24, 12).add(Duration(seconds: tick++));
  var state = engine
      .createProfile(
        state: _emptyProfilesState(),
        profileId: 'profile-1',
        name: 'Player',
        now: now(),
      )
      .state;
  state = engine
      .prepareGame(
        state: state,
        profileId: 'profile-1',
        gameId: GameId.colorMatch,
      )
      .state;
  final begun = engine.beginCurrentAttempt(
    state: state,
    profileId: 'profile-1',
    gameId: GameId.colorMatch,
    startedAt: now(),
  );
  state = begun.state;
  if (!completedLaunch && !replay) {
    return _ProfileFixture(state: state, launch: begun.value);
  }
  state = engine
      .completeLevel(
        state: state,
        launch: begun.value,
        normalizedScore: 73,
        completedAt: now(),
      )
      .state;
  if (completedLaunch) {
    return _ProfileFixture(state: state, launch: begun.value);
  }
  final replayBegun = engine.beginReplayAttempt(
    state: state,
    profileId: 'profile-1',
    gameId: GameId.colorMatch,
    level: 1,
    startedAt: now(),
  );
  return _ProfileFixture(state: replayBegun.state, launch: replayBegun.value);
}

Future<_ProfileHarness> _pumpProfile(
  WidgetTester tester, {
  required _ProfileFixture fixture,
  required _ControlledColorAdapter adapter,
  VoidCallback? onOpenMap,
}) async {
  final repository = InMemoryGameProfilesRepository(
    initialState: fixture.state,
  );
  var tick = 0;
  final container = ProviderContainer(
    overrides: [
      gameProfilesRepositoryProvider.overrideWith((ref) async => repository),
      gameAdapterRegistryProvider.overrideWithValue(_ColorRegistry(adapter)),
      gameProfilesClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 10, 24, 13).add(Duration(seconds: tick++)),
      ),
    ],
  );
  await container.read(gameProfilesProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MatchingScreen(launch: fixture.launch, onOpenMap: onOpenMap),
      ),
    ),
  );
  await tester.pump();
  return _ProfileHarness(container: container, repository: repository);
}

Future<void> _completeProfilePerfect(
  WidgetTester tester,
  GameLaunch launch,
) async {
  final scope = ProviderScope.containerOf(
    tester.element(find.byType(MatchingScreen)),
  );
  final provider = profileMatchingGameProvider(
    MatchingProfileSessionKey(launch),
  );
  final controller = scope.read(provider.notifier);
  while (scope.read(provider).phase != MatchingPhase.complete) {
    final game = scope.read(provider);
    if (game.phase == MatchingPhase.editing) {
      final target = game.target.toHsl();
      controller
        ..setHue(target.hue)
        ..setSaturation(target.saturation)
        ..setLightness(target.lightness)
        ..submit();
    } else {
      controller.nextRound();
    }
    await tester.pump();
  }
}

Future<void> _completeProfileWithCurrentGuess(
  WidgetTester tester,
  GameLaunch launch,
) async {
  final scope = ProviderScope.containerOf(
    tester.element(find.byType(MatchingScreen)),
  );
  final provider = profileMatchingGameProvider(
    MatchingProfileSessionKey(launch),
  );
  final controller = scope.read(provider.notifier);
  while (scope.read(provider).phase != MatchingPhase.complete) {
    if (scope.read(provider).phase == MatchingPhase.editing) {
      controller.submit();
    } else {
      controller.nextRound();
    }
    await tester.pump();
  }
}

PlayerGameProgress _profileProgress(
  InMemoryGameProfilesRepository repository,
) => repository.durableState.activeProfile!.gameProgress[GameId.colorMatch]!;

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 120 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue);
}
