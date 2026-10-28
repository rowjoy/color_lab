import 'dart:async';
import 'dart:typed_data';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/color_test/application/matching_game_controller.dart';
import 'package:color_lab/features/formula/application/formula_providers.dart';
import 'package:color_lab/features/harmonies/application/harmony_controller.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/mixer/application/mixer_controller.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/picker/application/photo_acquisition_controller.dart';
import 'package:color_lab/features/picker/application/photo_picker_service.dart';
import 'package:color_lab/features/picker/domain/photo_acquisition.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/application/room_color_provider.dart';
import 'package:color_lab/features/room_studio/application/room_mask_controller.dart';
import 'package:color_lab/features/room_studio/application/room_project_session_controller.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/mask_edit_command.dart'
    as exact;
import 'package:color_lab/features/room_studio/domain/mask_edit_history.dart';
import 'package:color_lab/features/room_studio/domain/mask_intent_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/mask_stroke.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/domain/room_layer_colors.dart';
import 'package:color_lab/features/room_studio/domain/room_mask_state.dart';
import 'package:color_lab/features/room_studio/domain/room_project.dart';
import 'package:color_lab/features/room_studio/domain/room_project_repository.dart';
import 'package:color_lab/features/room_studio/refine/mask_refinement.dart';
import 'package:color_lab/features/room_studio/refine/mask_refinement_service.dart';
import 'package:color_lab/features/room_studio/segmentation/room_segmentation_service.dart';
import 'package:color_lab/features/room_studio/segmentation/room_segmentation_worker.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/settings/application/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_acquisition_intent_store.dart';
import '../../../support/in_memory_app_preferences_repository.dart';
import '../../../support/in_memory_color_history_repository.dart';
import '../../../support/in_memory_saved_palette_repository.dart';
import '../../../support/in_memory_room_project_repository.dart';

PreparedPhoto photo([int marker = 1]) => PreparedPhoto(
  width: 10,
  height: 10,
  rgbaBytes: Uint8List(400)..[0] = marker,
  previewBytes: Uint8List(0),
  palette: const [],
);

MaskBitmap masks([int label = 0]) => MaskBitmap(
  width: 10,
  height: 10,
  labels: Uint8List(100)..fillRange(0, 100, label),
);

MaskStroke stroke({RoomLayer layer = RoomLayer.wall, bool erase = false}) =>
    MaskStroke(
      layer: layer,
      mode: erase ? MaskEditMode.erase : MaskEditMode.add,
      segments: [
        [MaskPoint(.55, .55)],
      ],
      diameterFraction: .05,
    );

Future<void> tick() => Future<void>.delayed(Duration.zero);

class Picker implements PhotoPickerService {
  PreparedPhoto? next = photo();
  Completer<void>? pickGate, recoveryGate;
  PhotoPickFailure? failure;
  int picks = 0, recoveries = 0;
  PhotoSource? source;

  @override
  Future<PreparedPhoto?> pick({
    PhotoSource source = PhotoSource.gallery,
  }) async {
    picks++;
    this.source = source;
    final captured = next;
    await pickGate?.future;
    if (failure != null) throw failure!;
    return captured;
  }

  @override
  Future<PreparedPhoto?> recoverLost() async {
    recoveries++;
    await recoveryGate?.future;
    return null;
  }

  @override
  Future<bool> openSettings() async => true;
}

class Store extends InMemoryAcquisitionIntentStore {
  Completer<void>? saveGate, clearGate, loadGate;
  int clears = 0;
  bool failClear = false;

  @override
  Future<AcquisitionIntentRecord> load() async {
    await loadGate?.future;
    return super.load();
  }

  @override
  Future<void> save(AcquisitionIntent intent) async {
    await saveGate?.future;
    await super.save(intent);
  }

  @override
  Future<void> clear({bool discardUntrusted = false}) async {
    clears++;
    await clearGate?.future;
    if (failClear) throw StateError('storage unavailable');
    await super.clear(discardUntrusted: discardUntrusted);
  }
}

class AnalysisRequest {
  AnalysisRequest(this.id, this.photo);
  final String id;
  final PreparedPhoto photo;
  final result = Completer<RoomSegmentationResult>();

  void succeed([MaskBitmap? value]) => result.complete(
    RoomSegmentationResult(photoId: id, masks: value ?? masks()),
  );

  void fail([
    RoomSegmentationFailureKind kind = RoomSegmentationFailureKind.processing,
  ]) => result.completeError(RoomSegmentationException(kind));
}

class Segmenter implements RoomSegmentationService {
  final requests = <AnalysisRequest>[];
  @override
  Future<RoomSegmentationResult> analyze({
    required String photoId,
    required PreparedPhoto photo,
  }) {
    final request = AnalysisRequest(photoId, photo);
    requests.add(request);
    return request.result.future;
  }

  @override
  Future<void> close() async {}
}

class ControlledRefreshWorker implements RoomSegmentationWorker {
  final result = Completer<MaskBitmap>();
  bool closed = false;

  @override
  Future<MaskBitmap> run(PreparedPhoto photo) => result.future;

  @override
  Future<void> close() async => closed = true;
}

class Refiner implements MaskRefinementService {
  Completer<void>? gate;
  bool fail = false;
  int calls = 0;
  @override
  Future<MaskRefinementResult> apply({
    required MaskBitmap current,
    required MaskBitmap ai,
    required MaskIntentBitmap intent,
    required MaskStroke stroke,
  }) async {
    calls++;
    await gate?.future;
    if (fail) throw StateError('worker failed');
    return applyMaskStroke(
      current: current,
      ai: ai,
      intent: intent,
      stroke: stroke,
    );
  }
}

class Harness {
  Harness({RoomSegmentationService Function()? segmentationFactory}) {
    var sequence = 0;
    container = ProviderContainer(
      overrides: [
        roomProjectRepositoryProvider.overrideWith((ref) async => projects),
        acquisitionIntentStoreProvider.overrideWith((ref) async => store),
        photoPickerServiceProvider.overrideWithValue(picker),
        roomSegmentationServiceProvider.overrideWith((ref) {
          final service = segmentationFactory?.call() ?? segmenter;
          ref.onDispose(() => unawaited(service.close()));
          return service;
        }),
        maskRefinementServiceProvider.overrideWithValue(refiner),
        appPreferencesRepositoryProvider.overrideWith(
          (ref) async => InMemoryAppPreferencesRepository(),
        ),
        colorHistoryRepositoryProvider.overrideWith(
          (ref) async => InMemoryColorHistoryRepository(),
        ),
        savedPaletteRepositoryProvider.overrideWith(
          (ref) async => InMemorySavedPaletteRepository(),
        ),
        roomPhotoIdFactoryProvider.overrideWithValue(
          () => 'photo-${sequence++}',
        ),
      ],
    );
    addTearDown(container.dispose);
  }
  final picker = Picker();
  final store = Store();
  final segmenter = Segmenter();
  final refiner = Refiner();
  final projects = ProjectStore();
  late final ProviderContainer container;
  RoomMaskController get controller =>
      container.read(roomMaskProvider.notifier);
  RoomMaskState get state => container.read(roomMaskProvider);
  AcquisitionReceipt? get pending =>
      container.read(photoAcquisitionProvider).pendingReceipt;

  Future<void> import({bool Function()? isActive}) => controller.importPhoto(
    PhotoSource.gallery,
    isActive: isActive ?? () => true,
  );

  Future<RoomMaskDraft> ready([int label = 0]) async {
    final operation = import();
    await tick();
    segmenter.requests.last.succeed(masks(label));
    await operation;
    return state.draft!;
  }

  Future<bool> paint({MaskStroke? value}) {
    final draft = state.draft!;
    return controller.applyStroke(
      photoId: draft.photoId,
      maskRevision: draft.maskRevision,
      stroke: value ?? stroke(),
    );
  }

