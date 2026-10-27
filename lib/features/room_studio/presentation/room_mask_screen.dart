import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/config/app_identity.dart';
import '../../picker/application/photo_picker_service.dart';
import '../application/room_export_controller.dart';
import '../application/room_gallery_writer.dart';
import '../../../l10n/l10n.dart';
import '../../../core/widgets/widgets.dart';
import '../../picker/application/photo_acquisition_controller.dart';
import '../../picker/domain/photo_acquisition.dart';
import '../../picker/presentation/acquisition_recovery_scope.dart';
import '../../mixer/presentation/mixer_color_picker.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/room_image_export_service.dart';
import '../application/room_mask_controller.dart';
import '../application/room_project_session_controller.dart';
import '../application/room_model_download_providers.dart';
import '../application/room_model_setup_controller.dart';
import '../application/room_recolor_provider.dart';
import '../domain/room_layer.dart';
import '../domain/room_mask_state.dart';
import 'room_layer_color_controls.dart';
import 'room_mask_dialogs.dart';
import 'room_mask_fullscreen_editor.dart';
import 'room_mask_viewport.dart';
import 'room_model_download_status.dart';
import 'room_recolor_viewport.dart';
import 'room_project_save_status.dart';
import 'room_variant_controls.dart';

class RoomMaskScreen extends ConsumerStatefulWidget {
  const RoomMaskScreen({
    super.key,
    this.projectId,
    this.compareRequested = false,
  });
  final String? projectId;
  final bool compareRequested;

  @override
  ConsumerState<RoomMaskScreen> createState() => _RoomMaskScreenState();
}

