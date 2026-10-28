import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';

import '../../room_studio/application/room_image_export_service.dart';
import '../application/coloring_export_service.dart';
import '../application/coloring_project_providers.dart';
import '../domain/coloring_project.dart';
import '../domain/drawing_definition.dart';

class MyArtworkSection extends ConsumerWidget {
  const MyArtworkSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(coloringProjectsProvider);
    final catalog = ref.watch(drawingCatalogProvider);
    return Card(
      key: const ValueKey('my-work-coloring-projects'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.coloringMyArtwork,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(context.l10n.coloringArtworkBody),
            const SizedBox(height: 16),
            if (projects.isLoading || catalog.isLoading)
              Center(child: CircularProgressIndicator())
            else if (projects.hasError || catalog.hasError)
              FilledButton.icon(
                onPressed: () {
                  ref.invalidate(coloringProjectsProvider);
                  ref.invalidate(drawingCatalogProvider);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.l10n.coloringRetryArtwork),
              )
            else if (projects.requireValue.isEmpty)
              _EmptyArtwork(onStart: () => context.push('/coloring'))
            else
              for (final project in projects.requireValue)
                _ArtworkRow(
                  project: project,
                  definition: catalog.requireValue
                      .where((item) => item.id == project.drawingId)
                      .firstOrNull,
                  onResume: () =>
                      context.push('/coloring/project/${project.id}'),
                  onDuplicate: () => _duplicate(context, ref, project),
                  onExport: () =>
                      _export(context, ref, project, catalog.requireValue),
                  onShare: () =>
                      _share(context, ref, project, catalog.requireValue),
                  onDelete: () => _delete(context, ref, project),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
    ColoringProject project,
  ) async {
    try {
      final copy = await ref
          .read(coloringProjectsProvider.notifier)
          .duplicate(project);
      if (context.mounted) context.push('/coloring/project/${copy.id}');
    } on Object {
      if (context.mounted) {
        _notice(context, context.l10n.coloringDuplicateFailed);
      }
    }
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    ColoringProject project,
    List<DrawingDefinition> catalog,
  ) async {
    final definition = catalog
        .where((item) => item.id == project.drawingId)
        .firstOrNull;
    if (definition == null) return;
    try {
      await saveColoringPng(
        encoder: ref.read(coloringExportServiceProvider),
        transport: ref.read(roomImageExportServiceProvider),
        definition: definition,
        project: project,
      );
      if (context.mounted) _notice(context, context.l10n.coloringExported);
    } on Object {
      if (context.mounted) {
        _notice(context, context.l10n.coloringExportFailed);
      }
    }
  }

  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    ColoringProject project,
    List<DrawingDefinition> catalog,
  ) async {
    final definition = catalog
        .where((item) => item.id == project.drawingId)
        .firstOrNull;
    final box = context.findRenderObject() as RenderBox?;
    if (definition == null || box == null) return;
    try {
      final result = await shareColoringPng(
        title: context.l10n.coloringShareTitle(
          context.l10n.coloringDrawingTitle(definition.title),
        ),
        encoder: ref.read(coloringExportServiceProvider),
        transport: ref.read(roomImageExportServiceProvider),
        definition: definition,
        project: project,
        origin: box.localToGlobal(Offset.zero) & box.size,
      );
      if (context.mounted) {
        _notice(context, switch (result) {
          RoomShareResult.completed => context.l10n.coloringShareCompleted,
          RoomShareResult.dismissed => context.l10n.coloringShareDismissed,
          RoomShareResult.unavailable => context.l10n.coloringShareUnavailable,
        });
      }
    } on Object {
      if (context.mounted) {
        _notice(context, context.l10n.coloringSharingFailed);
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ColoringProject project,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.coloringDeleteTitle),
        content: Text(context.l10n.coloringDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.coloringCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.coloringDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(coloringProjectsProvider.notifier).delete(project.id);
    } on Object {
      if (context.mounted) {
        _notice(context, context.l10n.coloringDeleteFailed);
      }
    }
  }

  void _notice(BuildContext context, String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _EmptyArtwork extends StatelessWidget {
  const _EmptyArtwork({required this.onStart});
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Icon(Icons.draw_outlined, size: 44),
      const SizedBox(height: 8),
      Text(context.l10n.coloringEmptyArtwork),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: onStart,
        child: Text(context.l10n.coloringOpenStudio),
      ),
    ],
  );
}

class _ArtworkRow extends StatelessWidget {
  const _ArtworkRow({
    required this.project,
    required this.definition,
    required this.onResume,
    required this.onDuplicate,
    required this.onExport,
    required this.onShare,
    required this.onDelete,
  });

  final ColoringProject project;
  final DrawingDefinition? definition;
  final VoidCallback onResume;
  final VoidCallback onDuplicate;
  final VoidCallback onExport;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            project.completed
                ? Icons.check_circle_rounded
                : Icons.edit_outlined,
          ),
          title: Text(
            definition == null
                ? context.l10n.coloringUnknownDrawing
                : context.l10n.coloringDrawingTitle(definition!.title),
          ),
          subtitle: Text(
            context.l10n.coloringProjectSummary(
              context.l10n.coloringModeSummary(project.mode.name),
              project.assignments.length,
            ),
          ),
          onTap: onResume,
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            TextButton(
              onPressed: onResume,
              child: Text(context.l10n.coloringResume),
            ),
            TextButton(
              onPressed: onDuplicate,
              child: Text(context.l10n.coloringDuplicate),
            ),
            TextButton(
              onPressed: onExport,
              child: Text(context.l10n.coloringExport),
            ),
            TextButton(
              onPressed: onShare,
              child: Text(context.l10n.coloringShare),
            ),
            TextButton(
              onPressed: onDelete,
              child: Text(context.l10n.coloringDelete),
            ),
          ],
        ),
        const Divider(),
      ],
    ),
  );
}
