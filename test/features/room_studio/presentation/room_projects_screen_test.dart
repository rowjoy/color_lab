import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_lab/data/schema/corrupt_record.dart';
import 'package:color_lab/data/schema/repository_snapshot.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/room_studio/domain/room_project.dart';
import 'package:color_lab/features/room_studio/domain/room_project_repository.dart';
import 'package:color_lab/features/room_studio/presentation/room_projects_screen.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_room_project_repository.dart';
import '../../../support/room_project_fixtures.dart';

void main() {
  testWidgets(
    'an entirely corrupt library never claims there are no projects yet',
    (tester) async {
      await _launch(tester, _ListedRepository([], corrupt: true));
      expect(find.text('No readable room projects'), findsOneWidget);
      expect(find.text('No room projects yet'), findsNothing);
      expect(
        find.textContaining('unreadable files have been kept'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'busy rename disables resubmission and a failed delete retains its project',
    (tester) async {
      final source = roomProjectFixture(revision: 1);
      final repo = _DeleteFailureRepository(source);
      await _launch(tester, repo);
      await _menu(tester, source.projectId, 'room-project-rename');
      final gate = Completer<void>();
      repo.beforeSave = () => gate.future;
      await tester.enterText(
        find.byKey(const ValueKey('room-project-name')),
        'Lounge',
      );
      final confirm = find.byKey(const ValueKey('room-project-rename-confirm'));
      await tester.tap(confirm);
      await tester.pump();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(find.text('Working…'), findsWidgets);
      gate.complete();
      await tester.pumpAndSettle();
      expect((await repo.read(source.projectId))!.snapshot.revision, 2);
      await _menu(tester, source.projectId, 'room-project-delete');
      await tester.tap(
        find.byKey(const ValueKey('room-project-delete-confirm')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be'), findsWidgets);
      expect(
        find.byKey(const ValueKey('room-project-delete-confirm')),
        findsOneWidget,
      );
      expect((await repo.read(source.projectId))!.snapshot.name, 'Lounge');
    },
  );

  testWidgets('long unicode project name duplicates within the name bound', (
    tester,
  ) async {
    final source = roomProjectFixture(
      revision: 1,
      name: List.filled(40, '🏠').join(),
    );
    final repo = InMemoryRoomProjectRepository(initial: [source]);
    await _launch(tester, repo);
    await _menu(tester, source.projectId, 'room-project-duplicate');
    final records = (await repo.listSnapshot()).records;
    final copy = records.singleWhere(
      (item) => item.projectId != source.projectId,
    );
    expect(copy.name, endsWith(' (copy)'));
    expect(copy.name.length, lessThanOrEqualTo(80));
    expect(copy.name.runes, isNot(contains(0xfffd)));
  });

  testWidgets(
    'healthy projects stay visible, sorted by update then stable ID',
    (tester) async {
      final first = roomProjectFixture(
        projectId: 'a',
        name: 'First',
        revision: 1,
      );
      final second = first.copyWith(projectId: 'b', name: 'Second');
      final old = first.copyWith(
        projectId: 'c',
        name: 'Old',
        updatedAt: first.createdAt,
      );
      final repo = _ListedRepository([old, second, first], corrupt: true);
      await _launch(tester, repo);
      final cards = tester.widgetList<RoomProjectCard>(
        find.byType(RoomProjectCard),
      );
      expect(cards.map((card) => card.project.projectId), ['a', 'b', 'c']);
      expect(find.textContaining('could not be read'), findsOneWidget);
      expect(find.text('First'), findsOneWidget);
      expect(find.textContaining('/private'), findsNothing);
    },
  );

  for (final thumbnail in ['real', 'missing', 'corrupt']) {
    testWidgets(
      '$thumbnail thumbnail has honest accessible label with recovery warning',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final project = roomProjectFixture(revision: 1).copyWith(
          thumbnailPng: switch (thumbnail) {
            'missing' => null,
            'corrupt' => Uint8List.fromList([1, 2, 3]),
            _ => roomProjectPng(),
          },
        );
        final repo = _ListedRepository([project], recovered: true);
        await _launch(tester, repo);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Living room'), findsWidgets);
        expect(find.textContaining('Updated'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('Updated')), findsOneWidget);
        expect(
          find.textContaining('Recovered an earlier saved version'),
          findsOneWidget,
        );
        final thumbnailLabel = thumbnail == 'real'
            ? 'Photo preview for Living room'
            : 'Photo preview unavailable for Living room';
        expect(find.bySemanticsLabel(thumbnailLabel), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets('empty, loading and failed library present localized recovery', (
    tester,
  ) async {
    final repo = _ListedRepository([])..gate = Completer<void>();
    await _launch(tester, repo, settle: false);
    expect(find.text('Loading room projects…'), findsOneWidget);
    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('No room projects yet'), findsOneWidget);
    repo.failure = const RoomProjectStorageException();
    await tester.tap(find.byKey(const ValueKey('room-projects-refresh')));
    await tester.pumpAndSettle();
    expect(find.text('Room projects could not be loaded'), findsOneWidget);
    repo.failure = null;
    await tester.tap(find.byKey(const ValueKey('room-projects-retry')));
    await tester.pumpAndSettle();
    expect(find.text('No room projects yet'), findsOneWidget);
  });

  testWidgets(
    'delete explains local assets, cancel does nothing, confirm deletes selected',
    (tester) async {
      final first = roomProjectFixture(revision: 1);
      final second = first.copyWith(projectId: 'other', name: 'Bedroom');
      final repo = InMemoryRoomProjectRepository(initial: [first, second]);
      await _launch(tester, repo);
      await _menu(tester, first.projectId, 'room-project-delete');
      expect(
        find.textContaining('working photo, masks and color variants'),
        findsOneWidget,
      );
      expect(
        find.textContaining('saved or shared outside the app'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('room-project-delete-cancel')),
      );
      await tester.pumpAndSettle();
      expect((await repo.listSnapshot()).records, hasLength(2));
      await _menu(tester, first.projectId, 'room-project-delete');
      await tester.tap(
        find.byKey(const ValueKey('room-project-delete-confirm')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Living room'), findsNothing);
      expect(find.text('Bedroom'), findsOneWidget);
      expect(await repo.read(first.projectId), isNull);
      expect(await repo.read('other'), isNotNull);
    },
  );

  testWidgets(
    'rename dialog blocks empty name and reports conflict without success',
    (tester) async {
      final project = roomProjectFixture(revision: 1);
      final repo = InMemoryRoomProjectRepository(initial: [project]);
      await _launch(tester, repo);
      await _menu(tester, project.projectId, 'room-project-rename');
      await tester.enterText(
        find.byKey(const ValueKey('room-project-name')),
        '   ',
      );
      await tester.tap(
        find.byKey(const ValueKey('room-project-rename-confirm')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('1–80'), findsOneWidget);
      await repo.save(
        project.copyWith(name: 'Other writer'),
        expectedRevision: 1,
      );
      await tester.enterText(
        find.byKey(const ValueKey('room-project-name')),
        'Mine',
      );
      await tester.tap(
        find.byKey(const ValueKey('room-project-rename-confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('changed since this list was loaded'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('room-project-rename-confirm')),
        findsOneWidget,
      );
      expect(
        (await repo.read(project.projectId))!.snapshot.name,
        'Other writer',
      );
    },
  );

  testWidgets(
    'duplicate creates an honest copy name and Compare is unavailable',
    (tester) async {
      final project = roomProjectFixture(revision: 1);
      final repo = InMemoryRoomProjectRepository(initial: [project]);
      await _launch(tester, repo);
      await tester.ensureVisible(
        find.byKey(ValueKey('room-project-menu-${project.projectId}')),
      );
      await tester.tap(
        find.byKey(ValueKey('room-project-menu-${project.projectId}')),
      );
      await tester.pumpAndSettle();
      final compare = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('room-project-compare')),
      );
      expect(compare.onPressed, isNull);
      expect(
        find.textContaining('Comparison is not available yet'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('room-project-duplicate')));
      await tester.pumpAndSettle();
      expect(find.text('Living room (copy)'), findsOneWidget);
      expect((await repo.listSnapshot()).records, hasLength(2));
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(568, 320),
    const Size(840, 800),
    const Size(1200, 800),
  ]) {
    testWidgets(
      'library and card actions reachable at $size with 200 percent text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final project = roomProjectFixture(revision: 1);
        await _launch(
          tester,
          _ListedRepository([project], recovered: true),
          textScale: 2,
        );
        final semantics = tester.ensureSemantics();
        final open = find.byKey(
          ValueKey('room-project-open-${project.projectId}'),
        );
        await tester.ensureVisible(open);
        await tester.pump();
        expect(open.hitTestable(), findsOneWidget);
        expect(find.bySemanticsLabel('Open Living room'), findsOneWidget);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Open Living room'))
              .getSemanticsData()
              .hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        final menu = find.byKey(
          ValueKey('room-project-menu-${project.projectId}'),
        );
        await tester.ensureVisible(menu);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        final rename = find.byKey(const ValueKey('room-project-rename'));
        await tester.ensureVisible(rename);
        await tester.pump();
        expect(rename.hitTestable(), findsOneWidget);
        final delete = find.byKey(const ValueKey('room-project-delete'));
        await tester.ensureVisible(delete);
        await tester.pump();
        expect(delete.hitTestable(), findsOneWidget);
        await tester.tap(delete);
        await tester.pumpAndSettle();
        final confirm = find.byKey(
          const ValueKey('room-project-delete-confirm'),
        );
        await tester.ensureVisible(confirm);
        await tester.pump();
        expect(confirm.hitTestable(), findsOneWidget);
        final cancel = find.byKey(const ValueKey('room-project-delete-cancel'));
        await tester.ensureVisible(cancel);
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}

class _DeleteFailureRepository extends InMemoryRoomProjectRepository {
  _DeleteFailureRepository(RoomProjectSnapshot project)
    : super(initial: [project]);
  @override
  Future<void> delete(String id) async =>
      throw const RoomProjectStorageException();
}

Future<void> _menu(WidgetTester tester, String id, String action) async {
  final menu = find.byKey(ValueKey('room-project-menu-$id'));
  await tester.ensureVisible(menu);
  await tester.tap(menu);
  await tester.pumpAndSettle();
  final item = find.byKey(ValueKey(action));
  await tester.ensureVisible(item);
  await tester.tap(item);
  await tester.pumpAndSettle();
}

Future<void> _launch(
  WidgetTester tester,
  RoomProjectRepository repository, {
  bool settle = true,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roomProjectRepositoryProvider.overrideWith((ref) async => repository),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const RoomProjectsScreen(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

class _ListedRepository extends InMemoryRoomProjectRepository {
  _ListedRepository(
    this.projects, {
    this.corrupt = false,
    this.recovered = false,
  });
  final List<RoomProjectSnapshot> projects;
  final bool corrupt, recovered;
  Object? failure;
  Completer<void>? gate;
  @override
  Future<RepositorySnapshot<RoomProjectSummary>> listSnapshot() async {
    await gate?.future;
    if (failure != null) throw failure!;
    return RepositorySnapshot(
      records: [
        for (final project in projects)
          RoomProjectSummary.fromReadResult(
            RoomProjectReadResult(
              snapshot: project,
              acknowledgedRevision: recovered ? 3 : project.revision,
              warning: recovered
                  ? RoomProjectRecoveryWarning(
                      reason: RoomProjectRecoveryReason.earlierRevision,
                      acknowledgedRevision: 3,
                      recoveredRevision: 1,
                    )
                  : null,
            ),
          ),
      ],
      corruptRecords: [
        if (corrupt)
          const CorruptRecord(
            collectionId: 'room-projects',
            storageKey: 'bad',
            reason: '/private/not-for-ui',
          ),
      ],
    );
  }
}
