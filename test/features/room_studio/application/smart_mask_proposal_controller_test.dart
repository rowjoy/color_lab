import 'dart:async';
import 'dart:typed_data';

import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/application/room_mask_controller.dart';
import 'package:color_lab/features/room_studio/application/room_project_session_controller.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/room_studio/application/smart_mask_proposal_controller.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/mask_intent_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/domain/room_mask_state.dart';
import 'package:color_lab/features/room_studio/domain/smart_mask_proposal.dart';
import 'package:color_lab/features/room_studio/refine/smart_mask_proposal_service.dart';
import 'package:color_lab/features/room_studio/segmentation/room_wall_depth_protection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_acquisition_intent_store.dart';
import '../../../support/in_memory_room_project_repository.dart';
import '../../../support/mask_edit_fixtures.dart';

class FakeProposals implements SmartMaskProposalService {
  final requests = <SmartMaskProposalKey>[];
  Completer<SmartMaskProposal?>? gate;
  SmartMaskProposal? Function(
    SmartMaskProposalKey,
    MaskBitmap,
    MaskIntentBitmap,
  )?
  result;
  @override
  Future<SmartMaskProposal?> propose({
    required SmartMaskProposalKey key,
    required Offset normalizedSeed,
    required PreparedPhoto photo,
    required MaskBitmap aiMasks,
    required MaskBitmap currentMasks,
    required MaskIntentBitmap intent,
    required RoomDepthFrame? depth,
  }) async {
    requests.add(key);
    if (gate != null) return gate!.future;
    if (result != null) return result!(key, currentMasks, intent);
    return proposal(key, currentMasks, intent);
  }
}

SmartMaskProposal proposal(
  SmartMaskProposalKey key,
  MaskBitmap masks,
  MaskIntentBitmap intent,
) {
  final command = historyEdit(1, before: 2, after: 1, afterIntent: 2);
  return SmartMaskProposal(
    key: key,
    command: command,
    previewMasks: command.applyForward(masks: masks, intent: intent).masks,
  );
}

class Harness {
  Harness({this.service}) {
    repository.beforeSave = () async {
      saves++;
    };
    container = ProviderContainer(
      overrides: [
        roomProjectRepositoryProvider.overrideWith((ref) async => repository),
        acquisitionIntentStoreProvider.overrideWith(
          (ref) async => InMemoryAcquisitionIntentStore(),
        ),
        if (service != null)
          smartMaskProposalServiceProvider.overrideWithValue(service!),
      ],
    );
  }
  final FakeProposals? service;
  final repository = InMemoryRoomProjectRepository(
    initial: [
      maskHistoryProjectFixture(),
      maskHistoryProjectFixture().copyWith(
        projectId: 'other-project',
        photoId: 'other-photo',
      ),
    ],
  );
  late final ProviderContainer container;
  int saves = 0;
  RoomMaskController get editor => container.read(roomMaskProvider.notifier);
  SmartMaskProposalController get controller =>
      container.read(smartMaskProposalProvider.notifier);
  SmartMaskProposalKey get key => SmartMaskProposalKey(
    projectId: 'project-1',
    photoId: 'photo-1',
    maskRevision: container.read(roomMaskProvider).draft!.maskRevision,
    layer: RoomLayer.wall,
    action: SmartMaskAction.add,
  );
  Future<void> open() async {
    expect(await editor.openProject('project-1'), isTrue);
  }

  Future<void> close() async {
    await container.read(roomProjectSessionProvider.notifier).closeProject();
    container.dispose();
    await repository.close();
  }

  Future<bool> request([
    SmartMaskProposalKey? value,
    Offset seed = const Offset(.5, .5),
  ]) => controller.requestProposal(key: value ?? key, normalizedSeed: seed);
}

List<SmartMaskProposalKey> mismatches(SmartMaskProposalKey k) => [
  SmartMaskProposalKey(
    projectId: 'other',
    photoId: k.photoId,
    maskRevision: k.maskRevision,
    layer: k.layer,
    action: k.action,
  ),
  SmartMaskProposalKey(
    projectId: k.projectId,
    photoId: 'other',
    maskRevision: k.maskRevision,
    layer: k.layer,
    action: k.action,
  ),
  SmartMaskProposalKey(
    projectId: k.projectId,
    photoId: k.photoId,
    maskRevision: k.maskRevision + 1,
    layer: k.layer,
    action: k.action,
  ),
  SmartMaskProposalKey(
    projectId: k.projectId,
    photoId: k.photoId,
    maskRevision: k.maskRevision,
    layer: RoomLayer.floor,
    action: k.action,
  ),
  for (final action in [SmartMaskAction.remove, SmartMaskAction.cleanup])
    SmartMaskProposalKey(
      projectId: k.projectId,
      photoId: k.photoId,
      maskRevision: k.maskRevision,
      layer: k.layer,
      action: action,
    ),
];

