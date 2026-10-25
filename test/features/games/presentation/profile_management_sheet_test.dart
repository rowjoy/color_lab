import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:color_lab/features/games/presentation/player_profile_dialog.dart';
import 'package:color_lab/features/games/presentation/profile_management_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_game_profiles_repository.dart';

void main() {
  final epoch = DateTime.utc(2026, 10, 24, 8);

  testWidgets('required first-player dialog blocks dismissal until creation', (
    tester,
  ) async {
    final repository = InMemoryGameProfilesRepository(
      initialState: emptyState(),
    );
    await tester.pumpWidget(profileApp(repository, createdAt: epoch));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-required-gate')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create-first-profile')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerProfileDialog), findsOneWidget);
    expect(find.text('Create your player'), findsOneWidget);
    expect(find.byKey(const ValueKey('cancel-player-profile')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(PlayerProfileDialog), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('player-profile-name')),
      'Me',
    );
    await tester.tap(find.byKey(const ValueKey('save-player-profile')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerProfileDialog), findsNothing);
    expect(repository.durableState.activeProfile!.name, 'Me');
    expect(repository.durableState.profiles, hasLength(1));
    expect(
      find.byKey(const ValueKey('manage-player-profiles')),
      findsOneWidget,
    );
  });

  testWidgets('create validates graphemes, controls, and duplicate names', (
    tester,
  ) async {
    final repository = InMemoryGameProfilesRepository(
      initialState: stateOf([
        profile('profile-1', 'Me', epoch),
      ], activeProfileId: 'profile-1'),
    );
    await tester.pumpWidget(profileApp(repository, createdAt: epoch));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('manage-player-profiles')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-player-profile')));
    await tester.pumpAndSettle();

    for (final invalid in ['A', '👩🏽‍🎨', 'Bad\u007fName']) {
      await tester.enterText(
        find.byKey(const ValueKey('player-profile-name')),
        invalid,
      );
      await tester.tap(find.byKey(const ValueKey('save-player-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Use 2–20 visible characters.'), findsOneWidget);
      expect(repository.durableState.profiles, hasLength(1));
    }

    await tester.enterText(
      find.byKey(const ValueKey('player-profile-name')),
      '  me  ',
    );
    await tester.tap(find.byKey(const ValueKey('save-player-profile')));
    await tester.pumpAndSettle();
    expect(find.text('That player name already exists.'), findsOneWidget);
    expect(repository.durableState.profiles, hasLength(1));

    await tester.enterText(
      find.byKey(const ValueKey('player-profile-name')),
      '👩🏽‍🎨' * 3,
    );
    await tester.tap(find.byKey(const ValueKey('save-player-profile')));
    await tester.pumpAndSettle();
    expect(repository.durableState.profiles, hasLength(2));
    expect(repository.durableState.activeProfile!.name, '👩🏽‍🎨' * 3);
  });

  testWidgets(
    'sheet switches, renames, confirms deletion, and returns to gate',
    (tester) async {
      final repository = InMemoryGameProfilesRepository(
        initialState: stateOf([
          profile('profile-1', 'First', epoch),
          profile('profile-2', 'Second', epoch.add(const Duration(minutes: 1))),
        ], activeProfileId: 'profile-2'),
      );
      await tester.pumpWidget(profileApp(repository, createdAt: epoch));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manage-player-profiles')));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileManagementSheet), findsOneWidget);
      expect(
        find.byKey(const ValueKey('active-profile-profile-2')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('select-profile-profile-1')));
      await tester.pumpAndSettle();
      expect(repository.durableState.activeProfileId, 'profile-1');
      expect(
        find.byKey(const ValueKey('active-profile-profile-1')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('rename-profile-profile-1')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('player-profile-name')),
            )
            .controller!
            .text,
        'First',
      );
      await tester.enterText(
        find.byKey(const ValueKey('player-profile-name')),
        'Owner',
      );
      await tester.tap(find.byKey(const ValueKey('save-player-profile')));
      await tester.pumpAndSettle();
      expect(repository.durableState.profiles['profile-1']!.name, 'Owner');

      await tester.tap(find.byKey(const ValueKey('delete-profile-profile-2')));
      await tester.pumpAndSettle();
      expect(find.text('Delete Second?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cancel-delete-profile')));
      await tester.pumpAndSettle();
      expect(repository.durableState.profiles, hasLength(2));

      await tester.tap(find.byKey(const ValueKey('delete-profile-profile-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete-profile')));
      await tester.pumpAndSettle();
      expect(repository.durableState.profiles.keys, ['profile-1']);

      await tester.tap(find.byKey(const ValueKey('delete-profile-profile-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete-profile')));
      await tester.pumpAndSettle();

      expect(repository.durableState.profiles, isEmpty);
      expect(find.byType(ProfileManagementSheet), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-required-gate')),
        findsOneWidget,
      );
    },
  );

  testWidgets('active choice survives a fresh provider container', (
    tester,
  ) async {
    final repository = InMemoryGameProfilesRepository(
      initialState: stateOf([
        profile('profile-1', 'First', epoch),
        profile('profile-2', 'Second', epoch.add(const Duration(minutes: 1))),
      ], activeProfileId: 'profile-2'),
    );
    await tester.pumpWidget(profileApp(repository, createdAt: epoch));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('manage-player-profiles')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-profile-profile-1')));
    await tester.pumpAndSettle();
    expect(repository.durableState.activeProfileId, 'profile-1');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(profileApp(repository, createdAt: epoch));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('manage-player-profiles')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active-profile-profile-1')),
      findsOneWidget,
    );
  });

  for (final dark in [false, true]) {
    testWidgets('sheet fits 360dp at 2x text with semantics, dark=$dark', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();
      final repository = InMemoryGameProfilesRepository(
        initialState: stateOf([
          profile('profile-1', 'First', epoch),
          profile('profile-2', 'Second', epoch.add(const Duration(minutes: 1))),
        ], activeProfileId: 'profile-2'),
      );
      await tester.pumpWidget(
        profileApp(
          repository,
          createdAt: epoch,
          dark: dark,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manage-player-profiles')));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Switch to First'), findsOneWidget);
      expect(find.bySemanticsLabel('Rename First'), findsOneWidget);
      expect(find.bySemanticsLabel('Delete First'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}

Widget profileApp(
  InMemoryGameProfilesRepository repository, {
  required DateTime createdAt,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  var sequence = repository.durableState.profiles.length;
  return ProviderScope(
    overrides: [
      gameProfilesRepositoryProvider.overrideWith((ref) async => repository),
      gameProfileIdFactoryProvider.overrideWithValue(
        () => 'profile-${++sequence}',
      ),
      gameProfilesClockProvider.overrideWithValue(() => createdAt),
    ],
    child: MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 800),
          textScaler: textScaler,
        ),
        child: const _ProfileGateHarness(),
      ),
    ),
  );
}

