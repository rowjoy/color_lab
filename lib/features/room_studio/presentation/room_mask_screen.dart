import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../picker/application/photo_acquisition_controller.dart';
import '../../picker/domain/photo_acquisition.dart';
import '../../picker/presentation/acquisition_recovery_scope.dart';
import '../../mixer/presentation/mixer_color_picker.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/room_image_export_service.dart';
import '../application/room_mask_controller.dart';
import '../application/room_model_download_providers.dart';
import '../application/room_recolor_provider.dart';
import '../domain/room_layer.dart';
import '../domain/room_mask_state.dart';
import '../recolor/room_recolor_frame.dart';
import 'room_layer_color_controls.dart';
import 'room_mask_dialogs.dart';
import 'room_mask_fullscreen_editor.dart';
import 'room_mask_viewport.dart';
import 'room_model_download_status.dart';
import '../models/room_model_store.dart';
import 'room_recolor_viewport.dart';

class RoomMaskScreen extends ConsumerStatefulWidget {
  const RoomMaskScreen({super.key});

  @override
  ConsumerState<RoomMaskScreen> createState() => _RoomMaskScreenState();
}

class _RoomMaskScreenState extends ConsumerState<RoomMaskScreen> {
  int _restoreView = 0;
  bool _confirming = false;
  Object? _importOperation;
  bool _showAfter = true;
  bool _sharing = false;
  (String, int)? _refreshedMasks;
  RoomRecolorFrame? _lastFrame;

  @override
  void initState() {
    super.initState();
    ref.listenManual(roomRecolorPreviewProvider, (_, next) {
      final frame = next.value;
      final current = ref.read(roomMaskProvider).draft;
      if (mounted &&
          frame != null &&
          current != null &&
          frame.key.photoId == current.photoId &&
          frame.key.maskRevision == current.maskRevision &&
          frame.key.colorRevision == current.colorRevision &&
          !identical(_lastFrame, frame)) {
        setState(() => _lastFrame = frame);
      }
    }, fireImmediately: true);
  }

  bool get _active =>
      mounted &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      (ModalRoute.of(context)?.isCurrent ?? false) &&
      GoRouter.of(context).state.uri.path == '/room/masks';

  bool _sameDraft(RoomMaskDraft? captured) {
    final current = ref.read(roomMaskProvider).draft;
    return current?.photoId == captured?.photoId &&
        current?.maskRevision == captured?.maskRevision;
  }

  Future<void> _import({PhotoSource? source, String? requestId}) async {
    if (!_active || _confirming || _importOperation != null) return;
    final operation = Object();
    setState(() => _importOperation = operation);
    try {
      final captured = ref.read(roomMaskProvider).draft;
      if (captured != null) {
        setState(() => _confirming = true);
        final accepted = await confirmReplaceRoomPhoto(context);
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

  void _cancelCandidate() {
    // Logical cancellation releases the action before physical inference ends.
    // The old future's finally cannot clear a subsequent action's guard.
    setState(() => _importOperation = null);
    ref.read(roomModelStoreProvider).cancel();
    ref.read(roomMaskProvider.notifier).cancelCandidate();
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
      context.go('/room');
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

  Future<void> _share(BuildContext anchor) async {
    if (_sharing || !_active) return;
    final draft = ref.read(roomMaskProvider).draft;
    final preview = ref.read(roomRecolorPreviewProvider);
    final frame = preview.value;
    if (draft == null ||
        preview.isLoading ||
        preview.hasError ||
        frame == null ||
        frame.key !=
            RoomRecolorKey(
              photoId: draft.photoId,
              maskRevision: draft.maskRevision,
              colorRevision: draft.colorRevision,
            )) {
      return;
    }
    final box = anchor.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return;
    setState(() => _sharing = true);
    try {
      await ref
          .read(roomImageExportServiceProvider)
          .sharePng(
            pngBytes: frame.pngBytes,
            photoId: draft.photoId,
            origin: box.localToGlobal(Offset.zero) & box.size,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Could not share the PNG. Try again.'),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roomMaskProvider);
    final modelProgress =
        ref.watch(roomModelDownloadProgressProvider).value ??
        ref.read(roomModelStoreProvider).progress;
    final controller = ref.read(roomMaskProvider.notifier);
    final acquisition = ref.watch(photoAcquisitionProvider);
    final receipt = acquisition.pendingReceipt;
    final draft = state.draft;
    final preview = ref.watch(roomRecolorPreviewProvider);
    final recolorKey = draft == null
        ? null
        : RoomRecolorKey(
            photoId: draft.photoId,
            maskRevision: draft.maskRevision,
            colorRevision: draft.colorRevision,
          );
    final previewFrame = preview.value;
    final currentFrame = recolorKey != null && previewFrame?.key == recolorKey
        ? previewFrame
        : null;
    final displayFrame =
        currentFrame ??
        (_lastFrame?.key.photoId == draft?.photoId ? _lastFrame : null);
    final canShare =
        currentFrame != null &&
        !preview.isLoading &&
        !preview.hasError &&
        state.stage == RoomMaskStage.ready &&
        !state.editBusy &&
        !_sharing;
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
          const Text(
            'AI models are verified during app startup. After setup, room analysis works offline.',
          ),
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
          if (acquisition.phase == AcquisitionPhase.storageError)
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
                  if (_active) controller.analyzeCandidate();
                },
              ),
            SecondaryButton(
              label: analyzing && modelProgress.busy
                  ? 'Cancel download'
                  : analyzing
                  ? 'Cancel analysis'
                  : 'Cancel import',
              onPressed: _cancelCandidate,
            ),
          ],
          if (state.stage == RoomMaskStage.error) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                modelProgress.stage == RoomModelDownloadStage.failed
                    ? 'AI models could not be downloaded or verified. Check your connection and free space, then retry. Your photo is safe.'
                    : 'Room analysis could not finish. Try again or choose another photo.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.candidate != null)
              PrimaryButton(
                label: 'Retry analysis',
                onPressed: () {
                  if (_active) controller.retryAnalysis();
                },
              ),
            SecondaryButton(
              label: 'Choose another photo',
              onPressed: canImport
                  ? () => _import(source: PhotoSource.gallery)
                  : null,
            ),
            if (draft != null)
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
                  Text(
                    'Photo preview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  RoomRecolorViewport(
                    sourcePngBytes: draft.photo.previewBytes,
                    width: draft.photo.width,
                    height: draft.photo.height,
                    currentKey: recolorKey!,
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
                      child: const Text(
                        'Preview could not update. Your photo and masks are safe.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SecondaryButton(
                      key: const ValueKey('room-recolor-retry'),
                      label: 'Retry preview',
                      onPressed: () =>
                          ref.invalidate(roomRecolorPreviewProvider),
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
                  Builder(
                    builder: (anchor) => PrimaryButton(
                      key: const ValueKey('room-recolor-share'),
                      label: 'Share PNG',
                      icon: Icons.ios_share_rounded,
                      isLoading: _sharing,
                      onPressed: canShare ? () => _share(anchor) : null,
                    ),
                  ),
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
                  if (RoomLayer.values.every(
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