void main() {
  test(
    'disabled request never calls a service or changes durable pixels',
    () async {
      final h = Harness();
      addTearDown(h.close);
      await h.open();
      final before = h.container.read(roomMaskProvider).draft!;
      expect(await h.request(), isFalse);
      expect(h.container.read(smartMaskProposalProvider), isNull);
      expect(h.container.read(roomMaskProvider).draft, same(before));
      expect(h.saves, 0);
    },
  );

  test(
    'nonfinite and out-of-range seeds and stale request keys never reach service',
    () async {
      final fake = FakeProposals();
      final h = Harness(service: fake);
      addTearDown(h.close);
      await h.open();
      for (final seed in [
        const Offset(double.nan, .5),
        const Offset(.5, double.infinity),
        const Offset(-.01, .5),
        const Offset(.5, 1.01),
      ]) {
        expect(await h.request(null, seed), isFalse);
      }
      for (final key in mismatches(h.key).take(4)) {
        expect(await h.request(key), isFalse);
      }
      expect(fake.requests, isEmpty);
      expect(await h.request(null, Offset.zero), isTrue);
      h.controller.cancelProposal();
      expect(await h.request(null, const Offset(1, 1)), isTrue);
      expect(h.saves, 0);
    },
  );

  test(
    'preview and Cancel preserve identical draft masks intent history and saves',
    () async {
      final h = Harness(service: FakeProposals());
      addTearDown(h.close);
      await h.open();
      final before = h.container.read(roomMaskProvider).draft!;
      expect(await h.request(), isTrue);
      expect(h.container.read(smartMaskProposalProvider), isNotNull);
      expect(h.container.read(roomMaskProvider).draft, same(before));
      h.controller.cancelProposal();
      expect(h.container.read(smartMaskProposalProvider), isNull);
      expect(await h.controller.applyProposal(h.key), isFalse);
      expect(h.container.read(roomMaskProvider).draft, same(before));
      expect(h.saves, 0);
    },
  );

  test(
    'Apply checks every full key field then commits one exact undoable command and save',
    () async {
      final h = Harness(service: FakeProposals());
      addTearDown(h.close);
      await h.open();
      final key = h.key;
      final before = h.container.read(roomMaskProvider).draft!;
      expect(await h.request(), isTrue);
      for (final wrong in mismatches(key)) {
        expect(await h.controller.applyProposal(wrong), isFalse);
      }
      expect(h.saves, 0);
      final first = h.controller.applyProposal(key);
      expect(await h.controller.applyProposal(key), isFalse);
      expect(await first, isTrue);
      expect(await h.controller.applyProposal(key), isFalse);
      for (var attempt = 0; attempt < 300; attempt++) {
        if (h.container.read(roomProjectSessionProvider)?.saveStatus ==
            RoomProjectSaveStatus.saved) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(
        h.container.read(roomProjectSessionProvider)?.saveStatus,
        RoomProjectSaveStatus.saved,
      );
      final after = h.container.read(roomMaskProvider).draft!;
      expect(after.masks.labels, [4, 1, 3, 4]);
      expect(after.intent.bytes, [5, 2, 0, 0]);
      expect(
        after.history.undoStack.length,
        before.history.undoStack.length + 1,
      );
      expect(after.history.redoStack, isEmpty);
      expect(after.maskRevision, before.maskRevision + 1);
      expect(h.saves, 1);
      expect(
        await h.editor.undo(
          photoId: key.photoId,
          maskRevision: after.maskRevision,
        ),
        isTrue,
      );
      expect(
        h.container.read(roomMaskProvider).draft!.masks.labels,
        before.masks.labels,
      );
      expect(
        h.container.read(roomMaskProvider).draft!.intent.bytes,
        before.intent.bytes,
      );
    },
  );

  test(
    'only one physical in-flight request even after Cancel; completion cannot resurrect',
    () async {
      final fake = FakeProposals()..gate = Completer();
      final h = Harness(service: fake);
      addTearDown(h.close);
      await h.open();
      final draft = h.container.read(roomMaskProvider).draft!;
      final key = h.key;
      final request = h.request();
      expect(await h.request(), isFalse);
      expect(await h.controller.applyProposal(key), isFalse);
      h.controller.cancelProposal();
      expect(await h.request(), isFalse);
      fake.gate!.complete(proposal(key, draft.masks, draft.intent));
      expect(await request, isFalse);
      expect(h.container.read(smartMaskProposalProvider), isNull);
      expect(h.container.read(roomMaskProvider).draft, same(draft));
      expect(h.saves, 0);
    },
  );

  for (final mutation in [
    'layer-away-back',
    'revision',
    'close-reopen',
    'project-photo-replaced',
  ]) {
    test(
      '$mutation discards both pending completion and visible preview',
      () async {
        for (final pending in [true, false]) {
          final fake = FakeProposals();
          if (pending) fake.gate = Completer();
          final h = Harness(service: fake);
          await h.open();
          try {
            final draft = h.container.read(roomMaskProvider).draft!;
            final key = h.key;
            final request = h.request();
            if (!pending) expect(await request, isTrue);
            switch (mutation) {
              case 'layer-away-back':
                h.editor.setLayer(RoomLayer.floor);
                h.editor.setLayer(RoomLayer.wall);
              case 'revision':
                await h.editor.undo(
                  photoId: key.photoId,
                  maskRevision: key.maskRevision,
                );
              case 'close-reopen':
                await h.editor.closeProject();
                await h.open();
              case 'project-photo-replaced':
                await h.editor.closeProject();
                expect(await h.editor.openProject('other-project'), isTrue);
            }
            if (pending) {
              fake.gate!.complete(proposal(key, draft.masks, draft.intent));
              expect(await request, isFalse);
            }
            expect(h.container.read(smartMaskProposalProvider), isNull);
            expect(await h.controller.applyProposal(key), isFalse);
          } finally {
            await h.close();
          }
        }
      },
    );
  }

  test(
    'new request and manual stroke cannot apply a previous preview',
    () async {
      final fake = FakeProposals();
      final h = Harness(service: fake);
      addTearDown(h.close);
      await h.open();
      final key = h.key;
      final before = h.container.read(roomMaskProvider).draft!;
      expect(await h.request(), isTrue);
      fake.gate = Completer();
      final pending = h.request(
        SmartMaskProposalKey(
          projectId: key.projectId,
          photoId: key.photoId,
          maskRevision: key.maskRevision,
          layer: key.layer,
          action: SmartMaskAction.cleanup,
        ),
      );
      expect(await h.controller.applyProposal(key), isFalse);
      h.controller.cancelProposal();
      fake.gate!.complete(null);
      expect(await pending, isFalse);
      fake.gate = null;
      expect(await h.request(), isTrue);
      h.editor.setTool(RoomMaskTool.add);
      expect(h.editor.beginStroke(const Offset(.5, .5)), isTrue);
      expect(await h.controller.applyProposal(key), isFalse);
      h.editor.cancelStroke();
      expect(await h.controller.applyProposal(key), isFalse);
      expect(h.container.read(roomMaskProvider).draft, same(before));
      expect(h.saves, 0);
    },
  );

  test('late completion after controller disposal is discarded', () async {
    final fake = FakeProposals()..gate = Completer();
    final h = Harness(service: fake);
    await h.open();
    final key = h.key;
    final draft = h.container.read(roomMaskProvider).draft!;
    final pending = h.request();
    await h.close();
    fake.gate!.complete(proposal(key, draft.masks, draft.intent));
    expect(await pending, isFalse);
  });

  test(
    'mismatching response keys, dimensions, before bytes, preview bytes and errors abstain',
    () async {
      for (var mode = 0; mode < 11; mode++) {
        final fake = FakeProposals()
          ..result = (key, masks, intent) {
            if (mode < 6) return proposal(mismatches(key)[mode], masks, intent);
            if (mode == 6) {
              return SmartMaskProposal(
                key: key,
                command: historyEdit(0, width: 1, height: 4),
                previewMasks: MaskBitmap(
                  width: 1,
                  height: 4,
                  labels: Uint8List(4),
                ),
              );
            }
            if (mode == 7) {
              return SmartMaskProposal(
                key: key,
                command: historyEdit(0),
                previewMasks: masks,
              );
            }
            if (mode == 8) {
              return SmartMaskProposal(
                key: key,
                command: proposal(key, masks, intent).command,
                previewMasks: masks,
              );
            }
            if (mode == 10) return null;
            throw StateError('service unavailable');
          };
        final h = Harness(service: fake);
        await h.open();
        try {
          final draft = h.container.read(roomMaskProvider).draft;
          expect(await h.request(), isFalse);
          expect(h.container.read(smartMaskProposalProvider), isNull);
          expect(h.container.read(roomMaskProvider).draft, same(draft));
          expect(h.saves, 0);
        } finally {
          await h.close();
        }
      }
    },
  );
}
