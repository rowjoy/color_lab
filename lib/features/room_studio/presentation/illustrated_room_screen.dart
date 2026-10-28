import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../l10n/l10n.dart';
import '../application/illustrated_room_editor_persistence.dart';
import 'illustrated_room_editor_flow.dart';
import 'illustrated_room_export_controls.dart';
import 'illustrated_room_surface_picker.dart';
import '../../mixer/presentation/mixer_color_picker.dart';
import '../application/illustrated_room_controller.dart';
import '../application/illustrated_room_export_controller.dart';
import '../application/illustrated_room_export_request.dart';
import '../application/room_designs_providers.dart';
import '../application/room_gallery_writer.dart';
import '../domain/illustrated_room.dart';
import '../domain/illustrated_room_draft.dart';
import '../domain/saved_room_design.dart';
import 'illustrated_room_controls.dart';
import 'illustrated_room_flyout.dart';
import 'illustrated_room_market_guide.dart';
import 'illustrated_room_navigation.dart';
import 'illustrated_room_svg.dart';
import 'saved_room_designs_sheet.dart';

class IllustratedRoomScreen extends ConsumerStatefulWidget {
  const IllustratedRoomScreen({super.key, required this.templateId});

  final String templateId;

  @override
  ConsumerState<IllustratedRoomScreen> createState() =>
      _IllustratedRoomScreenState();
}

enum _ExitChoice { keep, discard, cancel }

class _IllustratedRoomScreenState extends ConsumerState<IllustratedRoomScreen> {
  IllustratedRoomTool? _activeTool;
  IllustratedRoomViewMode _viewMode = IllustratedRoomViewMode.fillScreen;
  bool? _railVisibleOverride;
  bool? _lastResponsiveRailVisible;
  bool _focusPreview = false;
  bool? _railVisibleOverrideBeforeFocus;
  bool _checkingExit = false;
  bool _handlingExport = false;
  bool _previewUnavailable = false;
  int _previewAttempt = 0;
  String? _selectedRegionId;
  bool _flowOpen = false;

  IllustratedRoomTemplate? get _template =>
      IllustratedRoomCatalog.maybeById(widget.templateId);

  @override
  void initState() {
    super.initState();
    _scheduleTemplateActivation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final railVisible = _railVisibleFor(MediaQuery.sizeOf(context).width);
    if (_lastResponsiveRailVisible == true && !railVisible) {
      _activeTool = null;
    }
    _lastResponsiveRailVisible = railVisible;
  }