class _RoomMaskScreenState extends ConsumerState<RoomMaskScreen>
    with WidgetsBindingObserver {
  int _restoreView = 0;
  bool _confirming = false;
  Object? _importOperation;
  bool _showAfter = true;
  late final RoomExportController _exports;
  PhotoSource _lastSource = PhotoSource.gallery;
  bool _recoveryObserved = false;
  Object? _recoveryOperation, _recoveryLifetime;
  RoomMaskState? _recoveryMask;
  AcquisitionRecoveryFailure? _recoveredFailure;
  (String, int)? _refreshedMasks;
  late final RoomRecolorCoordinator _previews;
  Object? _previewOwner;
  bool _previewRouteVisible = false;

  @override
  void initState() {
    super.initState();
    _previews = ref.read(roomRecolorCoordinatorProvider.notifier);
    _exports = RoomExportController(
      service: ref.read(roomImageExportServiceProvider),
      readSource: _readExportSource,
    )..addListener(_exportChanged);
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(
      photoAcquisitionProvider,
      (_, next) => _receiveRecoveryFailure(next),
    );
    ref.listenManual(roomProjectSessionProvider, (_, next) {
      _exports.reconcile();
      if (!identical(_recoveryLifetime, next?.lifetime)) {
        // Revoke permanently even if a later close returns to a null session.
        _recoveryOperation = null;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPreviewVisibility();
  }

  void _exportChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _recoveryOperation = null;
      _exports.revoke(beforeHandoffOnly: true);
    } else {
      _observeRecoveryFailure();
    }
  }

  void _syncPreviewVisibility() {
    final visible = _routeVisible;
    final becameVisible = visible && !_previewRouteVisible;
    _previewRouteVisible = visible;
    if (!visible) {
      _recoveryOperation = null;
      _exports.revoke();
    } else {
      _observeRecoveryFailure();
    }
    final owner = _previewOwner;
    if (visible && (becameVisible || owner == null || !_previews.owns(owner))) {
      // A retained editor may return while the covering editor is still
      // animating out. Claim now; that old owner's later dispose stays stale.
      _previewOwner = _previews.attachOwner(isVisible: () => _routeVisible);
    } else if (owner != null) {
      _previews.setOwnerVisible(owner, visible);
    }
  }

  void _observeRecoveryFailure() {
    if (_recoveryObserved || !_active) return;
    _recoveryObserved = true;
    if (ref
        .read(photoAcquisitionProvider.notifier)
        .reserveRecoveryFailure(AcquisitionDestination.room)) {
      _recoveryOperation = Object();
      _recoveryLifetime = ref.read(roomProjectSessionProvider)?.lifetime;
      _recoveryMask = ref.read(roomMaskProvider);
      _receiveRecoveryFailure(ref.read(photoAcquisitionProvider));
    }
  }

  bool get _recoveryCurrent =>
      mounted &&
      _recoveryOperation != null &&
      _active &&
      identical(
        _recoveryLifetime,
        ref.read(roomProjectSessionProvider)?.lifetime,
      ) &&
      identical(_recoveryMask, ref.read(roomMaskProvider));

  void _receiveRecoveryFailure(AcquisitionState state) {
    final failure = state.recoveryFailure;
    if (failure?.intent.destination != AcquisitionDestination.room ||
        !_recoveryCurrent) {
      return;
    }
    final operation = _recoveryOperation;
    // Initial recovery can already be ready during didChangeDependencies.
    // Revalidate the original owner after the frame before updating its UI.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_recoveryCurrent ||
          !identical(operation, _recoveryOperation) ||
          !identical(
            failure,
            ref.read(photoAcquisitionProvider).recoveryFailure,
          )) {
        return;
      }
      setState(() {
        _recoveredFailure = failure;
        _lastSource = failure!.intent.source;
      });
    });
    // Resuming from inactive need not schedule a frame on its own.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _exports.removeListener(_exportChanged);
    _exports.dispose();
    final owner = _previewOwner;
    if (owner != null) _previews.detachOwner(owner);
    super.dispose();
  }

  // The coordinator tracks lifecycle independently. An inactive dependency
  // rebuild must not mark a current route hidden and prevent its later resume.
  bool get _routeVisible =>
      mounted &&
      (ModalRoute.of(context)?.isCurrent ?? false) &&
      GoRouter.of(context).state.uri.path == '/room/masks';

  bool get _active =>
      _routeVisible &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  bool _sameDraft(RoomMaskDraft? captured) {
    final current = ref.read(roomMaskProvider).draft;
    return current?.photoId == captured?.photoId &&
        current?.maskRevision == captured?.maskRevision;
  }

  bool _analysisReady() {
    // Stored masks/colors need no models. A new analysis still needs the
    // explicit setup permission before picker/inference can start a download.
    if (widget.projectId == null || ref.read(roomModelSetupProvider).canEnter) {
      return true;
    }
    context.push(
      Uri(
        path: '/room/masks',
        queryParameters: {
          'setupProject': widget.projectId!,
          if (widget.compareRequested) 'compare': '1',
        },
      ).toString(),
    );
    return false;
  }

  Future<void> _import({PhotoSource? source, String? requestId}) async {
    if (!_active || _confirming || _importOperation != null) return;
    if (!_analysisReady()) return;
    if (source != null) _lastSource = source;
    _recoveryOperation = null;
    _exports.revoke();
    final operation = Object();
    setState(() => _importOperation = operation);
    try {
      final captured = ref.read(roomMaskProvider).draft;
      if (captured != null) {
        setState(() => _confirming = true);
        final accepted = await confirmReplaceRoomPhoto(
          context,
          hasUnsavedChanges:
              ref.read(roomProjectSessionProvider)?.hasUnsavedChanges ?? false,
        );
        if (!mounted) return;
        setState(() => _confirming = false);
        if (!accepted || !_active || !_sameDraft(captured)) return;
      }
      final controller = ref.read(roomMaskProvider.notifier);
      if (requestId != null) {
        await controller.continueImport(requestId, isActive: () => _active);
      } else {
        await controller.importPhoto(source!, isActive: () => _active);
      }
    } finally {
      if (mounted && identical(_importOperation, operation)) {
        setState(() => _importOperation = null);
      }
    }
  }

  void _cancelCandidate({bool retainPhoto = false}) {
    // Logical cancellation releases the action before physical inference ends.
    // The old future's finally cannot clear a subsequent action's guard.
    setState(() => _importOperation = null);
    ref.read(roomModelStoreProvider).cancel();
    final controller = ref.read(roomMaskProvider.notifier);
    if (retainPhoto) {
      controller.cancelAnalysis();
    } else {
      controller.cancelCandidate();
    }
  }

  Future<void> _restore(RoomMaskDraft draft) async {
    if (!_active || _confirming) return;
    setState(() => _confirming = true);
    final accepted = await confirmRestoreAiMasks(context);
    if (!mounted) return;
    setState(() => _confirming = false);
    if (!accepted || !_active || !_sameDraft(draft)) return;
    if (ref
        .read(roomMaskProvider.notifier)
        .restoreAiMasks(
          photoId: draft.photoId,
          maskRevision: draft.maskRevision,
        )) {
      setState(() => _restoreView++);
    }
  }

  Future<void> _refreshMasks(RoomMaskDraft draft) async {
    if (!_active || _confirming || !_sameDraft(draft)) return;
    if (!_analysisReady()) return;
    setState(() => _refreshedMasks = null);
    final accepted = await ref
        .read(roomMaskProvider.notifier)
        .reanalyzeCurrentPhoto();
    if (!mounted || !accepted) return;
    final current = ref.read(roomMaskProvider).draft;
    if (current?.photoId == draft.photoId &&
        current!.maskRevision == draft.maskRevision + 1) {
      setState(() => _refreshedMasks = (current.photoId, current.maskRevision));
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(widget.projectId == null ? '/room' : '/rooms/projects');
    }
  }

  Future<void> _editFullscreen(RoomMaskDraft draft) async {
    final state = ref.read(roomMaskProvider);
    if (!_active ||
        _confirming ||
        state.stage != RoomMaskStage.ready ||
        state.editBusy) {
      return;
    }
    final controller = ref.read(roomMaskProvider.notifier);
    controller.setShowOverlay(true);
    if (ref.read(roomMaskProvider).tool == RoomMaskTool.move) {
      controller.setTool(RoomMaskTool.add);
    }
    await showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (_) => Dialog.fullscreen(
        child: RoomMaskFullscreenEditor(photoId: draft.photoId),
      ),
    );
  }

  Future<void> _chooseColor(RoomMaskDraft draft, RoomLayer layer) async {
    final color = await showMixerColorPicker(
      context,
      initialColor: draft.colors.colorFor(layer),
    );
    if (!mounted || color == null || !_active) return;
    final current = ref.read(roomMaskProvider).draft;
    if (current?.photoId != draft.photoId) return;
    ref.read(roomMaskProvider.notifier).setLayerColor(layer, color);
  }

  RoomExportSource? _readExportSource() {
    if (!mounted) return null;
    final owner = _previewOwner;
    final session = ref.read(roomProjectSessionProvider);
    if (owner == null || session == null) return null;
    final state = ref.read(roomMaskProvider);
    final preview = ref.read(roomRecolorPreviewProvider);
    return RoomExportSource(
      session: session,
      owner: owner,
      eligible:
          _active &&
          _previews.owns(owner) &&
          !_confirming &&
          _importOperation == null,
      ready:
          state.stage == RoomMaskStage.ready &&
          !state.editBusy &&
          !preview.isLoading &&
          !preview.hasError &&
          state.draft?.photoId == session.visible.photoId,
      frame: preview.value,
    );
  }

  Future<void> _export(RoomExportAction action, BuildContext anchor) async {
    final box = anchor.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return;
    await _exports.export(
      action,
      origin: box.localToGlobal(Offset.zero) & box.size,
      title: context.l10n.roomExportTitle(AppIdentity.displayName),
    );
  }

  Future<void> _recover(
    RoomFailureRecovery recovery, {
    AcquisitionRecoveryFailure? recoveredFailure,
  }) async {
    if (!_active) return;
    if (recoveredFailure != null &&
        (!_recoveryCurrent ||
            !identical(
              recoveredFailure,
              ref.read(photoAcquisitionProvider).recoveryFailure,
            ))) {
      return;
    }
    switch (recovery) {
      case RoomFailureRecovery.settings:
        await ref.read(photoPickerServiceProvider).openSettings();
      case RoomFailureRecovery.storage:
        final acquisition = ref.read(photoAcquisitionProvider);
        if (acquisition.phase == AcquisitionPhase.storageError) {
          await ref.read(photoAcquisitionProvider.notifier).retryStorage();
        } else {
          await ref.read(roomProjectSessionProvider.notifier).retrySave();
        }
      case RoomFailureRecovery.model:
        await ref.read(roomModelSetupProvider.notifier).check();
        if (mounted && _active && _analysisReady()) {
          await ref.read(roomMaskProvider.notifier).retryAnalysis();
        }
      case RoomFailureRecovery.analysis:
        if (_analysisReady()) {
          await ref.read(roomMaskProvider.notifier).retryAnalysis();
        }
      case RoomFailureRecovery.picker:
        await _import(source: _lastSource);
      case RoomFailureRecovery.gallery:
      case RoomFailureRecovery.smaller:
      case RoomFailureRecovery.supported:
        await _import(source: PhotoSource.gallery);
    }
  }

  Widget _exportPanel(RoomProjectSession session, bool enabled) {
    final l10n = context.l10n;
    final failure = _exports.failure, notice = _exports.notice;
    final message = switch (failure) {
      RoomExportFailure.accessDenied => l10n.roomExportAccess,
      RoomExportFailure.capacity => l10n.roomExportCapacity,
      RoomExportFailure.save => l10n.roomExportSaveFailed,
      RoomExportFailure.share => l10n.roomExportShareFailed,
      RoomExportFailure.invalidPreview => l10n.roomExportInvalid,
      RoomExportFailure.interrupted => l10n.roomExportInterrupted,
      null => switch (notice) {
        RoomExportNotice.saved => l10n.roomExportSaved,
        RoomExportNotice.shared => l10n.roomExportShared,
        RoomExportNotice.dismissed => l10n.roomExportDismissed,
        RoomExportNotice.unavailable => l10n.roomExportUnavailable,
        null => null,
      },
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.roomExportSelected(session.variantSet.active.name)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.roomExportResolution(
            session.visible.photo.width,
            session.visible.photo.height,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.roomExportEffects),
        if (session.hasUnsavedChanges) Text(l10n.roomExportUnsaved),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.roomExportLimits,
          key: const ValueKey('room-export-disclosure'),
        ),
        const SizedBox(height: AppSpacing.md),
        Builder(
          builder: (anchor) => PrimaryButton(
            key: const ValueKey('room-recolor-save'),
            label: l10n.roomExportSave,
            icon: Icons.save_alt_rounded,
            isLoading:
                _exports.busy && _exports.lastAction == RoomExportAction.save,
            onPressed: enabled
                ? () => _export(RoomExportAction.save, anchor)
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Builder(
          builder: (anchor) => PrimaryButton(
            key: const ValueKey('room-recolor-share'),
            label: l10n.roomExportShare,
            icon: Icons.ios_share_rounded,
            isLoading:
                _exports.busy && _exports.lastAction == RoomExportAction.share,
            onPressed: enabled
                ? () => _export(RoomExportAction.share, anchor)
                : null,
          ),
        ),
        if (_exports.busy)
          Semantics(liveRegion: true, child: Text(l10n.roomExportSaving)),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(message, key: const ValueKey('room-export-result')),
          ),
        ],
        if (failure != null)
          Builder(
            builder: (anchor) => SecondaryButton(
              key: const ValueKey('room-export-recovery'),
              label: failure == RoomExportFailure.accessDenied
                  ? l10n.roomOpenSettings
                  : failure == RoomExportFailure.invalidPreview
                  ? l10n.roomRetryPreview
                  : _exports.lastAction == RoomExportAction.save
                  ? l10n.roomRetrySaveImage
                  : l10n.roomRetryShare,
              onPressed: _exports.busy
                  ? null
                  : () => failure == RoomExportFailure.accessDenied
                        ? ref.read(roomGallerySettingsProvider)()
                        : failure == RoomExportFailure.invalidPreview
                        ? _previews.retry(discardActive: true)
                        : _export(
                            _exports.lastAction ?? RoomExportAction.share,
                            anchor,
                          ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roomMaskProvider);
    final session = ref.watch(roomProjectSessionProvider);
    final modelProgress =
        ref.watch(roomModelDownloadProgressProvider).value ??
        ref.read(roomModelStoreProvider).progress;
    final controller = ref.read(roomMaskProvider.notifier);
    final acquisition = ref.watch(photoAcquisitionProvider);
    final receipt = acquisition.pendingReceipt;
    final recoveredFailure =
        _recoveryCurrent &&
            identical(_recoveredFailure, acquisition.recoveryFailure)
        ? _recoveredFailure
        : null;
    final failure = state.stage == RoomMaskStage.error
        ? state.failure
        : recoveredFailure == null
        ? null
        : RoomMaskController.acquisitionFailure(recoveredFailure.kind);
    final draft = state.draft;
    final preview = ref.watch(roomRecolorPreviewProvider);
    final recolorKey = roomActiveRecolorKey(session);
    final comparing = roomBaselineRecolorKey(session) != null;
    final previewFrame = preview.value;
    final currentFrame = recolorKey != null && previewFrame?.key == recolorKey
        ? previewFrame
        : null;
    final displayFrame = ref.watch(roomRecolorDisplayProvider);
    final canShare =
        currentFrame != null &&
        !preview.isLoading &&
        !preview.hasError &&
        state.stage == RoomMaskStage.ready &&
        !state.editBusy &&
        !_exports.busy &&
        (_readExportSource()?.canCapture ?? false);
    final analyzing = state.stage == RoomMaskStage.analyzing;
    final refreshing = analyzing && state.candidate == null && draft != null;
    final acquiring = state.stage == RoomMaskStage.acquiring;
    final canImport =
        !_confirming &&
        _importOperation == null &&
        !analyzing &&
        !acquiring &&
        acquisition.phase == AcquisitionPhase.ready &&
        receipt == null &&
        !acquisition.hasUntrustedIntent;
    return AcquisitionRecoveryScope(
      child: StudioPage(
        name: 'RoomMasks',
        children: [
          Row(
            children: [
              IconCircleButton(
                icon: Icons.arrow_back_rounded,
                label: 'Back',
                onPressed: _back,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Room masks',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (widget.compareRequested && session != null) ...[
            const RoomVariantControls(),
            const SizedBox(height: AppSpacing.xl),
          ],
          PrimaryButton(
            key: const ValueKey('room-mask-gallery'),
            label: 'Choose room photo',
            icon: Icons.photo_outlined,
            onPressed: canImport
                ? () => _import(source: PhotoSource.gallery)
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            key: const ValueKey('room-mask-camera'),
            label: 'Take room photo',
            icon: Icons.camera_alt_outlined,
            onPressed: canImport
                ? () => _import(source: PhotoSource.camera)
                : null,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(context.l10n.roomModelsEditorOffline),
          const SizedBox(height: AppSpacing.md),
          if (receipt != null) ...[
            Text(
              receipt.destination == null
                  ? 'Choose where to continue this recovered photo.'
                  : 'A photo is waiting for you to continue.',
            ),
            if (receipt.destination != AcquisitionDestination.capture)
              SecondaryButton(
                key: const ValueKey('room-mask-continue-import'),
                label: 'Continue in Room',
                onPressed:
                    !_confirming &&
                        _importOperation == null &&
                        acquisition.phase == AcquisitionPhase.ready
                    ? () => _import(requestId: receipt.requestId)
                    : null,
              ),
            if (receipt.destination != AcquisitionDestination.room)
              SecondaryButton(
                label: 'Continue in Capture',
                onPressed: () => context.go('/capture'),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (acquisition.phase == AcquisitionPhase.storageError &&
              state.stage != RoomMaskStage.error)
            SecondaryButton(
              label: 'Retry photo request',
              onPressed: () =>
                  ref.read(photoAcquisitionProvider.notifier).retryStorage(),
            ),
          if (acquisition.hasUntrustedIntent && receipt == null)
            SecondaryButton(
              label: 'Review unfinished request in Capture',
              onPressed: () => context.go('/capture'),
            ),
          if (analyzing || acquiring) ...[
            if (state.candidate != null) ...[
              Image.memory(
                state.candidate!.photo.previewBytes,
                key: const ValueKey('room-mask-candidate-photo'),
                height: 300,
                width: double.infinity,
                fit: BoxFit.contain,
                semanticLabel: 'Original room photo awaiting analysis',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (analyzing && modelProgress.busy)
              RoomModelDownloadStatus(progress: modelProgress)
            else
              Semantics(
                liveRegion: true,
                child: Text(
                  analyzing
                      ? refreshing
                            ? 'Refreshing AI masks…'
                            : 'Finding room surfaces on this device…'
                      : state.candidate == null
                      ? 'Waiting for your room photo…'
                      : 'Your photo is ready to analyze.',
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            if (acquiring && state.candidate != null)
              PrimaryButton(
                key: const ValueKey('room-mask-continue-analysis'),
                label: 'Analyze this photo',
                onPressed: () {
                  if (_active && _analysisReady()) {
                    controller.analyzeCandidate();
                  }
                },
              ),
            if (acquiring && state.candidate != null)
              SecondaryButton(
                key: const ValueKey('room-mask-manual'),
                label: context.l10n.roomEditManually,
                onPressed: () {
                  if (_active) controller.createManualFallback();
                },
              ),
            SecondaryButton(
              label: analyzing && modelProgress.busy
                  ? 'Cancel download'
                  : analyzing
                  ? 'Cancel analysis'
                  : state.candidate != null
                  ? context.l10n.roomDiscardPhoto
                  : 'Cancel import',
              onPressed: () => _cancelCandidate(retainPhoto: analyzing),
            ),
          ],
          if (state.stage == RoomMaskStage.error ||
              recoveredFailure != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(roomFailureCopy(context.l10n, failure).$1),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              key: const ValueKey('room-photo-recovery'),
              label: roomFailureCopy(context.l10n, failure).$2,
              onPressed: () => _recover(
                roomFailureCopy(context.l10n, failure).$3,
                recoveredFailure: recoveredFailure,
              ),
            ),
            if (state.candidate != null) ...[
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                key: const ValueKey('room-mask-manual'),
                label: context.l10n.roomEditManually,
                onPressed: () {
                  if (_active) controller.createManualFallback();
                },
              ),
            ],
            if (draft != null && state.stage == RoomMaskStage.error)
              SecondaryButton(
                label: 'Return to previous masks',
                onPressed: _cancelCandidate,
              ),
          ],
          if (draft != null)
            Offstage(
              key: const ValueKey('room-mask-editor'),
              offstage: state.stage != RoomMaskStage.ready && !refreshing,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (session != null &&
                      session.visible.photoId == draft.photoId) ...[
                    RoomProjectSaveStatusView(
                      session: session,
                      onRetry: () {
                        if (_active) {
                          ref
                              .read(roomProjectSessionProvider.notifier)
                              .retrySave();
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (draft.manualMode) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(context.l10n.roomManualModeNotice),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Text(
                    'Photo preview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (!widget.compareRequested && session != null) ...[
                    const RoomVariantControls(),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (comparing)
                    RoomComparisonPreview(showOriginal: !_showAfter)
                  else if (recolorKey != null)
                    RoomRecolorViewport(
                      sourcePngBytes: draft.photo.previewBytes,
                      width: draft.photo.width,
                      height: draft.photo.height,
                      currentKey: recolorKey,
                      frame: displayFrame,
                      showAfter: _showAfter,
                      updating: preview.isLoading,
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      ChoiceChip(
                        key: const ValueKey('room-recolor-before'),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        label: const Text('Before'),
                        selected: !_showAfter,
                        onSelected: (_) => setState(() => _showAfter = false),
                      ),
                      ChoiceChip(
                        key: const ValueKey('room-recolor-after'),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        label: const Text('After'),
                        selected: _showAfter,
                        onSelected: (_) => setState(() => _showAfter = true),
                      ),
                    ],
                  ),
                  if (preview.hasError) ...[
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(context.l10n.roomPreviewFailed),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SecondaryButton(
                      key: const ValueKey('room-recolor-retry'),
                      label: context.l10n.roomRetryPreview,
                      onPressed: _previews.retry,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  RoomLayerColorControls(
                    colors: draft.colors,
                    selectedLayer: state.selectedLayer,
                    enabled: !state.editBusy && !_confirming,
                    onSelect: controller.setLayer,
                    onChoose: () => _chooseColor(draft, state.selectedLayer),
                    onReset: () =>
                        controller.setLayerColor(state.selectedLayer, null),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (session != null) _exportPanel(session, canShare),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Refine masks',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    key: const ValueKey('room-mask-refresh'),
                    label: refreshing
                        ? 'Refreshing AI masks…'
                        : draft.manualMode
                        ? context.l10n.roomRetryAnalysis
                        : 'Refresh AI masks',
                    icon: Icons.refresh_rounded,
                    isLoading: refreshing,
                    onPressed:
                        state.stage == RoomMaskStage.ready &&
                            !state.editBusy &&
                            !_confirming
                        ? () => _refreshMasks(draft)
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      state.stage == RoomMaskStage.ready &&
                              state.failure != null
                          ? 'Could not refresh AI masks. Your current masks and colors are safe. Try again.'
                          : _refreshedMasks ==
                                (draft.photoId, draft.maskRevision)
                          ? 'AI masks refreshed. Your corrections and colors were kept.'
                          : 'Refresh this photo’s AI masks while keeping your corrections and surface colors.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    key: const ValueKey('room-mask-fullscreen'),
                    label: 'Edit full screen',
                    icon: Icons.fullscreen_rounded,
                    onPressed: !state.editBusy && !_confirming
                        ? () => _editFullscreen(draft)
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Mask preview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  KeyedSubtree(
                    key: ValueKey((draft.photoId, _restoreView)),
                    child: SizedBox(
                      height: 300,
                      child: RoomMaskViewport(
                        key: const ValueKey('room-mask-viewport'),
                        photoId: draft.photoId,
                        maskRevision: draft.maskRevision,
                        photo: draft.photo,
                        masks: draft.masks,
                        layer: state.selectedLayer,
                        tool: state.tool,
                        brushFraction: state.brushFraction,
                        showOverlay: state.showOverlay,
                        editingEnabled: state.canEdit && !_confirming,
                        onStroke: (stroke) {
                          if (_active) {
                            controller.applyStroke(
                              photoId: draft.photoId,
                              maskRevision: draft.maskRevision,
                              stroke: stroke,
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (!draft.manualMode &&
                      RoomLayer.values.every(
                        (layer) => draft.aiMasks.count(layer) == 0,
                      ))
                    const Text(
                      'No supported surfaces were found. You can mark them manually.',
                    ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final layer in RoomLayer.values)
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppSpacing.huge,
                          ),
                          child: ChoiceChip(
                            key: ValueKey('room-mask-layer-${layer.name}'),
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                            label: Text(
                              '${_title(layer.name)} · ${draft.masks.count(layer) == 0 ? 'Not detected' : '${(100 * draft.masks.count(layer) / draft.masks.pixelCount).toStringAsFixed(1)}%'}',
                            ),
                            selected: state.selectedLayer == layer,
                            onSelected: (_) => controller.setLayer(layer),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final tool in RoomMaskTool.values)
                        ChoiceChip(
                          key: ValueKey('room-mask-tool-${tool.name}'),
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          label: Text(_title(tool.name)),
                          selected: state.tool == tool,
                          onSelected:
                              state.showOverlay || tool == RoomMaskTool.move
                              ? (_) => controller.setTool(tool)
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Brush size · ${(state.brushFraction * 100).round()}% of photo',
                  ),
                  Slider(
                    key: const ValueKey('room-mask-brush'),
                    value: state.brushFraction,
                    min: .01,
                    max: .20,
                    label: '${(state.brushFraction * 100).round()}%',
                    onChanged: state.canEdit
                        ? controller.setBrushFraction
                        : null,
                  ),
                  SwitchListTile.adaptive(
                    key: const ValueKey('room-mask-show-original'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show original'),
                    value: !state.showOverlay,
                    onChanged: (value) => controller.setShowOverlay(!value),
                  ),
                  SecondaryButton(
                    key: const ValueKey('room-mask-undo'),
                    label: 'Undo',
                    icon: Icons.undo_rounded,
                    onPressed:
                        state.canEdit && draft.history.canUndo && !_confirming
                        ? () => controller.undo(
                            photoId: draft.photoId,
                            maskRevision: draft.maskRevision,
                          )
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    key: const ValueKey('room-mask-restore'),
                    label: 'Restore AI masks',
                    onPressed: state.canEdit && !_confirming
                        ? () => _restore(draft)
                        : null,
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'Automatic masks may miss surfaces or include nearby objects. Refine any layer that needs correction.',
          ),
        ],
      ),
    );
  }

  static String _title(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}
