import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';

import '../../room_studio/application/room_image_export_service.dart';
import '../../room_studio/presentation/illustrated_room_navigation.dart';
import '../../learning/domain/learning_palette_copy.dart';
import '../application/coloring_export_service.dart';
import '../application/coloring_project_providers.dart';
import '../domain/coloring_project.dart';
import '../domain/drawing_definition.dart';
import 'coloring_canvas.dart';
import 'coloring_room_assignment_dialog.dart';

class ColoringCompletionScreen extends ConsumerStatefulWidget {
  const ColoringCompletionScreen({
    super.key,
    required this.projectId,
    this.paletteCopy,
  });

  final String projectId;
  final LearningPaletteCopy? paletteCopy;

  @override
  ConsumerState<ColoringCompletionScreen> createState() =>
      _ColoringCompletionScreenState();
}

class _ColoringCompletionScreenState
    extends ConsumerState<ColoringCompletionScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(coloringProjectsProvider);
    final catalog = ref.watch(drawingCatalogProvider);
    if (projects.isLoading || catalog.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final project = projects.value
        ?.where((item) => item.id == widget.projectId)
        .firstOrNull;
    final definition = project == null
        ? null
        : catalog.value
              ?.where(
                (item) =>
                    item.id == project.drawingId &&
                    item.revision == project.drawingRevision,
              )
              .firstOrNull;
    if (project == null || definition == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.coloringStudioTitle)),
        body: Center(child: Text(context.l10n.coloringCompletedUnavailable)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.coloringCompleteTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.coloringDrawingTitle(definition.title),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.coloringCompleteBody,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  AspectRatio(
                    aspectRatio: definition.artwork.intrinsicSize.aspectRatio,
                    child: IgnorePointer(
                      child: ColoringCanvas(
                        definition: definition,
                        assignments: project.assignments,
                        onRegionTap: (_) {},
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('coloring-export'),
                        onPressed: _busy
                            ? null
                            : () => _export(definition, project),
                        icon: const Icon(Icons.download_rounded),
                        label: Text(context.l10n.coloringExportPng),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('coloring-share'),
                        onPressed: _busy
                            ? null
                            : () => _share(definition, project),
                        icon: const Icon(Icons.share_rounded),
                        label: Text(context.l10n.coloringShare),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('coloring-use-in-room'),
                        onPressed: project.assignments.isEmpty
                            ? null
                            : () => _useInRoom(project),
                        icon: const Icon(Icons.meeting_room_outlined),
                        label: Text(context.l10n.coloringUseInRoom),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/coloring'),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(context.l10n.coloringChooseAnother),
                      ),
                      TextButton(
                        onPressed: () => context.go('/my-work'),
                        child: Text(context.l10n.coloringOpenArtwork),
                      ),
                      if (widget.paletteCopy != null)
                        TextButton.icon(
                          key: const ValueKey('coloring-return-to-source'),
                          onPressed: () =>
                              context.go(widget.paletteCopy!.returnLocation),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: Text(context.l10n.coloringReturnLearning),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _export(
    DrawingDefinition definition,
    ColoringProject project,
  ) async {
    final l10n = context.l10n;
    await _run(() async {
      await saveColoringPng(
        encoder: ref.read(coloringExportServiceProvider),
        transport: ref.read(roomImageExportServiceProvider),
        definition: definition,
        project: project,
      );
      _notice(l10n.coloringExportedComplete);
    });
  }

  Future<void> _share(
    DrawingDefinition definition,
    ColoringProject project,
  ) async {
    final l10n = context.l10n;
    await _run(() async {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? const Rect.fromLTWH(0, 0, 1, 1)
          : box.localToGlobal(Offset.zero) & box.size;
      final result = await shareColoringPng(
        title: context.l10n.coloringShareTitle(
          context.l10n.coloringDrawingTitle(definition.title),
        ),
        encoder: ref.read(coloringExportServiceProvider),
        transport: ref.read(roomImageExportServiceProvider),
        definition: definition,
        project: project,
        origin: origin,
      );
      _notice(switch (result) {
        RoomShareResult.completed => l10n.coloringShareCompleted,
        RoomShareResult.dismissed => l10n.coloringShareDismissed,
        RoomShareResult.unavailable => l10n.coloringShareUnavailable,
      });
    });
  }

  Future<void> _useInRoom(ColoringProject project) async {
    final assigned = await showColoringRoomAssignmentDialog(
      context,
      project.assignments.values,
    );
    if (assigned == null || !mounted) return;
    await openLearningPaletteInIllustratedRoom(
      context,
      LearningPaletteCopy(
        colors: assigned,
        returnLocation: '/coloring/complete/${project.id}',
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await action();
    } on Object {
      _notice(l10n.coloringPngFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}