  @override
  void didUpdateWidget(IllustratedRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.templateId != widget.templateId) {
      _activeTool = null;
      _selectedRegionId = null;
      _railVisibleOverride = null;
      _focusPreview = false;
      _railVisibleOverrideBeforeFocus = null;
      _previewUnavailable = false;
      _previewAttempt = 0;
      _scheduleTemplateActivation();
    }
  }

  void _scheduleTemplateActivation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final template = _template;
      if (template == null) return;
      final session = ref.read(illustratedRoomProvider);
      if (session.activeTemplateId != template.id) {
        ref.read(illustratedRoomProvider.notifier).openTemplate(template);
      }
    });
  }

  Future<void> _saveDesign(IllustratedRoomDraft draft) async {
    final initialName =
        draft.savedName ??
        defaultRoomDesignName(
          draft.template,
          ref.read(roomDesignClockProvider)(),
        );
    await showSaveRoomDesignDialog(context, initialName: initialName);
  }

  Future<void> _saveToGallery(IllustratedRoomDraft draft) async {
    if (_handlingExport) return;
    _handlingExport = true;
    IllustratedRoomExportResult result;
    final request = IllustratedRoomExportRequest(
      ownsRequest: () =>
          mounted &&
          widget.templateId == draft.template.id &&
          (ModalRoute.of(context)?.isCurrent ?? true) &&
          ref.read(illustratedRoomProvider).activeTemplateId ==
              draft.template.id,
    );
    try {
      result = await ref
          .read(illustratedRoomExportProvider.notifier)
          .saveToGallery(draft, isCurrent: () => request.isCurrent);
    } catch (_) {
      result = const IllustratedRoomExportFailed(
        IllustratedRoomExportFailure.unexpected,
      );
    } finally {
      request.dispose();
      _handlingExport = false;
    }
    if (!mounted) return;
    _showExportResult(result);
  }

  void _showExportResult(IllustratedRoomExportResult result) {
    final message = illustratedRoomExportMessage(context.l10n, result);
    final accessDenied =
        result is IllustratedRoomExportFailed &&
        result.failure == IllustratedRoomExportFailure.accessDenied;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Semantics(
            container: true,
            liveRegion: true,
            label: message,
            excludeSemantics: true,
            child: Text(message),
          ),
          action: accessDenied
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: () => unawaited(_openGallerySettings()),
                )
              : null,
        ),
      );
  }

  Future<void> _openGallerySettings() async {
    try {
      await ref.read(roomGallerySettingsProvider)();
    } catch (_) {
      // Opening system Settings is best-effort; no private platform failure is
      // surfaced from the room editor.
    }
  }

  Future<void> _openSavedDesign(SavedRoomDesign design) async {
    final opened = await openIllustratedSavedDesign(context, design);
    if (opened && mounted) setState(() => _activeTool = null);
  }

  Future<void> _goBack() async {
    if (_checkingExit) return;
    if (_focusPreview) {
      _exitFocusPreview();
      return;
    }
    if (_activeTool != null) {
      setState(() => _activeTool = null);
      return;
    }
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600 && _railVisibleFor(width)) {
      _hideColorRail();
      return;
    }

    final draft = ref.read(illustratedRoomProvider).draftFor(widget.templateId);
    if (draft == null || !draft.isDirty) {
      ref.read(illustratedRoomProvider.notifier).closeEditor();
      _leaveEditor();
      return;
    }

    _checkingExit = true;
    final choice = await showDialog<_ExitChoice>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: const Text('Keep this draft?'),
        content: const Text(
          'You can keep these colors on this device, discard the changes, '
          'or stay in the editor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitChoice.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitChoice.discard),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitChoice.keep),
            child: const Text('Keep draft'),
          ),
        ],
      ),
    );
    _checkingExit = false;
    if (!mounted || choice == null || choice == _ExitChoice.cancel) return;
    if (choice == _ExitChoice.discard) {
      ref.read(illustratedRoomProvider.notifier).discardActiveChanges();
    }
    ref.read(illustratedRoomProvider.notifier).closeEditor();
    _leaveEditor();
  }

  void _leaveEditor() {
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (context.canPop()) {
        context.pop();
      } else {
        router.go('/room/illustrated');
      }
    } else {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    }
  }

  Future<void> _chooseCustomColor(
    IllustratedRoomDraft draft,
    IllustratedRoomSurface surface,
  ) async {
    final initial =
        draft.colors?.colorFor(surface) ??
        draft.template.defaultPalette.colors.colorFor(surface);
    final color = await showMixerColorPicker(context, initialColor: initial);
    if (!mounted ||
        color == null ||
        ref.read(illustratedRoomProvider).activeTemplateId !=
            draft.template.id ||
        !identical(ref.read(illustratedRoomProvider).activeDraft, draft)) {
      return;
    }
    ref.read(illustratedRoomProvider.notifier).setSurfaceColor(surface, color);
  }

  Future<void> _returnToBlackAndWhite(IllustratedRoomDraft draft) async {
    final controller = ref.read(illustratedRoomProvider.notifier);
    if (draft.temporaryGrayscale) {
      controller.clearComparison();
    } else {
      controller.showTemporaryGrayscale();
    }
    if (mounted) setState(() => _activeTool = null);
  }

  void _selectTool(IllustratedRoomTool tool) {
    setState(() => _activeTool = _activeTool == tool ? null : tool);
  }

  bool _railVisibleFor(double width) => _railVisibleOverride ?? width >= 600;

  Future<void> _openFlow([String? regionId]) async {
    if (_flowOpen) return;
    setState(() {
      _flowOpen = true;
      if (regionId != null) _selectedRegionId = regionId;
    });
    await showIllustratedRoomEditorFlow(
      context,
      templateId: widget.templateId,
      selectedRegionId: _selectedRegionId,
      onRegionSelected: (id) {
        if (mounted) setState(() => _selectedRegionId = id);
      },
    );
    if (mounted) setState(() => _flowOpen = false);
  }

  void _showColorRail() {
    setState(() => _railVisibleOverride = true);
  }

  void _hideColorRail() {
    setState(() {
      _railVisibleOverride = false;
      _activeTool = null;
    });
  }

  void _enterFocusPreview() {
    setState(() {
      _railVisibleOverrideBeforeFocus = _railVisibleOverride;
      _focusPreview = true;
      _activeTool = null;
    });
  }

  void _exitFocusPreview() {
    setState(() {
      _focusPreview = false;
      _railVisibleOverride = _railVisibleOverrideBeforeFocus;
      _railVisibleOverrideBeforeFocus = null;
    });
  }

  IllustratedRoomSurface? _surfaceFor(IllustratedRoomTool? tool) =>
      switch (tool) {
        IllustratedRoomTool.wall => IllustratedRoomSurface.wall,
        IllustratedRoomTool.ceiling => IllustratedRoomSurface.ceiling,
        IllustratedRoomTool.floor => IllustratedRoomSurface.floor,
        IllustratedRoomTool.furniture => IllustratedRoomSurface.furniture,
        IllustratedRoomTool.looks ||
        IllustratedRoomTool.designs ||
        null => null,
      };

  void _handlePreviewError() {
    if (mounted && !_previewUnavailable) {
      setState(() => _previewUnavailable = true);
    }
  }

  void _retryPreview() {
    setState(() {
      _previewUnavailable = false;
      _previewAttempt++;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(illustratedRoomEditorPersistenceProvider);
    final template = _template;
    if (template == null) {
      return _UnavailableRoom(onBack: _leaveEditor);
    }

    final session = ref.watch(illustratedRoomProvider);
    final draft =
        session.draftFor(template.id) ??
        IllustratedRoomDraft.grayscale(template);
    final exportState = ref.watch(illustratedRoomExportProvider);
    final designs = ref.watch(savedRoomDesignsProvider);
    final savedDesignCount = designs.asData?.value.length ?? 0;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFF101316),
        body: _previewUnavailable
            ? _RoomPreviewUnavailable(onRetry: _retryPreview, onBack: _goBack)
            : LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 600;
                  final railWidth = compact ? 68.0 : 72.0;
                  final railVisible =
                      !_focusPreview && _railVisibleFor(constraints.maxWidth);
                  final showTitle =
                      !_focusPreview && (!railVisible || !compact);
                  final padding = MediaQuery.paddingOf(context);
                  final availableFlyoutWidth = math.max(
                    0.0,
                    constraints.maxWidth -
                        padding.left -
                        padding.right -
                        railWidth -
                        16,
                  );
                  final flyoutWidth = math.min(
                    availableFlyoutWidth,
                    (constraints.maxWidth * .42).clamp(232.0, 300.0),
                  );
                  final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
                  final activeSurface = _surfaceFor(_activeTool);

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          key: const ValueKey('room-scene'),
                          behavior: HitTestBehavior.opaque,
                          onTap:
                              _focusPreview ||
                                  (_activeTool == null &&
                                      !(compact && railVisible))
                              ? null
                              : () => setState(() {
                                  _activeTool = null;
                                  if (compact) _railVisibleOverride = false;
                                }),
                          child: _RoomScene(
                            draft: draft,
                            viewMode: _viewMode,
                            retryToken: _previewAttempt,
                            onError: _handlePreviewError,
                            selectedRegionId: _selectedRegionId,
                            onRegionSelected:
                                _focusPreview ||
                                    _activeTool != null ||
                                    (compact && railVisible)
                                ? null
                                : (id) => _openFlow(id),
                          ),
                        ),
                      ),
                      if (railVisible && _activeTool != null)
                        Positioned(
                          key: const ValueKey('room-flyout'),
                          top: padding.top + 64,
                          right: padding.right + railWidth + AppSpacing.sm,
                          bottom: math.max(
                            padding.bottom + AppSpacing.sm,
                            keyboardInset + AppSpacing.sm,
                          ),
                          width: flyoutWidth,
                          child: IllustratedRoomFlyout(
                            tool: _activeTool!,
                            draft: draft,
                            onClose: () => setState(() => _activeTool = null),
                            onPaletteSelected: ref
                                .read(illustratedRoomProvider.notifier)
                                .applyPalette,
                            onSuggestedColor: (color) {
                              if (activeSurface != null) {
                                ref
                                    .read(illustratedRoomProvider.notifier)
                                    .setSurfaceColor(activeSurface, color);
                              }
                            },
                            onCustomColor: activeSurface == null
                                ? () {}
                                : () =>
                                      _chooseCustomColor(draft, activeSurface),
                            onMarketGuide: () => showIllustratedRoomMarketGuide(
                              context,
                              template,
                            ),
                            designsContent: _DesignsContent(
                              draft: draft,
                              savedDesignCount: savedDesignCount,
                              onSave: draft.canSave
                                  ? () => _saveDesign(draft)
                                  : null,
                              onOpen: _openSavedDesign,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 0,
                        right: padding.right,
                        bottom: 0,
                        width: railWidth,
                        child: IgnorePointer(
                          ignoring: !railVisible,
                          child: ExcludeSemantics(
                            excluding: !railVisible,
                            child: AnimatedSlide(
                              duration: AppMotion.duration(context),
                              curve: railVisible
                                  ? AppMotion.enter
                                  : AppMotion.exit,
                              offset: railVisible
                                  ? Offset.zero
                                  : const Offset(1, 0),
                              child: AnimatedOpacity(
                                duration: AppMotion.duration(context),
                                curve: railVisible
                                    ? AppMotion.enter
                                    : AppMotion.exit,
                                opacity: railVisible ? 1 : 0,
                                child: AnimatedSwitcher(
                                  duration: AppMotion.duration(context),
                                  child: railVisible
                                      ? IllustratedRoomColorRail(
                                          key: const ValueKey(
                                            'room-color-rail',
                                          ),
                                          draft: draft,
                                          activeTool: _activeTool,
                                          savedDesignCount: savedDesignCount,
                                          exportBusy: exportState.isBusy,
                                          onHide: _hideColorRail,
                                          onToolSelected: _selectTool,
                                          onBlackAndWhite: () =>
                                              _returnToBlackAndWhite(draft),
                                          onSaveToGallery:
                                              !exportState.isBusy &&
                                                  !_handlingExport
                                              ? () => _saveToGallery(draft)
                                              : null,
                                        )
                                      : const SizedBox.expand(
                                          key: ValueKey(
                                            'room-color-rail-hidden',
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!_focusPreview)
                        Positioned(
                          left: padding.left + AppSpacing.sm,
                          bottom:
                              math.max(padding.bottom, keyboardInset) +
                              AppSpacing.sm,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: math.max(
                                48,
                                constraints.maxWidth -
                                    padding.horizontal -
                                    (railVisible ? railWidth : 64) -
                                    24,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!_flowOpen)
                                  Material(
                                    borderRadius: BorderRadius.circular(8),
                                    child: IllustratedRoomDraftStatus(
                                      templateId: widget.templateId,
                                    ),
                                  ),
                                FilledButton.icon(
                                  key: const ValueKey('room-edit-flow'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                  onPressed: () => _openFlow(),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: Text(
                                    _selectedRegionId == null
                                        ? context.l10n.roomChangeSurface
                                        : context.l10n.roomSelectedSurface(
                                            roomRegionName(
                                              context.l10n,
                                              _selectedRegionId!,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (!_focusPreview)
                        Positioned(
                          right: padding.right + AppSpacing.sm,
                          bottom: padding.bottom + AppSpacing.sm,
                          child: IgnorePointer(
                            ignoring: railVisible,
                            child: ExcludeSemantics(
                              excluding: railVisible,
                              child: AnimatedOpacity(
                                duration: AppMotion.duration(context),
                                curve: railVisible
                                    ? AppMotion.exit
                                    : AppMotion.enter,
                                opacity: railVisible ? 0 : 1,
                                child: IconCircleButton(
                                  key: const ValueKey('room-show-color-tools'),
                                  icon: Icons.palette_outlined,
                                  label: 'Show color tools',
                                  onPressed: _showColorRail,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!_focusPreview)
                        Positioned(
                          left: padding.left + AppSpacing.sm,
                          top: padding.top + AppSpacing.sm,
                          child: IconCircleButton(
                            key: const ValueKey('room-editor-back'),
                            icon: Icons.arrow_back_rounded,
                            label: 'Back',
                            onPressed: _goBack,
                          ),
                        ),
                      if (showTitle)
                        Positioned(
                          left: padding.left + 64,
                          right:
                              padding.right +
                              (railVisible ? railWidth : 0) +
                              164,
                          top: padding.top + AppSpacing.sm,
                          height: 48,
                          child: _EditorTitle(draft: draft),
                        ),
                      if (!_focusPreview)
                        Positioned(
                          right:
                              padding.right +
                              (railVisible ? railWidth : 0) +
                              AppSpacing.sm,
                          top: padding.top + AppSpacing.sm,
                          child: _ViewModeControl(
                            mode: _viewMode,
                            onChanged: (mode) =>
                                setState(() => _viewMode = mode),
                            onFocusPreview: _enterFocusPreview,
                          ),
                        ),
                      if (_focusPreview)
                        Positioned(
                          right: padding.right + AppSpacing.sm,
                          top: padding.top + AppSpacing.sm,
                          child: IconCircleButton(
                            key: const ValueKey('room-exit-focus-preview'),
                            icon: Icons.fullscreen_exit_rounded,
                            label: 'Exit focus preview',
                            onPressed: _exitFocusPreview,
                          ),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _RoomScene extends StatelessWidget {
  const _RoomScene({
    required this.draft,
    required this.viewMode,
    required this.retryToken,
    required this.onError,
    this.selectedRegionId,
    this.onRegionSelected,
  });

  final IllustratedRoomDraft draft;
  final IllustratedRoomViewMode viewMode;
  final int retryToken;
  final VoidCallback onError;
  final String? selectedRegionId;
  final ValueChanged<String>? onRegionSelected;

  @override
  Widget build(BuildContext context) {
    final colors = draft.colors;
    final key = ValueKey(
      '${draft.template.id}-${viewMode.name}-${draft.mode.name}-'
      '${colors?.wall.hex}-${colors?.ceiling.hex}-'
      '${colors?.floor.hex}-${colors?.furniture.hex}',
    );
    return ColoredBox(
      color: const Color(0xFF101316),
      child: AnimatedSwitcher(
        duration: AppMotion.duration(context),
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        child: SizedBox.expand(
          key: key,
          child: IllustratedRoomSvg(
            draft: draft,
            fit: viewMode == IllustratedRoomViewMode.fillScreen
                ? BoxFit.cover
                : BoxFit.contain,
            alignment: Alignment(
              draft.template.focalPoint.x,
              draft.template.focalPoint.y,
            ),
            retryToken: retryToken,
            onError: onError,
            selectedRegionId: selectedRegionId,
            onRegionSelected: onRegionSelected,
          ),
        ),
      ),
    );
  }
}

class _EditorTitle extends StatelessWidget {
  const _EditorTitle({required this.draft});

  final IllustratedRoomDraft draft;

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('room-editor-title'),
    color: context.appColors.surface.withValues(alpha: .92),
    borderRadius: BorderRadius.circular(AppRadii.pill),
    elevation: 6,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Center(
        child: Text(
          '${draft.template.title} · ${draft.visualStateLabel}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
    ),
  );
}

class _ViewModeControl extends StatelessWidget {
  const _ViewModeControl({
    required this.mode,
    required this.onChanged,
    required this.onFocusPreview,
  });

  final IllustratedRoomViewMode mode;
  final ValueChanged<IllustratedRoomViewMode> onChanged;
  final VoidCallback onFocusPreview;

  @override
  Widget build(BuildContext context) => Material(
    color: context.appColors.surface.withValues(alpha: .92),
    borderRadius: BorderRadius.circular(AppRadii.pill),
    elevation: 6,
    clipBehavior: Clip.antiAlias,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ViewModeButton(
          key: const ValueKey('room-view-fill'),
          label: 'Fill screen',
          icon: Icons.crop_free_rounded,
          selected: mode == IllustratedRoomViewMode.fillScreen,
          onPressed: () => onChanged(IllustratedRoomViewMode.fillScreen),
        ),
        _ViewModeButton(
          key: const ValueKey('room-view-full'),
          label: 'See whole room',
          icon: Icons.fit_screen_rounded,
          selected: mode == IllustratedRoomViewMode.fullRoom,
          onPressed: () => onChanged(IllustratedRoomViewMode.fullRoom),
        ),
        _ViewModeButton(
          key: const ValueKey('room-focus-preview'),
          label: 'Focus preview',
          icon: Icons.fullscreen_rounded,
          selected: false,
          onPressed: onFocusPreview,
        ),
      ],
    ),
  );
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    onTap: onPressed,
    label: label,
    excludeSemantics: true,
    child: Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? context.appColors.primary.withValues(alpha: .18)
                  : Colors.transparent,
              border: Border.all(
                color: selected
                    ? context.appColors.primary
                    : Colors.transparent,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Icon(
              icon,
              color: selected
                  ? context.appColors.primary
                  : context.appColors.textPrimary,
            ),
          ),
        ),
      ),
    ),
  );
}

class _DesignsContent extends StatelessWidget {
  const _DesignsContent({
    required this.draft,
    required this.savedDesignCount,
    required this.onSave,
    required this.onOpen,
  });

  final IllustratedRoomDraft draft;
  final int savedDesignCount;
  final VoidCallback? onSave;
  final Future<void> Function(SavedRoomDesign) onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        savedDesignCount == 1
            ? '1 saved design on this device'
            : '$savedDesignCount saved designs on this device',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.appColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.md),
      PrimaryButton(
        key: const ValueKey('room-save-design'),
        label: draft.savedDesignId == null ? 'Save design' : 'Update design',
        icon: Icons.bookmark_add_outlined,
        onPressed: onSave,
      ),
      const SizedBox(height: AppSpacing.lg),
      Text('Saved designs', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppSpacing.sm),
      Expanded(child: SavedRoomDesignsList(onOpen: onOpen)),
    ],
  );
}

class _UnavailableRoom extends StatelessWidget {
  const _UnavailableRoom({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('room-template-unavailable'),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.meeting_room_outlined, size: 56),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Room unavailable',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'This room illustration is not available.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const ValueKey('room-unavailable-back'),
              label: 'Back to rooms',
              icon: Icons.arrow_back_rounded,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoomPreviewUnavailable extends StatelessWidget {
  const _RoomPreviewUnavailable({required this.onRetry, required this.onBack});

  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.broken_image_outlined,
                size: 56,
                color: Colors.white70,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Room preview unavailable',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'The illustration could not be loaded, so color controls are '
                'paused.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                key: const ValueKey('room-preview-retry'),
                label: 'Retry preview',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                key: const ValueKey('room-preview-back'),
                label: 'Back to Room',
                icon: Icons.arrow_back_rounded,
                onPressed: onBack,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