  Future<void> saved() async {
    for (var i = 0; i < 300; i++) {
      if (container.read(roomProjectSessionProvider)?.saveStatus ==
          RoomProjectSaveStatus.saved) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('Project did not save');
  }
}

class ProjectStore extends InMemoryRoomProjectRepository {
  Completer<void>? readGate;
  Object? readError;
  @override
  Future<RoomProjectReadResult?> read(String projectId) async {
    await readGate?.future;
    if (readError != null) throw readError!;
    return super.read(projectId);
  }
}

void main() {
  test(
    'intent-equal Add commits explicit intent once instead of being a no-op',
    () async {
      final h = Harness();
      await h.ready(1);
      await h.saved();
      h.controller.setTool(RoomMaskTool.add);
      var saves = 0;
      h.projects.beforeSave = () async {
        saves++;
      };
      expect(await h.paint(), isTrue);
      await h.saved();
      expect(h.state.draft!.intent.intentAt(55), 2);
      expect(h.state.draft!.changedFromAiCount, 0);
      expect(h.state.draft!.hasEdits, isTrue);
      expect(saves, 1);
    },
  );

  test(
    'completed lifecycle stroke and direct undo redo each save exactly once',
    () async {
      final h = Harness();
      await h.ready();
      await h.saved();
      var saves = 0;
      h.projects.beforeSave = () async {
        saves++;
      };
      h.controller.setLayer(RoomLayer.floor);
      h.controller.setTool(RoomMaskTool.add);
      final before = h.state.draft!;
      expect(h.controller.beginStroke(const Offset(1.5, 1.5)), isTrue);
      expect(h.controller.extendStroke(const Offset(8.5, 1.5)), isTrue);
      expect(h.state.draft, same(before));
      expect(saves, 0);
      expect(await h.controller.commitStroke(), isTrue);
      await h.saved();
      final painted = h.state.draft!;
      expect(painted.history.undoStack, hasLength(1));
      expect(painted.intent.intentAt(11), 4);
      expect(painted.maskRevision, 1);
      expect(saves, 1);
      h.refiner.fail = true;
      final calls = h.refiner.calls;
      expect(
        await h.controller.undo(photoId: painted.photoId, maskRevision: 1),
        isTrue,
      );
      await h.saved();
      expect(h.state.draft!.intent.bytes, List.filled(100, 0));
      expect(saves, 2);
      expect(
        await h.controller.redo(photoId: painted.photoId, maskRevision: 2),
        isTrue,
      );
      await h.saved();
      expect(h.state.draft!.masks.labels, painted.masks.labels);
      expect(h.state.draft!.intent.bytes, painted.intent.bytes);
      expect(h.refiner.calls, calls);
      expect(saves, 3);
      h.refiner.fail = false;
      expect(
        await h.controller.undo(photoId: painted.photoId, maskRevision: 3),
        isTrue,
      );
      await h.saved();
      expect(await h.paint(value: stroke(layer: RoomLayer.floor)), isTrue);
      await h.saved();
      expect(h.state.draft!.history.redoStack, isEmpty);
      expect(saves, 5);
    },
  );

  for (final action in [
    'cancel',
    'second begin',
    'layer',
    'tool',
    'brush',
    'close',
    'dispose',
  ]) {
    test(
      'incomplete stroke $action changes no visible or durable bytes',
      () async {
        final h = Harness();
        await h.ready();
        await h.saved();
        final original = h.state.draft!;
        final session = h.container.read(roomProjectSessionProvider)!;
        var saves = 0;
        h.projects.beforeSave = () async {
          saves++;
        };
        h.controller.setTool(RoomMaskTool.add);
        final controller = h.controller;
        expect(controller.beginStroke(const Offset(5.5, 5.5)), isTrue);
        expect(controller.extendStroke(const Offset(6.5, 5.5)), isTrue);
        switch (action) {
          case 'cancel':
            controller.cancelStroke();
          case 'second begin':
            expect(controller.beginStroke(const Offset(3.5, 3.5)), isFalse);
          case 'layer':
            controller.setLayer(RoomLayer.floor);
          case 'tool':
            controller.setTool(RoomMaskTool.erase);
          case 'brush':
            controller.setBrushFraction(.10);
          case 'close':
            await controller.closeProject();
          case 'dispose':
            h.container.invalidate(roomMaskProvider);
        }
        expect(await controller.commitStroke(), isFalse);
        await tick();
        if (action != 'close' && action != 'dispose') {
          expect(h.state.draft, same(original));
        }
        expect(saves, 0);
        expect(
          (await h.projects.read(session.projectId))!.snapshot.maskBytes,
          original.masks.labels,
        );
        expect(
          (await h.projects.read(session.projectId))!.snapshot.intent.bytes,
          List.filled(100, 0),
        );
      },
    );
  }

  test(
    'cancelled in-flight stroke and stale selection discard complete worker result',
    () async {
      final h = Harness();
      await h.ready();
      await h.saved();
      h.controller.setTool(RoomMaskTool.add);
      var saves = 0;
      h.projects.beforeSave = () async {
        saves++;
      };
      for (final cancel in [true, false]) {
        final before = h.state.draft!;
        h.refiner.gate = Completer<void>();
        expect(h.controller.beginStroke(const Offset(5.5, 5.5)), isTrue);
        final completing = h.controller.commitStroke();
        if (cancel) {
          h.controller.cancelStroke();
        } else {
          h.controller.setLayer(RoomLayer.floor);
        }
        h.refiner.gate!.complete();
        expect(await completing, isFalse);
        expect(h.state.draft, same(before));
        expect(saves, 0);
      }
    },
  );

  test(
    'source edge excursion breaks stroke segments and Move cannot paint',
    () async {
      final h = Harness();
      await h.ready();
      await h.saved();
      expect(h.controller.beginStroke(const Offset(5.5, 5.5)), isFalse);
      h.controller.setTool(RoomMaskTool.add);
      for (final point in [
        const Offset(-1, 0),
        const Offset(10, 5),
        Offset(double.nan, 0),
      ]) {
        expect(h.controller.beginStroke(point), isFalse);
      }
      expect(h.controller.beginStroke(const Offset(1.5, 1.5)), isTrue);
      expect(h.controller.extendStroke(const Offset(-1, 3)), isFalse);
      expect(h.controller.extendStroke(const Offset(8.5, 8.5)), isTrue);
      expect(await h.controller.commitStroke(), isTrue);
      expect(h.state.draft!.masks.labels[11], 1);
      expect(h.state.draft!.masks.labels[88], 1);
      expect(h.state.draft!.masks.labels[55], 0);
    },
  );

  test(
    'refresh protects intent and rebases both stacks with one save and honest baseline',
    () async {
      final h = Harness();
      await h.ready(1);
      await h.saved();
      var saves = 0;
      h.projects.beforeSave = () async {
        saves++;
      };
      h.controller.setTool(RoomMaskTool.add);
      expect(await h.paint(), isTrue);
      await h.saved();
      h.controller.setLayer(RoomLayer.floor);
      expect(
        await h.paint(
          value: MaskStroke(
            layer: RoomLayer.floor,
            mode: MaskEditMode.add,
            segments: [
              [MaskPoint(.15, .15)],
            ],
          ),
        ),
        isTrue,
      );
      await h.saved();
      var draft = h.state.draft!;
      expect(
        await h.controller.undo(
          photoId: draft.photoId,
          maskRevision: draft.maskRevision,
        ),
        isTrue,
      );
      await h.saved();
      expect(await h.controller.refreshAiMasks(masks(4)), isTrue);
      await h.saved();
      draft = h.state.draft!;
      expect(saves, 4);
      expect(draft.aiMasks.labels, List.filled(100, 4));
      expect(draft.masks.labels[55], 1);
      expect(draft.masks.labels[11], 4);
      expect(draft.history.undoStack.single.beforeLabels, [4]);
      expect(draft.history.undoStack.single.afterLabels, [1]);
      expect(draft.history.undoStack.single.afterIntent, [2]);
      expect(draft.history.redoStack.single.beforeLabels, [4]);
      expect(draft.history.redoStack.single.afterLabels, [3]);
      expect(
        await h.controller.redo(
          photoId: draft.photoId,
          maskRevision: draft.maskRevision,
        ),
        isTrue,
      );
      await h.saved();
      expect(h.state.draft!.masks.labels[11], 3);
      expect(h.state.draft!.intent.intentAt(11), 4);
      expect(saves, 5);
      final before = h.state.draft!;
      expect(
        await h.controller.refreshAiMasks(
          MaskBitmap(width: 1, height: 100, labels: Uint8List(100)),
        ),
        isFalse,
      );
      expect(
        await h.controller.refreshAiMasks(masks(2), photoId: 'wrong'),
        isFalse,
      );
      expect(
        await h.controller.refreshAiMasks(masks(2), maskRevision: 0),
        isFalse,
      );
      expect(h.state.draft, same(before));
      expect(saves, 5);
      expect(
        h.controller.restoreAiMasks(
          photoId: before.photoId,
          maskRevision: before.maskRevision,
        ),
        isTrue,
      );
      await h.saved();
      expect(h.state.draft!.intent.bytes, List.filled(100, 0));
      expect(h.state.draft!.history.byteLength, 0);
      expect(h.state.draft!.hasEdits, isFalse);
      expect(saves, 6);
    },
  );

  test(
    'invalid no-op refresh rebase rejects atomically without dropping a command',
    () async {
      final h = Harness();
      await h.ready();
      await h.saved();
      final original = h.container.read(roomProjectSessionProvider)!.durable!;
      await h.controller.closeProject();
      final edit = exact.MaskEditCommand(
        width: 10,
        height: 10,
        indices: Uint32List.fromList([0]),
        beforeLabels: Uint8List.fromList([0]),
        afterLabels: Uint8List.fromList([1]),
        beforeIntent: Uint8List(1),
        afterIntent: Uint8List(1),
      );
      final stored = await h.projects.save(
        original.copyWith(
          maskBytes: Uint8List(100)..[0] = 1,
          history: MaskEditHistory.fromStacks(
            width: 10,
            height: 10,
            undoStack: [edit],
          ),
        ),
        expectedRevision: original.revision,
      );
      expect(await h.controller.openProject(stored.projectId), isTrue);
      final before = h.state.draft!;
      final session = h.container.read(roomProjectSessionProvider);
      var saves = 0;
      h.projects.beforeSave = () async {
        saves++;
      };
      expect(await h.controller.refreshAiMasks(masks(1)), isFalse);
      expect(h.state.draft, same(before));
      expect(h.container.read(roomProjectSessionProvider), same(session));
      expect(saves, 0);
    },
  );

  test(
    'session replacement cancels incomplete stroke and stale AI result',
    () async {
      final h = Harness();
      await h.ready(1);
      await h.saved();
      h.controller.setTool(RoomMaskTool.add);
      expect(h.controller.beginStroke(const Offset(5.5, 5.5)), isTrue);
      await h.container
          .read(roomProjectSessionProvider.notifier)
          .closeProject();
      expect(await h.controller.commitStroke(), isFalse);
      final before = h.state.draft!;
      final refresh = h.controller.reanalyzeCurrentPhoto();
      await h.container
          .read(roomProjectSessionProvider.notifier)
          .createFromAnalysis(before);
      h.segmenter.requests.last.succeed(masks(4));
      expect(await refresh, isFalse);
      expect(h.state.draft, same(before));
      await h.saved();
    },
  );

  test('AI completion after selection change cannot publish or save', () async {
    final h = Harness();
    await h.ready(1);
    await h.saved();
    var saves = 0;
    h.projects.beforeSave = () async {
      saves++;
    };
    final before = h.state.draft!;
    final refresh = h.controller.reanalyzeCurrentPhoto();
    h.controller.setLayer(RoomLayer.floor);
    h.segmenter.requests.last.succeed(masks(4));
    expect(await refresh, isFalse);
    expect(h.state.draft, same(before));
    expect(saves, 0);
    expect(h.state.editBusy, isFalse);
  });

  for (final lateFailure in [false, true]) {
    test(
      'stopping analysis retains the prepared photo for manual fallback despite late ${lateFailure ? 'failure' : 'success'}',
      () async {
        final h = Harness();
        final importing = h.import();
        await tick();
        final candidate = h.state.candidate!;
        h.controller.cancelAnalysis();
        expect(h.state.candidate, same(candidate));
        expect(h.state.stage, RoomMaskStage.acquiring);
        expect(h.state.draft, isNull);
        expect(h.controller.createManualFallback(), isTrue);
        final manual = h.state.draft!;
        expect(manual.photo, same(candidate.photo));
        expect(manual.masks.labels, List.filled(100, 0));
        if (lateFailure) {
          h.segmenter.requests.single.fail();
        } else {
          h.segmenter.requests.single.succeed(masks(3));
        }
        await importing;
        expect(h.state.draft, same(manual));
        expect(h.state.canEdit, isTrue);
        expect(h.state.failure, isNull);
        await h.saved();
      },
    );
  }

  for (final typed in [false, true]) {
    test(
      'stale ${typed ? 'typed' : 'raw'} Open failure leaves a newer color edit usable',
      () async {
        final h = Harness();
        await h.ready();
        await h.saved();
        final id = h.container.read(roomProjectSessionProvider)!.projectId;
        h.projects.readGate = Completer<void>();
        h.projects.readError = typed
            ? const RoomProjectStorageException()
            : StateError('private decode failure');
        final opening = h.controller.openProject(id);
        await tick();
        h.controller.setLayerColor(RoomLayer.wall, RgbColor(11, 22, 33));
        await h.saved();
        h.projects.readGate!.complete();
        expect(await opening, isFalse);
        expect(h.state.stage, RoomMaskStage.ready);
        expect(h.state.canEdit, isTrue);
        expect(h.state.failure, isNull);
        expect(h.state.draft!.colors.wall, RgbColor(11, 22, 33));
        expect(
          h.container.read(roomProjectSessionProvider)!.durable!.colors.wall,
          RgbColor(11, 22, 33),
        );
      },
    );
  }

  test(
    'missing Open during reanalysis cannot strand the current operation',
    () async {
      final h = Harness();
      await h.ready(1);
      await h.saved();
      final refresh = h.controller.reanalyzeCurrentPhoto();
      expect(await h.controller.openProject('missing-project'), isFalse);
      h.segmenter.requests.last.succeed(masks(3));
      expect(await refresh, isTrue);
      expect(h.state.stage, RoomMaskStage.ready);
      expect(h.state.editBusy, isFalse);
      expect(h.state.canEdit, isTrue);
      expect(h.state.draft!.masks.labels[0], 3);
    },
  );

  test(
    'late project open cannot detach the editor after a newer import starts',
    () async {
      final h = Harness();
      final original = await h.ready();
      await h.saved();
      final saved = h.container.read(roomProjectSessionProvider)!.durable!;
      await h.projects.save(
        saved.copyWith(projectId: 'another-project', photoId: 'another-photo'),
        expectedRevision: 0,
      );
      h.projects.readGate = Completer<void>();
      final opening = h.controller.openProject('another-project');
      await tick();
      final importing = h.import();
      await tick();
      h.projects.readGate!.complete();
      expect(await opening, isFalse);
      h.segmenter.requests.last.fail();
      await importing;
      h.controller.cancelCandidate();
      expect(h.state.draft, same(original));
      expect(
        h.container.read(roomProjectSessionProvider)!.projectId,
        saved.projectId,
      );
      h.controller.setLayerColor(RoomLayer.wall, RgbColor(10, 20, 30));
      await h.saved();
      expect(
        h.container.read(roomProjectSessionProvider)!.durable!.colors.wall,
        RgbColor(10, 20, 30),
      );
    },
  );

  test(
    'disposing editor invalidates pending autosaves before they can recreate data',
    () async {
      final h = Harness();
      await h.ready();
      await h.saved();
      final id = h.container.read(roomProjectSessionProvider)!.projectId;
      final gate = Completer<void>();
      var calls = 0;
      h.projects.beforeSave = () {
        calls++;
        return gate.future;
      };
      h.controller.setLayerColor(RoomLayer.wall, RgbColor(1, 2, 3));
      await tick();
      h.controller.setLayerColor(RoomLayer.wall, RgbColor(4, 5, 6));
      h.container.invalidate(roomMaskProvider);
      h.container.read(roomMaskProvider);
      await tick();
      expect(h.container.read(roomProjectSessionProvider), isNull);
      gate.complete();
      await h.projects.delete(id);
      await tick();
      expect(calls, 1);
      expect(await h.projects.read(id), isNull);
    },
  );

  test(
    'manual fallback explicitly saves failed analysis photo and retry rebases corrections',
    () async {
      final h = Harness();
      final importing = h.import();
      await tick();
      h.segmenter.requests.single.fail(
        RoomSegmentationFailureKind.modelUnavailable,
      );
      await importing;
      final candidate = h.state.candidate!;
      expect(h.controller.createManualFallback(), isTrue);
      expect(h.state.canEdit, isTrue);
      expect(h.state.draft!.photo, same(candidate.photo));
      expect(h.state.draft!.photoId, candidate.photoId);
      expect(h.state.draft!.manualMode, isTrue);
      expect(h.state.draft!.aiMasks.labels, List.filled(100, 0));
      expect(h.state.draft!.masks.labels, List.filled(100, 0));
      await h.saved();
      h.controller.setTool(RoomMaskTool.add);
      expect(await h.paint(), isTrue);
      final retry = h.controller.retryAnalysis();
      h.segmenter.requests.last.succeed(masks(3));
      await retry;
      expect(h.state.draft!.manualMode, isFalse);
      expect(h.state.draft!.masks.labels[55], 1);
      expect(h.state.draft!.masks.labels[0], 3);
      await h.saved();
      final saved = h.container.read(roomProjectSessionProvider)!.durable!;
      expect(saved.revision, 3);
      expect(saved.maskRevision, 2);
      expect(saved.aiMaskBytes[55], 3);
      expect(saved.maskBytes[55], 1);
    },
  );

  test(
    'only completed durable mutations save; cancelled and failed refinements do not',
    () async {
      final h = Harness();
      await h.ready(3);
      await h.saved();
      final id = h.container.read(roomProjectSessionProvider)!.projectId;
      Future<int> revision() async =>
          (await h.projects.read(id))!.snapshot.revision;
      h.controller.setLayer(RoomLayer.floor);
      h.controller.setBrushFraction(.08);
      h.controller.setShowOverlay(false);
      h.controller.setShowOverlay(true);
      h.controller.setLayer(RoomLayer.wall);
      h.controller.setTool(RoomMaskTool.add);
      expect(await revision(), 1);
      h.refiner.gate = Completer<void>();
      final cancelled = h.paint();
      h.controller.setTool(RoomMaskTool.move);
      h.refiner.gate!.complete();
      expect(await cancelled, isFalse);
      expect(await revision(), 1);
      h.refiner.gate = null;
      h.controller.setTool(RoomMaskTool.add);
      expect(await h.paint(), isTrue);
      await h.saved();
      expect(await revision(), 2);
      final draft = h.state.draft!;
      expect(
        await h.controller.undo(
          photoId: draft.photoId,
          maskRevision: draft.maskRevision,
        ),
        isTrue,
      );
      await h.saved();
      expect(await revision(), 3);
      h.controller.setLayerColor(RoomLayer.wall, RgbColor(1, 2, 3));
      await h.saved();
      expect(await revision(), 4);
      h.controller.setLayerColor(RoomLayer.wall, RgbColor(1, 2, 3));
      expect(await revision(), 4);
      h.controller.restoreAiMasks(
        photoId: draft.photoId,
        maskRevision: h.state.draft!.maskRevision,
      );
      await h.saved();
      expect(await revision(), 5);
      h.refiner.fail = true;
      expect(await h.paint(), isFalse);
      expect(await revision(), 5);
    },
  );

  test(
    'controller reopen restores persisted exact history and no extra save',
    () async {
      final h = Harness();
      await h.ready(3);
      h.controller.setTool(RoomMaskTool.add);
      await h.paint();
      h.controller.setLayerColor(RoomLayer.floor, RgbColor(4, 5, 6));
      await h.saved();
      final saved = h.container.read(roomProjectSessionProvider)!.durable!;
      await h.controller.closeProject();
      expect(h.state.draft, isNull);
      expect(await h.controller.openProject(saved.projectId), isTrue);
      expect(h.state.canEdit, isTrue);
      expect(h.state.draft!.history.canUndo, isTrue);
      expect(h.state.draft!.intent.bytes, saved.intent.bytes);
      expect(h.state.draft!.masks.labels, saved.maskBytes);
      expect(h.state.draft!.colors.floor, RgbColor(4, 5, 6));
      expect((await h.projects.read(saved.projectId))!.snapshot.revision, 3);
    },
  );
  for (final kind in [
    'intent-only undo',
    'label and intent undo',
    'nonempty redo',
  ]) {
    test('refresh rebases exact history: $kind', () async {
      final h = Harness();
      await h.ready(1);
      await h.saved();
      final original = h.container.read(roomProjectSessionProvider)!.durable!;
      await h.controller.closeProject();
      final redo = kind == 'nonempty redo';
      final intentOnly = kind == 'intent-only undo';
      final beforeIntent = kind == 'label and intent undo' ? 2 : 0;
      final afterIntent = redo
          ? 5
          : intentOnly
          ? 2
          : 5;
      final edit = exact.MaskEditCommand(
        width: 10,
        height: 10,
        indices: Uint32List.fromList([0]),
        beforeLabels: Uint8List.fromList([1]),
        afterLabels: Uint8List.fromList([intentOnly ? 1 : 4]),
        beforeIntent: Uint8List.fromList([beforeIntent]),
        afterIntent: Uint8List.fromList([afterIntent]),
      );
      final currentLabels = Uint8List(100)..fillRange(0, 100, 1);
      currentLabels[0] = redo ? 1 : edit.afterLabels[0];
      final intent = Uint8List(100)..[0] = redo ? beforeIntent : afterIntent;
      final stored = await h.projects.save(
        original.copyWith(
          maskBytes: currentLabels,
          intent: MaskIntentBitmap.fromBytes(
            width: 10,
            height: 10,
            bytes: intent,
          ),
          history: MaskEditHistory.fromStacks(
            width: 10,
            height: 10,
            undoStack: redo ? [] : [edit],
            redoStack: redo ? [edit] : [],
          ),
        ),
        expectedRevision: original.revision,
      );
      expect(await h.controller.openProject(stored.projectId), isTrue);
      var saves = 0;
      h.projects.beforeSave = () async {
        saves++;
      };
      final before = h.state.draft!;
      final refresh = h.controller.reanalyzeCurrentPhoto();
      h.segmenter.requests.last.succeed(masks(4));
      expect(await refresh, isTrue);
      await h.saved();
      final after = h.state.draft!;
      expect(after.intent.bytes, intent);
      expect(after.history.undoStack.length, before.history.undoStack.length);
      expect(after.history.redoStack.length, before.history.redoStack.length);
      final rebased = redo
          ? after.history.redoStack.single
          : after.history.undoStack.single;
      expect(rebased.beforeIntent, [beforeIntent]);
      expect(rebased.afterIntent, [afterIntent]);
      expect(rebased.beforeLabels, [beforeIntent == 0 ? 4 : beforeIntent - 1]);
      expect(rebased.afterLabels, [afterIntent - 1]);
      expect(saves, 1);
    });
  }

  test(
    'refresh keeps manual Add and Erase, colors, and rebased undo',
    () async {
      final h = Harness();
      await h.ready(RoomLayer.wall.label);
      h.controller.setTool(RoomMaskTool.erase);
      expect(await h.paint(value: stroke(erase: true)), isTrue);
      h.controller.setLayer(RoomLayer.floor);
      h.controller.setTool(RoomMaskTool.add);
      expect(
        await h.paint(
          value: MaskStroke(
            layer: RoomLayer.floor,
            mode: MaskEditMode.add,
            segments: [
              [MaskPoint(.15, .15)],
            ],
            diameterFraction: .05,
          ),
        ),
        isTrue,
      );
      final color = RgbColor(12, 34, 56);
      h.controller.setLayerColor(RoomLayer.wall, color);
      final before = h.state.draft!;
      final refresh = h.controller.reanalyzeCurrentPhoto();
      expect(h.state.draft, same(before));
      expect(h.state.stage, RoomMaskStage.analyzing);
      expect(h.state.editBusy, isTrue);
      expect(await h.controller.reanalyzeCurrentPhoto(), isFalse);
      expect(await h.paint(), isFalse);
      expect(h.controller.setLayerColor(RoomLayer.wall, null), isFalse);
      final request = h.segmenter.requests.last;
      expect(request.photo, same(before.photo));
      expect(request.id, before.photoId);
      final nextLabels = Uint8List(100)..fillRange(0, 100, 4);
      nextLabels[55] = 2;
      request.succeed(MaskBitmap(width: 10, height: 10, labels: nextLabels));
      expect(await refresh, isTrue);
      final after = h.state.draft!;
      expect(after.photoId, before.photoId);
      expect(after.photo, same(before.photo));
      expect(after.masks.labels[0], 4);
      expect(after.masks.labels[11], 3);
      expect(after.masks.labels[55], 0);
      expect(after.aiMasks.labels[11], 4);
      expect(after.aiMasks.labels[55], 2);
      expect(after.changedFromAiCount, 2);
      expect(after.maskRevision, before.maskRevision + 1);
      expect(after.colors, same(before.colors));
      expect(after.colorRevision, before.colorRevision);
      expect(after.history.commands.length, 2);
      expect(
        await h.controller.undo(
          photoId: after.photoId,
          maskRevision: after.maskRevision,
        ),
        isTrue,
      );
      expect(h.state.draft!.masks.labels[11], 4);
      expect(h.state.draft!.changedFromAiCount, 1);
      final last = h.state.draft!;
      expect(
        await h.controller.undo(
          photoId: last.photoId,
          maskRevision: last.maskRevision,
        ),
        isTrue,
      );
      expect(h.state.draft!.masks.labels[55], 2);
      expect(h.state.draft!.changedFromAiCount, 0);
    },
  );

  test('refresh with unchanged predictions still advances revision', () async {
    final h = Harness();
    final before = await h.ready(1);
    final refresh = h.controller.reanalyzeCurrentPhoto();
    h.segmenter.requests.last.succeed(masks(1));
    expect(await refresh, isTrue);
    expect(h.state.draft!.maskRevision, before.maskRevision + 1);
    expect(h.state.draft!.changedFromAiCount, 0);
    expect(h.state.canEdit, isTrue);
  });

  for (final kind in RoomSegmentationFailureKind.values) {
    test('refresh $kind keeps the edited draft usable', () async {
      final h = Harness();
      await h.ready();
      h.controller.setTool(RoomMaskTool.add);
      await h.paint();
      final before = h.state.draft!;
      final refresh = h.controller.reanalyzeCurrentPhoto();
      h.segmenter.requests.last.fail(kind);
      expect(await refresh, isFalse);
      expect(h.state.draft, same(before));
      expect(h.state.stage, RoomMaskStage.ready);
      expect(h.state.failure!.name, kind.name);
      expect(h.state.canEdit, isTrue);
    });
  }

  for (final wrongId in [false, true]) {
    test(
      'refresh rejects wrong ${wrongId ? 'identity' : 'dimensions'}',
      () async {
        final h = Harness();
        final before = await h.ready(1);
        final refresh = h.controller.reanalyzeCurrentPhoto();
        h.segmenter.requests.last.result.complete(
          RoomSegmentationResult(
            photoId: wrongId ? 'another-photo' : before.photoId,
            masks: wrongId
                ? masks(4)
                : MaskBitmap(width: 1, height: 1, labels: Uint8List(1)),
          ),
        );
        expect(await refresh, isFalse);
        expect(h.state.draft, same(before));
        expect(h.state.failure, RoomMaskFailureKind.invalidOutput);
        expect(h.state.canEdit, isTrue);
      },
    );
  }

  for (final completion in ['success', 'error']) {
    for (final supersede in ['photo', 'edit', 'dispose']) {
      test('late refresh $completion cannot overwrite $supersede', () async {
        final h = Harness();
        await h.ready(1);
        final refresh = h.controller.reanalyzeCurrentPhoto();
        final pending = h.segmenter.requests.last;
        if (supersede == 'photo') {
          h.picker.next = photo(2);
          await h.ready(3);
        } else if (supersede == 'edit') {
          h.controller.cancelCandidate();
          h.controller.setTool(RoomMaskTool.erase);
          await h.paint(value: stroke(erase: true));
        } else {
          h.container.invalidate(roomMaskProvider);
        }
        final current = h.state.draft;
        if (completion == 'success') {
          pending.succeed(masks(4));
        } else {
          pending.fail();
        }
        expect(await refresh, isFalse);
        expect(h.state.draft, same(current));
        expect(h.state.failure, isNull);
      });
    }
  }

  test(
    'refresh refuses empty, importing, and active refinement states',
    () async {
      final h = Harness();
      expect(await h.controller.reanalyzeCurrentPhoto(), isFalse);
      final importing = h.import();
      await tick();
      expect(await h.controller.reanalyzeCurrentPhoto(), isFalse);
      h.segmenter.requests.last.succeed();
      await importing;
      h.controller.setTool(RoomMaskTool.add);
      h.refiner.gate = Completer<void>();
      final edit = h.paint();
      expect(await h.controller.reanalyzeCurrentPhoto(), isFalse);
      h.refiner.gate!.complete();
      expect(await edit, isTrue);
      expect(h.state.draft!.masks.labels[55], 1);
    },
  );

  test(
    'refresh bypasses the real service cached result for the same photo',
    () async {
      final workers = <ControlledRefreshWorker>[];
      final h = Harness(
        segmentationFactory: () => IsolateRoomSegmentationService(
          workerFactory: () async {
            final worker = ControlledRefreshWorker();
            workers.add(worker);
            return worker;
          },
        ),
      );
      final importing = h.import();
      await tick();
      workers.single.result.complete(masks(1));
      await importing;
      final before = h.state.draft!;
      final refresh = h.controller.reanalyzeCurrentPhoto();
      await tick();
      expect(workers.length, 2);
      workers.last.result.complete(masks(4));
      expect(await refresh, isTrue);
      expect(h.state.draft!.masks.labels[0], 4);
      expect(h.state.draft!.photo, same(before.photo));
      expect(workers.first.closed, isTrue);
    },
  );

  test(
    'provider creation is inert; only a successful AI draft permits edits',
    () async {
      final h = Harness();
      expect(h.state.stage, RoomMaskStage.empty);
      expect(h.state.canEdit, isFalse);
      expect(h.state.selectedLayer, RoomLayer.wall);
      expect(h.state.tool, RoomMaskTool.move);
      expect(h.state.brushFraction, .05);
      expect(h.state.showOverlay, isTrue);
      await tick();
      expect(h.picker.recoveries, 0);
      expect(h.segmenter.requests, isEmpty);
      expect(
        await h.controller.undo(photoId: 'photo-0', maskRevision: 0),
        isFalse,
      );
      final operation = h.import();
      await tick();
      expect(h.state.stage, RoomMaskStage.analyzing);
      expect(h.state.canEdit, isFalse);
      expect(h.state.draft, isNull);
      h.segmenter.requests.single.succeed();
      await operation;
      expect(h.state.canEdit, isTrue);
      expect(h.state.draft!.masks.count(RoomLayer.wall), 0);
      h.controller.setTool(RoomMaskTool.add);
      expect(await h.paint(), isTrue);
      expect(h.state.draft!.masks.labels[55], 1);
      expect(h.state.draft!.hasEdits, isTrue);
      expect(h.state.draft!.maskRevision, 1);
    },
  );

  for (final oldFails in [false, true]) {
    test(
      'late A ${oldFails ? 'error' : 'success'} cannot overwrite equal-sized B',
      () async {
        final h = Harness();
        final first = h.import();
        await tick();
        final a = h.segmenter.requests.single;
        h.picker.next = photo(2);
        final second = h.import();
        await tick();
        final b = h.segmenter.requests.last;
        expect(a.id, isNot(b.id));
        expect(a.photo.width, b.photo.width);
        b.succeed(masks(3));
        await second;
        final committedB = h.state.draft;
        if (oldFails) {
          a.fail();
        } else {
          a.succeed(masks(1));
        }
        await first;
        expect(h.state.draft, same(committedB));
        expect(h.state.stage, RoomMaskStage.ready);
        expect(h.state.failure, isNull);
      },
    );
  }

  test(
    'pick cancel, inference failure and logical cancel preserve committed edits',
    () async {
      final h = Harness();
      await h.ready();
      h.controller.setTool(RoomMaskTool.add);
      await h.paint();
      final committed = h.state.draft;
      h.picker.next = null;
      await h.import();
      expect(h.state.draft, same(committed));
      expect(h.state.stage, RoomMaskStage.ready);
      h.picker.next = photo(2);
      final replacement = h.import();
      await tick();
      expect(h.state.draft, same(committed));
      expect(h.state.canEdit, isFalse);
      h.segmenter.requests.last.fail(
        RoomSegmentationFailureKind.modelUnavailable,
      );
      await replacement;
      expect(h.state.failure, RoomMaskFailureKind.modelUnavailable);
      expect(h.state.canEdit, isFalse);
      expect(h.state.draft, same(committed));
      final retry = h.controller.retryAnalysis();
      await tick();
      final pending = h.segmenter.requests.last;
      expect(pending.photo, same(h.state.candidate!.photo));
      h.controller.cancelCandidate();
      expect(h.state.draft, same(committed));
      expect(h.state.canEdit, isTrue);
      pending.succeed(masks(4));
      await retry;
      expect(h.state.draft, same(committed));
    },
  );

  for (final kind in RoomSegmentationFailureKind.values) {
    test('actual inference $kind never enables blank manual editing', () async {
      final h = Harness();
      final operation = h.import();
      await tick();
      h.segmenter.requests.single.fail(kind);
      await operation;
      expect(h.state.stage, RoomMaskStage.error);
      expect(h.state.draft, isNull);
      expect(h.state.canEdit, isFalse);
      expect(h.state.failure!.name, kind.name);
      expect(
        h.controller.restoreAiMasks(photoId: 'photo-0', maskRevision: 0),
        isFalse,
      );
      final retry = h.controller.retryAnalysis();
      await tick();
      h.segmenter.requests.last.succeed();
      await retry;
      expect(h.state.canEdit, isTrue);
      expect(h.picker.picks, 1);
    });
  }

  test('wrong result identity or dimensions cannot commit', () async {
    for (final wrongIdentity in [false, true]) {
      final h = Harness();
      final operation = h.import();
      await tick();
      final request = h.segmenter.requests.single;
      request.result.complete(
        RoomSegmentationResult(
          photoId: wrongIdentity ? 'different-photo' : request.id,
          masks: wrongIdentity
              ? masks()
              : MaskBitmap(width: 1, height: 1, labels: Uint8List(1)),
        ),
      );
      await operation;
      expect(h.state.failure, RoomMaskFailureKind.invalidOutput);
      expect(h.state.draft, isNull);
    }
  });

  test('inactive request neither recovers nor opens native picker', () async {
    final h = Harness();
    await h.import(isActive: () => false);
    await h.import(isActive: () => throw StateError('gone'));
    expect(h.picker.recoveries, 0);
    expect(h.picker.picks, 0);
    expect(h.state.stage, RoomMaskStage.empty);
  });

  for (final boundary in ['recovery', 'save']) {
    for (final cancel in [false, true]) {
      test(
        '${cancel ? 'cancel' : 'hide'} during $boundary blocks native launch',
        () async {
          final h = Harness();
          final gate = Completer<void>();
          if (boundary == 'recovery') {
            h.picker.recoveryGate = gate;
          } else {
            h.store.saveGate = gate;
          }
          var active = true;
          final operation = h.import(isActive: () => active);
          await tick();
          if (cancel) {
            h.controller.cancelCandidate();
          } else {
            active = false;
          }
          gate.complete();
          await operation;
          expect(h.picker.picks, 0);
          expect(h.segmenter.requests, isEmpty);
          expect(h.state.stage, RoomMaskStage.empty);
        },
      );
    }
  }

  test(
    'late hidden receipt stays pending until explicit matching continue',
    () async {
      final h = Harness();
      h.picker.pickGate = Completer<void>();
      var active = true;
      final operation = h.import(isActive: () => active);
      await tick();
      active = false;
      h.picker.pickGate!.complete();
      await operation;
      final receipt = h.pending!;
      expect(h.store.clears, 0);
      expect(h.state.candidate, isNull);
      expect(h.segmenter.requests, isEmpty);
      await h.controller.continueImport(
        receipt.requestId,
        isActive: () => false,
      );
      expect(h.pending, same(receipt));
      active = true;
      final continuation = h.controller.continueImport(
        receipt.requestId,
        isActive: () => active,
      );
      await tick();
      expect(h.pending, isNull);
      expect(h.state.candidate!.photoId, isNot(receipt.requestId));
      expect(h.segmenter.requests.single.photo, same(receipt.photo));
      h.segmenter.requests.single.succeed();
      await continuation;
      expect(h.state.canEdit, isTrue);
    },
  );

  test(
    'retained receipt claim rejects duplicate and stale continuations without losing pixels',
    () async {
      final h = Harness();
      final old = await h.ready();
      h.picker.next = photo(2);
      final replacement = h.picker.next;
      h.store.clearGate = Completer<void>();
      var active = true;
      final operation = h.import(isActive: () => active);
      await tick();
      final receipt = h.pending!;
      active = false;
      await h.controller.continueImport(
        receipt.requestId,
        isActive: () => true,
      );
      expect(h.state.stage, RoomMaskStage.acquiring);
      expect(h.state.failure, isNull);
      expect(h.state.draft, same(old));
      h.store.clearGate!.complete();
      await operation;
      final candidate = h.state.candidate!;
      expect(candidate.photo, same(replacement));
      expect(h.pending, isNull);
      await h.controller.continueImport(
        receipt.requestId,
        isActive: () => true,
      );
      expect(h.state.candidate, same(candidate));
      expect(h.state.failure, isNull);
      final analysis = h.controller.analyzeCandidate();
      await tick();
      expect(h.state.draft, same(old));
      h.segmenter.requests.last.succeed(masks(3));
      await analysis;
      expect(h.state.draft!.photo, same(replacement));
      // A settled claim must not lock out a later, independent receipt.
      h.picker.next = photo(3);
      h.picker.pickGate = Completer<void>();
      var laterActive = true;
      final later = h.import(isActive: () => laterActive);
      await tick();
      laterActive = false;
      h.picker.pickGate!.complete();
      await later;
      final laterReceipt = h.pending!;
      final continuation = h.controller.continueImport(
        laterReceipt.requestId,
        isActive: () => true,
      );
      await tick();
      expect(h.pending, isNull);
      expect(h.segmenter.requests.last.photo, same(h.picker.next));
      h.segmenter.requests.last.succeed(masks(4));
      await continuation;
      expect(h.state.draft!.photo, same(h.picker.next));
      expect(h.state.canEdit, isTrue);
    },
  );

  test(
    'hidden mid-claim stages accepted pixels without unseen inference',
    () async {
      final h = Harness();
      h.store.clearGate = Completer<void>();
      var active = true;
      final operation = h.import(isActive: () => active);
      await tick();
      expect(h.store.clears, 1);
      active = false;
      h.store.clearGate!.complete();
      await operation;
      expect(h.pending, isNull);
      expect(h.state.stage, RoomMaskStage.acquiring);
      expect(h.state.editBusy, isFalse);
      expect(h.state.candidate!.photo, same(h.picker.next));
      expect(h.segmenter.requests, isEmpty);
      final analysis = h.controller.analyzeCandidate();
      await tick();
      h.segmenter.requests.single.succeed();
      await analysis;
      expect(h.state.stage, RoomMaskStage.ready);
    },
  );

  for (final invalidate in [false, true]) {
    test(
      '${invalidate ? 'disposed' : 'cancelled'} mid-claim rejects acceptance and retains receipt',
      () async {
        final h = Harness();
        h.store.clearGate = Completer<void>();
        final operation = h.import();
        await tick();
        final receipt = h.pending!;
        if (invalidate) {
          h.container.invalidate(roomMaskProvider);
        } else {
          h.controller.cancelCandidate();
        }
        h.store.clearGate!.complete();
        await operation;
        expect(h.pending, same(receipt));
        expect(h.segmenter.requests, isEmpty);
        expect(h.state.candidate, isNull);
        expect(h.state.stage, RoomMaskStage.empty);
      },
    );
  }

  test('superseded claim cannot consume receipt for old operation', () async {
    final h = Harness();
    h.store.clearGate = Completer<void>();
    final operation = h.import();
    await tick();
    final receipt = h.pending!;
    await h.import(); // Core acquisition gate is busy; supersedes first owner.
    h.store.clearGate!.complete();
    await operation;
    expect(h.pending, same(receipt));
    expect(h.segmenter.requests, isEmpty);
  });

  test('claim storage failure preserves receipt and last draft', () async {
    final h = Harness();
    final committed = await h.ready();
    h.store.failClear = true;
    await h.import();
    expect(h.state.failure, RoomMaskFailureKind.storage);
    expect(h.pending, isNotNull);
    expect(h.state.draft, same(committed));
    expect(h.state.canEdit, isFalse);
    expect(h.segmenter.requests.length, 1);
  });

  test('shared storage retry reconciles only its owned Room error', () async {
    final h = Harness();
    final draft = await h.ready();
    await h.saved();
    h.store.failClear = true;
    await h.import();
    final receipt = h.pending;
    final before = h.container.read(roomProjectSessionProvider);
    h.store.failClear = false;
    await h.container.read(photoAcquisitionProvider.notifier).retryStorage();
    expect(h.state.failure, isNull);
    expect(h.state.stage, RoomMaskStage.ready);
    expect(h.state.draft, same(draft));
    expect(h.pending, same(receipt));
    expect(h.container.read(roomProjectSessionProvider), same(before));
    expect(h.picker.picks, 2);
    expect(h.segmenter.requests, hasLength(1));
  });

  for (final replacement in [
    'new mask error',
    'new session',
    'closed editor',
    'new acquisition owner',
  ]) {
    test('late shared storage retry cannot alter $replacement', () async {
      final h = Harness();
      await h.ready();
      await h.saved();
      h.store.failClear = true;
      await h.import();
      final failed = h.state;
      h.store.failClear = false;
      final gate = h.store.loadGate = Completer<void>();
      final retry = h.container
          .read(photoAcquisitionProvider.notifier)
          .retryStorage();
      await tick();
      switch (replacement) {
        case 'new mask error':
          h.controller.cancelCandidate();
          h.projects.readError = const RoomProjectStorageException();
          expect(await h.controller.openProject('unreadable'), isFalse);
          expect(h.state.failure, RoomMaskFailureKind.storage);
        case 'new session':
          await h.container
              .read(roomProjectSessionProvider.notifier)
              .createManualFallback(
                RoomPhotoCandidate(photoId: 'replacement', photo: photo(2)),
              );
          await h.saved();
        case 'closed editor':
          await h.controller.closeProject();
        case 'new acquisition owner':
          h.container.invalidate(photoAcquisitionProvider);
          h.container.read(photoAcquisitionProvider);
      }
      final newer = h.state;
      final session = h.container.read(roomProjectSessionProvider);
      gate.complete();
      await retry;
      await h.controller.retryAcquisitionStorage(failedState: failed);
      expect(h.state, same(newer));
      expect(h.container.read(roomProjectSessionProvider), same(session));
      expect(h.picker.picks, 2);
      expect(h.segmenter.requests, hasLength(1));
    });
  }

  test(
    'an old photo retry cannot act on a newer failure of the same receipt',
    () async {
      final h = Harness();
      final draft = await h.ready();
      await h.saved();
      h.store.failClear = true;
      await h.import();
      final oldError = h.state;
      final receipt = h.pending!;
      h.store.failClear = false;
      await h.container.read(photoAcquisitionProvider.notifier).retryStorage();
      h.store.failClear = true;
      await h.controller.continueImport(
        receipt.requestId,
        isActive: () => true,
      );
      final newer = h.state;
      final acquisition = h.container.read(photoAcquisitionProvider);
      h.store.failClear = false;
      await h.controller.retryAcquisitionStorage(failedState: oldError);
      expect(h.state, same(newer));
      expect(h.container.read(photoAcquisitionProvider), same(acquisition));
      expect(h.pending, same(receipt));
      await h.controller.retryAcquisitionStorage(failedState: newer);
      expect(h.state.failure, isNull);
      expect(h.state.draft, same(draft));
      expect(h.pending, same(receipt));
      expect(h.picker.picks, 2);
    },
  );

  test('picker failure is typed and last draft survives', () async {
    final h = Harness();
    final committed = await h.ready();
    h.picker.failure = const PhotoPickFailure(
      PhotoPickFailureKind.permissionDenied,
    );
    await h.controller.importPhoto(PhotoSource.camera, isActive: () => true);
    expect(h.picker.source, PhotoSource.camera);
    expect(h.state.failure, RoomMaskFailureKind.permissionDenied);
    expect(h.state.draft, same(committed));
    expect(h.state.canEdit, isFalse);
  });

  test(
    'captured photo/revision/tool/layer guards reject stale mutations',
    () async {
      final h = Harness();
      final a = await h.ready();
      expect(await h.paint(), isFalse); // Move is not a painting tool.
      h.controller.setTool(RoomMaskTool.add);
      expect(await h.paint(value: stroke(layer: RoomLayer.floor)), isFalse);
      expect(await h.paint(value: stroke(erase: true)), isFalse);
      expect(await h.paint(), isTrue);
      final edited = h.state.draft!;
      expect(
        await h.controller.applyStroke(
          photoId: a.photoId,
          maskRevision: 0,
          stroke: stroke(),
        ),
        isFalse,
      );
      expect(
        await h.controller.undo(photoId: a.photoId, maskRevision: 0),
        isFalse,
      );
      expect(
        h.controller.restoreAiMasks(photoId: a.photoId, maskRevision: 0),
        isFalse,
      );
      expect(h.state.draft, same(edited));
      final b = await h.ready(3);
      expect(
        await h.controller.applyStroke(
          photoId: a.photoId,
          maskRevision: edited.maskRevision,
          stroke: stroke(),
        ),
        isFalse,
      );
      expect(
        await h.controller.undo(
          photoId: a.photoId,
          maskRevision: edited.maskRevision,
        ),
        isFalse,
      );
      expect(
        h.controller.restoreAiMasks(
          photoId: a.photoId,
          maskRevision: edited.maskRevision,
        ),
        isFalse,
      );
      expect(h.state.draft, same(b));
      expect(b.history.canUndo, isFalse);
      expect(b.hasEdits, isFalse);
    },
  );

  test(
    'refinement serializes and old completion cannot change replacement',
    () async {
      final h = Harness();
      final a = await h.ready();
      h.controller.setTool(RoomMaskTool.add);
      h.refiner.gate = Completer<void>();
      final edit = h.paint();
      expect(h.state.editBusy, isTrue);
      expect(h.state.canEdit, isFalse);
      expect(await h.paint(), isFalse);
      expect(
        await h.controller.undo(photoId: a.photoId, maskRevision: 0),
        isFalse,
      );
      expect(
        h.controller.restoreAiMasks(photoId: a.photoId, maskRevision: 0),
        isFalse,
      );
      final b = await h.ready(3);
      expect(h.state.editBusy, isTrue);
      expect(h.state.canEdit, isFalse);
      expect(
        await h.paint(),
        isFalse,
      ); // Old physical worker still has the gate.
      h.refiner.gate!.complete();
      expect(await edit, isFalse);
      expect(h.state.draft, same(b));
      expect(h.state.editBusy, isFalse);
      expect(await h.paint(), isTrue);
    },
  );

  for (final selection in ['layer', 'tool', 'overlay']) {
    test(
      '$selection changes discard in-flight stroke even if switched back',
      () async {
        final h = Harness();
        final original = await h.ready();
        h.controller.setTool(RoomMaskTool.add);
        h.refiner.gate = Completer<void>();
        final edit = h.paint();
        switch (selection) {
          case 'layer':
            h.controller.setLayer(RoomLayer.floor);
            h.controller.setLayer(RoomLayer.wall);
          case 'tool':
            h.controller.setTool(RoomMaskTool.erase);
            h.controller.setTool(RoomMaskTool.add);
          case 'overlay':
            h.controller.setShowOverlay(false);
            expect(h.state.tool, RoomMaskTool.move);
            h.controller.setShowOverlay(true);
            h.controller.setTool(RoomMaskTool.add);
        }
        h.refiner.gate!.complete();
        expect(await edit, isFalse);
        expect(h.state.draft, same(original));
        expect(h.state.editBusy, isFalse);
        expect(h.state.canEdit, isTrue);
      },
    );
  }

  test(
    'undo restores exact ownership; restore resets revision and bounded history',
    () async {
      final h = Harness();
      await h.ready(3);
      h.controller.setTool(RoomMaskTool.add);
      await h.paint();
      final edited = h.state.draft!;
      expect(edited.masks.labels[55], 1);
      expect(edited.aiMasks.labels[55], 3);
      expect(
        await h.controller.undo(photoId: edited.photoId, maskRevision: 1),
        isTrue,
      );
      expect(h.state.draft!.masks.labels[55], 3);
      expect(h.state.draft!.hasEdits, isFalse);
      expect(h.state.draft!.maskRevision, 2);
      await h.paint();
      final beforeRestore = h.state.draft!;
      expect(
        h.controller.restoreAiMasks(
          photoId: beforeRestore.photoId,
          maskRevision: 3,
        ),
        isTrue,
      );
      expect(h.state.draft!.masks, same(beforeRestore.aiMasks));
      expect(h.state.draft!.history.canUndo, isFalse);
      expect(h.state.draft!.hasEdits, isFalse);
      expect(h.state.draft!.maskRevision, 4);
      expect(
        h.controller.restoreAiMasks(
          photoId: beforeRestore.photoId,
          maskRevision: 3,
        ),
        isFalse,
      );
    },
  );

  test(
    'history eviction does not confuse dirty status with undo count',
    () async {
      final h = Harness();
      await h.ready();
      for (var i = 0; i < 21; i++) {
        final layer = i.isEven ? RoomLayer.wall : RoomLayer.floor;
        h.controller.setLayer(layer);
        h.controller.setTool(RoomMaskTool.add);
        expect(await h.paint(value: stroke(layer: layer)), isTrue);
      }
      expect(h.state.draft!.history.commands.length, 20);
      for (var i = 0; i < 20; i++) {
        final draft = h.state.draft!;
        expect(
          await h.controller.undo(
            photoId: draft.photoId,
            maskRevision: draft.maskRevision,
          ),
          isTrue,
        );
      }
      expect(h.state.draft!.history.canUndo, isFalse);
      expect(h.state.draft!.changedFromAiCount, 1);
      expect(h.state.draft!.hasEdits, isTrue);
      expect(h.state.draft!.masks.labels[55], 1);
    },
  );

  test(
    'no-op stroke keeps revision/history; erase back to AI keeps explicit intent',
    () async {
      final h = Harness();
      await h.ready();
      h.controller.setTool(RoomMaskTool.add);
      await h.paint();
      final edited = h.state.draft!;
      expect(await h.paint(), isFalse);
      expect(h.state.draft, same(edited));
      h.controller.setTool(RoomMaskTool.erase);
      expect(await h.paint(value: stroke(erase: true)), isTrue);
      expect(h.state.draft!.hasEdits, isTrue);
      expect(h.state.draft!.intent.intentAt(55), 1);
      expect(h.state.draft!.history.commands.length, 2);
    },
  );

  test(
    'direct undo ignores legacy worker gates and rejects stale or disposed ownership',
    () async {
      final h = Harness();
      await h.ready();
      h.controller.setTool(RoomMaskTool.add);
      await h.paint();
      final edited = h.state.draft!;
      h.refiner.gate = Completer<void>();
      h.refiner.fail = true;
      final calls = h.refiner.calls;
      expect(
        await h.controller.undo(photoId: edited.photoId, maskRevision: 0),
        isFalse,
      );
      expect(h.state.draft, same(edited));
      expect(
        await h.controller.undo(photoId: edited.photoId, maskRevision: 1),
        isTrue,
      );
      expect(h.refiner.calls, calls);
      expect(h.state.draft!.intent.bytes, List.filled(100, 0));
      final controller = h.controller;
      h.container.invalidate(roomMaskProvider);
      expect(
        await controller.redo(photoId: edited.photoId, maskRevision: 2),
        isFalse,
      );
      expect(h.state.draft, isNull);
      h.refiner.gate!.complete();
    },
  );

  test(
    'show-original and settings preserve mask snapshots and enforce brush bounds',
    () async {
      final h = Harness();
      final original = await h.ready();
      h.controller.setTool(RoomMaskTool.add);
      h.controller.setShowOverlay(false);
      expect(h.state.tool, RoomMaskTool.move);
      expect(h.state.canEdit, isFalse);
      h.controller.setTool(RoomMaskTool.erase);
      expect(h.state.tool, RoomMaskTool.move);
      expect(await h.paint(), isFalse);
      h.controller.setBrushFraction(.001);
      expect(h.state.brushFraction, .01);
      h.controller.setBrushFraction(1);
      expect(h.state.brushFraction, .20);
      h.controller.setBrushFraction(double.nan);
      expect(h.state.brushFraction, .20);
      h.controller.setShowOverlay(true);
      expect(h.state.draft, same(original));
      expect(h.state.canEdit, isTrue);
    },
  );

  test(
    'navigation subscriptions, selection and unrelated providers never reset masks',
    () async {
      final h = Harness();
      await h.ready();
      h.controller.setTool(RoomMaskTool.add);
      await h.paint();
      final original = h.state.draft!;
      final subscription = h.container.listen(roomMaskProvider, (_, _) {});
      subscription.close();
      await tick();
      final color = RgbColor(12, 34, 56);
      h.container.read(roomColorProvider.notifier).setColor(color);
      h.container.read(matchingGameProvider.notifier).setHue(123);
      h.container.read(mixerProvider.notifier).addColor(color);
      h.container.read(formulaTargetProvider.notifier).setColor(color);
      h.container.read(harmonyDraftProvider.notifier).setBase(color);
      await h.container.read(appPreferencesProvider.future);
      h.container.read(themeModeProvider);
      await h.container
          .read(themeModeProvider.notifier)
          .setMode(ThemeMode.dark);
      await h.container
          .read(colorHistoryProvider.notifier)
          .saveColor(color, name: 'Independent history');
      await h.container
          .read(savedPalettesProvider.notifier)
          .savePalette(
            name: 'Independent palette',
            base: color,
            mode: HarmonyMode.complementary,
            colors: [color, RgbColor(200, 210, 220)],
          );
      h.container.invalidate(roomPhotoIdFactoryProvider);
      h.container.invalidate(roomSegmentationServiceProvider);
      h.container.invalidate(maskRefinementServiceProvider);
      h.controller.setLayer(RoomLayer.ceiling);
      await tick();
      expect(h.state.draft, same(original));
      expect(h.segmenter.requests.length, 1);
      expect(h.container.read(roomColorProvider), color);
      expect(h.container.read(formulaTargetProvider), color);
      expect(h.container.read(matchingGameProvider).hue, 123);
      expect(h.container.read(themeModeProvider), ThemeMode.dark);
      expect(h.container.read(colorHistoryProvider).requireValue.length, 1);
      expect(h.container.read(savedPalettesProvider).requireValue.length, 1);
      final fresh = Harness();
      expect(fresh.state.draft, isNull);
    },
  );

  test(
    'over-budget exact commands retain visible pixels with no partial undo',
    () async {
      final h = Harness();
      h.picker.next = PreparedPhoto(
        width: 1600,
        height: 1600,
        rgbaBytes: Uint8List(1600 * 1600 * 4),
        previewBytes: Uint8List(0),
        palette: const [],
      );
      final operation = h.import();
      await tick();
      h.segmenter.requests.single.succeed(
        MaskBitmap(width: 1600, height: 1600, labels: Uint8List(1600 * 1600)),
      );
      await operation;
      h.controller.setTool(RoomMaskTool.add);
      h.controller.setBrushFraction(.20);
      for (final layer in [RoomLayer.wall, RoomLayer.floor]) {
        h.controller.setLayer(layer);
        expect(
          await h.paint(
            value: MaskStroke(
              layer: layer,
              mode: MaskEditMode.add,
              diameterFraction: .20,
              segments: [
                for (var row = 0; row < 10; row++)
                  [
                    MaskPoint(0, (row + .5) / 10),
                    MaskPoint(1, (row + .5) / 10),
                  ],
              ],
            ),
          ),
          isTrue,
        );
      }
      final draft = h.state.draft!;
      expect(draft.history.commands, isEmpty);
      expect(draft.history.byteLength, 0);
      expect(
        await h.controller.undo(
          photoId: draft.photoId,
          maskRevision: draft.maskRevision,
        ),
        isFalse,
      );
      expect(h.state.draft!.history.canUndo, isFalse);
      expect(h.state.draft!.changedFromAiCount, 2560000);
      expect(h.state.draft!.masks.count(RoomLayer.floor), 2560000);
      expect(h.state.draft!.hasEdits, isTrue);
    },
  );

  for (final action in ['cancel', 'dispose', 'supersede']) {
    test(
      '$action while native pick is pending preserves late receipt',
      () async {
        final h = Harness();
        h.picker.pickGate = Completer<void>();
        final operation = h.import();
        await tick();
        switch (action) {
          case 'cancel':
            h.controller.cancelCandidate();
          case 'dispose':
            h.container.invalidate(roomMaskProvider);
          case 'supersede':
            await h.import();
        }
        h.picker.pickGate!.complete();
        await operation;
        expect(h.pending!.photo, same(h.picker.next));
        expect(h.store.clears, 0);
        expect(h.state.candidate, isNull);
        expect(h.segmenter.requests, isEmpty);
      },
    );
  }

  test(
    'disposed controller discards late inference without starting replacement work',
    () async {
      final h = Harness();
      final operation = h.import();
      await tick();
      h.container.invalidate(roomMaskProvider);
      h.segmenter.requests.single.succeed(masks(4));
      await operation;
      expect(h.state.stage, RoomMaskStage.empty);
      expect(h.state.draft, isNull);
      expect(h.segmenter.requests.length, 1);
    },
  );

  test(
    'layer colors change only color revision and no-op is ignored',
    () async {
      final h = Harness();
      final original = await h.ready();
      final sage = RgbColor.fromHex('#A7B5A0');

      expect(original.colors, const RoomLayerColors());
      expect(original.colorRevision, 0);
      expect(h.controller.setLayerColor(RoomLayer.wall, sage), isTrue);
      expect(h.state.draft!.colors.wall, sage);
      expect(h.state.draft!.colorRevision, 1);
      expect(h.state.draft!.maskRevision, 0);
      expect(h.controller.setLayerColor(RoomLayer.wall, sage), isFalse);
      expect(h.state.draft!.colorRevision, 1);
      expect(h.controller.setLayerColor(RoomLayer.wall, null), isTrue);
      expect(h.state.draft!.colors.hasAny, isFalse);
      expect(h.state.draft!.colorRevision, 2);
      expect(h.state.draft!.maskRevision, 0);
    },
  );

  test('manual mask actions preserve all four layer colors', () async {
    final h = Harness();
    await h.ready(3);
    final expected = <RoomLayer, RgbColor>{
      RoomLayer.wall: RgbColor.fromHex('#A7B5A0'),
      RoomLayer.ceiling: RgbColor.fromHex('#F4F1EA'),
      RoomLayer.floor: RgbColor.fromHex('#D9BC9E'),
      RoomLayer.furniture: RgbColor.fromHex('#C5B7D0'),
    };
    for (final entry in expected.entries) {
      expect(h.controller.setLayerColor(entry.key, entry.value), isTrue);
    }

    void expectColors() {
      final draft = h.state.draft!;
      expect(draft.colorRevision, 4);
      for (final entry in expected.entries) {
        expect(draft.colors.colorFor(entry.key), entry.value);
      }
    }

    h.controller.setTool(RoomMaskTool.add);
    expect(await h.paint(), isTrue);
    expectColors();
    final added = h.state.draft!;
    expect(
      await h.controller.undo(
        photoId: added.photoId,
        maskRevision: added.maskRevision,
      ),
      isTrue,
    );
    expectColors();
    h.controller.setLayer(RoomLayer.floor);
    h.controller.setTool(RoomMaskTool.erase);
    expect(
      await h.paint(value: stroke(layer: RoomLayer.floor, erase: true)),
      isTrue,
    );
    expectColors();
    final erased = h.state.draft!;
    expect(
      h.controller.restoreAiMasks(
        photoId: erased.photoId,
        maskRevision: erased.maskRevision,
      ),
      isTrue,
    );
    expectColors();
  });

  test('successful photo replacement resets all layer colors', () async {
    final h = Harness();
    await h.ready();
    h.controller.setLayerColor(RoomLayer.floor, RgbColor(12, 34, 56));
    h.picker.next = photo(2);

    final replacement = h.import();
    await tick();
    h.segmenter.requests.last.succeed(masks(RoomLayer.floor.label));
    await replacement;

    expect(h.state.draft!.colors, const RoomLayerColors());
    expect(h.state.draft!.colorRevision, 0);
  });

  test(
    'draft rejects mismatched dimensions and negative revision or dirty count',
    () {
      final p = photo();
      RoomMaskDraft create({
        MaskBitmap? ai,
        int revision = 0,
        int colorRevision = 0,
        int dirty = 0,
      }) => RoomMaskDraft(
        photoId: 'p',
        photo: p,
        aiMasks: ai ?? masks(),
        masks: masks(),
        history: MaskEditHistory.empty(width: 10, height: 10),
        maskRevision: revision,
        colorRevision: colorRevision,
        changedFromAiCount: dirty,
      );
      expect(
        () => create(ai: MaskBitmap(width: 1, height: 1, labels: Uint8List(1))),
        throwsArgumentError,
      );
      expect(() => create(revision: -1), throwsArgumentError);
      expect(() => create(colorRevision: -1), throwsArgumentError);
      expect(() => create(dirty: -1), throwsArgumentError);
    },
  );
}
