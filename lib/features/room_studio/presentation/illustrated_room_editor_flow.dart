import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/color/color_models.dart';
import '../../../l10n/l10n.dart';
import '../../mixer/presentation/mixer_color_picker.dart';
import '../application/illustrated_room_controller.dart';
import '../application/illustrated_room_draft_store.dart';
import '../domain/illustrated_room.dart';
import '../domain/illustrated_room_draft.dart';
import 'illustrated_room_surface_picker.dart';
import 'illustrated_room_history_controls.dart';
import 'illustrated_room_palette_sheet.dart';
import 'illustrated_room_svg.dart';
import 'saved_room_designs_sheet.dart';
import 'illustrated_room_navigation.dart';
import 'illustrated_room_compare_controls.dart';
import 'illustrated_room_export_controls.dart';

enum IllustratedRoomWidthClass {
  compact,
  medium,
  expanded,
  large;

  static IllustratedRoomWidthClass forWidth(double width) => width < 600
      ? compact
      : width < 840
      ? medium
      : width < 1200
      ? expanded
      : large;
}

Future<void> showIllustratedRoomEditorFlow(
  BuildContext context, {
  required String templateId,
  String? selectedRegionId,
  required ValueChanged<String> onRegionSelected,
}) => showDialog<void>(
  context: context,
  useSafeArea: true,
  builder: (context) => Dialog(
    insetPadding: const EdgeInsets.all(8),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: switch (IllustratedRoomWidthClass.forWidth(
          MediaQuery.sizeOf(context).width,
        )) {
          IllustratedRoomWidthClass.compact => 600,
          IllustratedRoomWidthClass.medium => 640,
          IllustratedRoomWidthClass.expanded => 760,
          IllustratedRoomWidthClass.large => 880,
        },
      ),
      child: _EditorFlow(
        templateId: templateId,
        selectedRegionId: selectedRegionId,
        onRegionSelected: onRegionSelected,
      ),
    ),
  ),
);

class _EditorFlow extends ConsumerStatefulWidget {
  const _EditorFlow({
    required this.templateId,
    required this.selectedRegionId,
    required this.onRegionSelected,
  });
  final String templateId;
  final String? selectedRegionId;
  final ValueChanged<String> onRegionSelected;
  @override
  ConsumerState<_EditorFlow> createState() => _EditorFlowState();
}

class _EditorFlowState extends ConsumerState<_EditorFlow> {
  String? _selected;
  String? _previewLook;
  @override
  void initState() {
    super.initState();
    _selected = widget.selectedRegionId;
  }

  IllustratedRoomDraft get draft =>
      ref.read(illustratedRoomProvider).draftFor(widget.templateId)!;
  bool get _active =>
      ref.read(illustratedRoomProvider).activeTemplateId == widget.templateId;
  void _applyColor(RgbColor color, String target) {
    if (!mounted || !_active) return;
    final controller = ref.read(illustratedRoomProvider.notifier);
    if (draft.template.regionAssetPath != null) {
      controller.setRegionColor(target, color);
    } else {
      controller.setGroupColor(target, color);
    }
  }

  Future<void> _chooseColor({required bool palettes}) async {
    final target = _selected;
    if (target == null) return;
    final expected = draft;
    final selection = palettes
        ? showIllustratedRoomPalettes(context)
        : showMixerColorPicker(context);
    final color = await selection;
    // A replacement/route change while the picker is open must not edit a
    // different saved design or template. Capture the original target as well.
    if (color != null && mounted && _active && identical(draft, expected)) {
      _applyColor(color, target);
    }
  }

  Future<void> _save({bool copy = false}) async {
    final current = draft;
    await showSaveRoomDesignDialog(
      context,
      initialName:
          current.savedName ??
          defaultRoomDesignName(
            current.template,
            ref.read(roomDesignClockProvider)(),
          ),
      templateId: widget.templateId,
      asCopy: copy,
    );
  }