final class _ProfileGateHarness extends ConsumerWidget {
  const _ProfileGateHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(gameProfilesProvider);
    return Scaffold(
      body: profiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const Text('Profile load failed'),
        data: (state) => Center(
          child: state.profiles.isEmpty
              ? Column(
                  key: const ValueKey('profile-required-gate'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Create a player to start'),
                    FilledButton(
                      key: const ValueKey('create-first-profile'),
                      onPressed: () => showPlayerProfileDialog(
                        context,
                        requiredProfile: true,
                      ),
                      child: const Text('Create player'),
                    ),
                  ],
                )
              : FilledButton(
                  key: const ValueKey('manage-player-profiles'),
                  onPressed: () => showProfileManagementSheet(context),
                  child: Text(state.activeProfile!.name),
                ),
        ),
      ),
    );
  }
}

GameProfilesState emptyState() => GameProfilesState(
  activeProfileId: null,
  profiles: const {},
  legacyMigrationComplete: true,
);

GameProfilesState stateOf(
  List<PlayerProfile> profiles, {
  required String activeProfileId,
}) => GameProfilesState(
  activeProfileId: activeProfileId,
  profiles: {for (final value in profiles) value.id: value},
  legacyMigrationComplete: true,
);

PlayerProfile profile(String id, String name, DateTime createdAt) =>
    PlayerProfile(
      id: id,
      name: name,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
