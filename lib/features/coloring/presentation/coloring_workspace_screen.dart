import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';

import '../../../core/color/color_models.dart';
import '../../learning/domain/learning_palette_copy.dart';
import '../application/coloring_project_providers.dart';
import '../application/coloring_session_controller.dart';
import '../domain/drawing_definition.dart';
import 'color_source_sheet.dart';
import 'coloring_canvas.dart';
import 'coloring_region_list.dart';

class ColoringWorkspaceScreen extends ConsumerStatefulWidget {
  const ColoringWorkspaceScreen({
    super.key,
    required this.projectId,
    this.paletteCopy,
  });

  final String projectId;
  final LearningPaletteCopy? paletteCopy;

  @override
  ConsumerState<ColoringWorkspaceScreen> createState() =>
      _ColoringWorkspaceScreenState();
}

class _ColoringWorkspaceScreenState
    extends ConsumerState<ColoringWorkspaceScreen> {
  ColoringSessionController? _controller;
  String? _selectedGuidedSlotId;
  String? _message;
  bool _finishing = false;

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.flush().catchError((Object _, StackTrace _) {}));
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentProject = ref.watch(coloringProjectProvider(widget.projectId));
    final catalog = ref.watch(drawingCatalogProvider);
    final repository = ref.watch(coloringProjectRepositoryProvider);
    if (currentProject.isLoading || catalog.isLoading || repository.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (currentProject.hasError || catalog.hasError || repository.hasError) {
      return _Unavailable(
        message: context.l10n.coloringOpenFailed,
        onRetry: () {
          ref.invalidate(coloringProjectRepositoryProvider);
          ref.invalidate(coloringProjectsProvider);
          ref.invalidate(coloringProjectProvider(widget.projectId));
          ref.invalidate(drawingCatalogProvider);
        },
      );
    }
    final project = currentProject.requireValue;
    if (project == null) {
      return _Unavailable(message: context.l10n.coloringProjectMissing);
    }
    final definition = catalog.requireValue
        .where(
          (item) =>
              item.id == project.drawingId &&
              item.revision == project.drawingRevision,
        )
        .firstOrNull;
    if (definition == null) {
      return _Unavailable(message: context.l10n.coloringRevisionMissing);
    }
    if (_controller == null) {
      final projects = ref.read(coloringProjectsProvider.notifier);
      _controller = ColoringSessionController(
        repository: repository.requireValue,
        definition: definition,
        project: project,
        onAcknowledged: projects.publishAcknowledged,
      );
    }
    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) => _buildWorkspace(context, _controller!),
    );
  }

  Widget _buildWorkspace(
    BuildContext context,
    ColoringSessionController controller,
  ) {
    final session = controller.session;
    final definition = controller.definition;
    final isGuided = session.visible.mode == ColoringMode.guided;
    final controls = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isGuided
                ? context.l10n.coloringGuidedMode
                : context.l10n.coloringFreeMode,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.coloringProgress(
              controller.filledRequiredCount,
              controller.requiredCount,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: controller.progress),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(_message!, key: const ValueKey('coloring-feedback')),
            ),
          ],
          if (session.saveStatus == ProjectSaveStatus.failed) ...[
            const SizedBox(height: 12),
            MaterialBanner(
              content: Text(context.l10n.coloringSaveDraft),
              actions: [
                TextButton(
                  key: const ValueKey('coloring-retry-save'),
                  onPressed: () => _guard(controller.retrySave),
                  child: Text(context.l10n.coloringRetry),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          ColoringRegionList(
            definition: definition,
            project: session.visible,
            focusedRegionId: session.focusedRegionId,
            onSelect: (id) {
              controller.focusRegion(id);
              setState(() => _message = context.l10n.coloringRegionSelected);
            },
          ),
          const SizedBox(height: 16),
          ColorSourceSheet(
            definition: definition,
            guidedOnly: isGuided,
            selectedColor: _selectedGuidedSlotId == null
                ? null
                : definition.slotById(_selectedGuidedSlotId!).color,
            extraColors: widget.paletteCopy?.colors ?? const [],
            onSelected: (color) => isGuided
                ? _selectGuidedColor(definition, color)
                : _applyFreeColor(controller, color),
          ),
          if (isGuided) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('coloring-apply-guided'),
              onPressed:
                  session.focusedRegionId == null ||
                      _selectedGuidedSlotId == null
                  ? null
                  : () => _applyGuidedSelection(controller),
              icon: const Icon(Icons.format_color_fill_rounded),
              label: Text(context.l10n.coloringApplyGuided),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: session.visible.undoStack.isEmpty
                    ? null
                    : () => _guard(controller.undo),
                icon: const Icon(Icons.undo_rounded),
                label: Text(context.l10n.coloringUndo),
              ),
              OutlinedButton.icon(
                onPressed: session.visible.redoStack.isEmpty
                    ? null
                    : () => _guard(controller.redo),
                icon: const Icon(Icons.redo_rounded),
                label: Text(context.l10n.coloringRedo),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final id = controller.findNextRegion();
                  setState(
                    () => _message = id == null
                        ? context.l10n.coloringAllColored
                        : context.l10n.coloringNextUnfilled,
                  );
                },
                icon: const Icon(Icons.my_location_rounded),
                label: Text(context.l10n.coloringFindRegion),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('coloring-finish'),
            onPressed: () => _finish(controller),
            icon: const Icon(Icons.check_rounded),
            label: Text(context.l10n.coloringFinish),
          ),
        ],
      ),
    );
    final canvas = Padding(
      padding: const EdgeInsets.all(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ColoringCanvas(
            definition: definition,
            assignments: session.visible.assignments,
            focusedRegionId: session.focusedRegionId,
            onRegionTap: (id) => _tapRegion(controller, id),
          ),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !_finishing,
        title: Text(context.l10n.coloringDrawingTitle(definition.title)),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Center(
              child: Text(switch (session.saveStatus) {
                ProjectSaveStatus.saved => context.l10n.coloringSaved,
                ProjectSaveStatus.saving => context.l10n.coloringSaving,
                ProjectSaveStatus.failed => context.l10n.coloringNotSaved,
              }),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _finishing,
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth >= 800
                ? Row(
                    children: [
                      Expanded(flex: 3, child: canvas),
                      SizedBox(width: 360, child: controls),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(
                        flex: constraints.maxHeight < 480 ? 2 : 5,
                        child: canvas,
                      ),
                      Expanded(
                        flex: constraints.maxHeight < 480 ? 3 : 5,
                        child: controls,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _selectGuidedColor(DrawingDefinition definition, RgbColor color) {
    final slot = definition.slots
        .where((item) => item.color == color)
        .firstOrNull;
    setState(() {
      _selectedGuidedSlotId = slot?.id;
      _message = slot == null
          ? context.l10n.coloringChooseGuided
          : context.l10n.coloringSelectedColor(
              context.l10n.coloringSlotLabel(slot.label),
            );
    });
  }

  Future<void> _tapRegion(
    ColoringSessionController controller,
    String id,
  ) async {
    controller.focusRegion(id);
    if (controller.session.visible.mode == ColoringMode.free) {
      setState(() => _message = context.l10n.coloringNowChooseColor);
      return;
    }
    await _applyGuidedSelection(controller);
  }

  Future<void> _applyGuidedSelection(
    ColoringSessionController controller,
  ) async {
    final id = controller.session.focusedRegionId;
    if (id == null) {
      setState(() => _message = context.l10n.coloringChooseRegion);
      return;
    }
    final slotId = _selectedGuidedSlotId;
    if (slotId == null) {
      setState(() => _message = context.l10n.coloringChooseLabeledColor);
      return;
    }
    final accepted = await _guardValue(
      () => controller.fillRegion(
        id,
        controller.definition.slotById(slotId).color,
      ),
      false,
    );
    if (!mounted) return;
    setState(
      () => _message = accepted
          ? context.l10n.coloringAccepted
          : context.l10n.coloringWrongColor,
    );
  }

  Future<void> _applyFreeColor(
    ColoringSessionController controller,
    RgbColor color,
  ) async {
    final regionId = controller.session.focusedRegionId;
    if (regionId == null) {
      setState(() => _message = context.l10n.coloringChooseRegion);
      return;
    }
    await _guard(() => controller.fillRegion(regionId, color));
    if (mounted) {
      setState(() => _message = context.l10n.coloringAppliedColor(color.hex));
    }
  }

  Future<void> _finish(ColoringSessionController controller) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      final completed = await _guardValue(controller.finish, false);
      if (!mounted) return;
      if (completed) {
        context.replace(
          '/coloring/complete/${widget.projectId}',
          extra: widget.paletteCopy,
        );
      } else {
        setState(
          () => _message =
              controller.session.saveStatus == ProjectSaveStatus.failed
              ? context.l10n.coloringRetryBeforeFinish
              : context.l10n.coloringFinishRemaining,
        );
      }
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _guard(Future<dynamic> Function() action) async {
    try {
      await action();
    } on Object {
      if (mounted) {
        setState(() => _message = context.l10n.coloringChangeSaveFailed);
      }
    }
  }

  Future<T> _guardValue<T>(Future<T> Function() action, T fallback) async {
    try {
      return await action();
    } on Object {
      if (mounted) {
        setState(() => _message = context.l10n.coloringChangeSaveFailed);
      }
      return fallback;
    }
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.coloringStudioTitle)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.palette_outlined, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: Text(context.l10n.coloringRetry),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