  Widget _button(String key, String label, VoidCallback? action) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: OutlinedButton(
      key: ValueKey(key),
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: action,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final current = ref
        .watch(illustratedRoomProvider)
        .draftFor(widget.templateId)!;
    final controller = ref.read(illustratedRoomProvider.notifier);
    final l10n = context.l10n;
    final preview = _previewLook == null
        ? null
        : current.applyPalette(_previewLook!);
    return SingleChildScrollView(
      key: const ValueKey('room-flow-scroll'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _button(
            'room-flow-close',
            l10n.roomClose,
            () => Navigator.of(context).pop(),
          ),
          Text(
            l10n.roomEditFlow,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          IllustratedRoomDraftStatus(templateId: widget.templateId),
          IllustratedRoomHistoryControls(
            onUndo: current.history.canUndo ? controller.undo : null,
            onRedo: current.history.canRedo ? controller.redo : null,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.roomChooseLook,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final look in current.template.palettes)
            _button(
              'room-flow-look-${look.id}',
              look.localizedName(l10n),
              () => setState(() => _previewLook = look.id),
            ),
          if (preview != null) ...[
            Text(l10n.roomLookPreview),
            SizedBox(height: 160, child: IllustratedRoomSvg(draft: preview)),
            _button('room-apply-complete-look', l10n.roomApplyCompleteLook, () {
              if (!_active) return;
              controller.applyCompleteLook(preview.colors!);
              setState(() => _previewLook = null);
            }),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.roomChangeSurface,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_selected != null)
            Text(l10n.roomSelectedSurface(roomRegionName(l10n, _selected!))),
          IllustratedRoomSurfacePicker(
            draft: current,
            selectedRegionId: _selected,
            onSelected: (id) {
              setState(() => _selected = id);
              widget.onRegionSelected(id);
            },
          ),
          if (_selected != null) ...[
            IllustratedRoomPaletteSheet(
              colors: [
                for (final surface in IllustratedRoomSurface.values)
                  current.template.defaultPalette.colors.colorFor(surface),
              ],
              onSelected: (color) => _applyColor(color, _selected!),
            ),
            _button(
              'room-my-palettes',
              l10n.roomMyPalettes,
              () => _chooseColor(palettes: true),
            ),
            _button(
              'room-region-custom',
              l10n.roomCustomColor,
              () => _chooseColor(palettes: false),
            ),
          ],
          const SizedBox(height: 16),
          _button(
            'room-flow-save',
            current.savedDesignId == null ? l10n.roomSave : l10n.roomUpdate,
            current.canSave ? () => _save() : null,
          ),
          if (current.assignments != null)
            _button(
              'room-save-copy',
              l10n.roomSaveCopy,
              () => _save(copy: true),
            ),
          _button(
            'room-my-designs',
            l10n.roomMyDesigns,
            () => showSavedRoomDesigns(
              context,
              onOpen: (design) async {
                final opened = await openIllustratedSavedDesign(
                  context,
                  design,
                );
                return opened;
              },
            ),
          ),
          const SizedBox(height: 16),
          IllustratedRoomCompareControls(templateId: widget.templateId),
          if (current.comparison.isActive)
            SizedBox(height: 180, child: IllustratedRoomSvg(draft: current)),
          const SizedBox(height: 16),
          IllustratedRoomExportControls(templateId: widget.templateId),
        ],
      ),
    );
  }
}

class IllustratedRoomDraftStatus extends ConsumerWidget {
  const IllustratedRoomDraftStatus({super.key, required this.templateId});
  final String templateId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(illustratedRoomDraftStoreProvider)
      .when(
        loading: () => Text(context.l10n.roomLoading),
        error: (_, _) => _status(
          context,
          IllustratedRoomDraftSaveStatus.failed,
          () => unawaited(
            ref
                .read(illustratedRoomDraftLoadRetryProvider)()
                .catchError((Object _) {}),
          ),
        ),
        data: (store) => ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            if (store.recoveryUnavailableFor(templateId)) {
              return Semantics(
                liveRegion: true,
                child: Text(context.l10n.roomDraftUnavailable),
              );
            }
            final status = store.statusFor(templateId);
            if (status == null) return const SizedBox.shrink();
            return _status(
              context,
              status,
              () =>
                  unawaited(store.retry(templateId).catchError((Object _) {})),
            );
          },
        ),
      );
  Widget _status(
    BuildContext context,
    IllustratedRoomDraftSaveStatus status,
    VoidCallback retry,
  ) => Semantics(
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(switch (status) {
          IllustratedRoomDraftSaveStatus.saved => context.l10n.roomSaved,
          IllustratedRoomDraftSaveStatus.saving => context.l10n.roomSaving,
          IllustratedRoomDraftSaveStatus.failed => context.l10n.roomDraftFailed,
        }),
        if (status == IllustratedRoomDraftSaveStatus.failed)
          TextButton(
            key: const ValueKey('room-draft-retry'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: retry,
            child: Text(context.l10n.roomRetry),
          ),
      ],
    ),
  );
}
