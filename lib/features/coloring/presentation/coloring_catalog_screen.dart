import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';

import '../../learning/domain/learning_palette_copy.dart';
import '../application/coloring_project_providers.dart';
import '../domain/coloring_project.dart';
import '../domain/drawing_definition.dart';
import 'coloring_canvas.dart';
import 'coloring_mode_sheet.dart';

class ColoringCatalogScreen extends ConsumerStatefulWidget {
  const ColoringCatalogScreen({super.key, this.paletteCopy});

  final LearningPaletteCopy? paletteCopy;

  @override
  ConsumerState<ColoringCatalogScreen> createState() =>
      _ColoringCatalogScreenState();
}

class _ColoringCatalogScreenState extends ConsumerState<ColoringCatalogScreen> {
  DrawingCategory? _category;
  DrawingDifficulty? _difficulty;
  ColoringMode? _mode;
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(drawingCatalogProvider);
    final projects = ref.watch(coloringProjectsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.coloringStudioTitle)),
      body: SafeArea(
        child: catalog.when(
          loading: () => Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _CatalogError(
            onRetry: () => ref.invalidate(drawingCatalogProvider),
          ),
          data: (drawings) {
            final filtered = drawings
                .where(
                  (drawing) =>
                      (_category == null || drawing.category == _category) &&
                      (_difficulty == null ||
                          drawing.difficulty == _difficulty),
                )
                .toList(growable: false);
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.l10n.coloringCatalogHeadline,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(context.l10n.coloringCatalogBody),
                        if (widget.paletteCopy != null) ...[
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                context.l10n.coloringCopiedPaletteReady,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _Filters(
                          category: _category,
                          difficulty: _difficulty,
                          mode: _mode,
                          onCategory: (value) =>
                              setState(() => _category = value),
                          onDifficulty: (value) =>
                              setState(() => _difficulty = value),
                          onMode: (value) => setState(() => _mode = value),
                        ),
                      ],
                    ),
                  ),
                ),
                if (projects.value case final saved? when saved.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _ContinueSection(
                      projects: saved
                          .where(
                            (project) => _mode == null || project.mode == _mode,
                          )
                          .toList(growable: false),
                      catalog: drawings,
                      onResume: (project) => context.push(
                        '/coloring/project/${project.id}',
                        extra: widget.paletteCopy,
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.crossAxisExtent >= 1000
                          ? 3
                          : constraints.crossAxisExtent >= 620
                          ? 2
                          : 1;
                      if (columns == 1) {
                        return SliverList.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) => Padding(
                            padding: EdgeInsets.only(
                              bottom: index == filtered.length - 1 ? 0 : 16,
                            ),
                            child: _DrawingCard(
                              definition: filtered[index],
                              enabled: !_starting,
                              singleColumn: true,
                              onStart: () => _start(filtered[index]),
                            ),
                          ),
                        );
                      }
                      return SliverGrid.builder(
                        itemCount: filtered.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: columns == 1 ? 1.35 : .92,
                        ),
                        itemBuilder: (context, index) => _DrawingCard(
                          definition: filtered[index],
                          enabled: !_starting,
                          singleColumn: false,
                          onStart: () => _start(filtered[index]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _start(DrawingDefinition definition) async {
    final mode =
        _mode ??
        await showColoringModeSheet(
          context,
          drawingTitle: context.l10n.coloringDrawingTitle(definition.title),
        );
    if (mode == null || !mounted) return;
    setState(() => _starting = true);
    try {
      final project = await ref
          .read(coloringProjectsProvider.notifier)
          .create(definition, mode);
      if (!mounted) return;
      await context.push(
        '/coloring/project/${project.id}',
        extra: widget.paletteCopy,
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.coloringCreateFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.category,
    required this.difficulty,
    required this.mode,
    required this.onCategory,
    required this.onDifficulty,
    required this.onMode,
  });

  final DrawingCategory? category;
  final DrawingDifficulty? difficulty;
  final ColoringMode? mode;
  final ValueChanged<DrawingCategory?> onCategory;
  final ValueChanged<DrawingDifficulty?> onDifficulty;
  final ValueChanged<ColoringMode?> onMode;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      FilterChip(
        label: Text(context.l10n.coloringAllCategories),
        selected: category == null,
        onSelected: (_) => onCategory(null),
      ),
      for (final value in DrawingCategory.values)
        FilterChip(
          label: Text(switch (value) {
            DrawingCategory.fruit => context.l10n.coloringCategoryFruit,
            DrawingCategory.animals => context.l10n.coloringCategoryAnimals,
            DrawingCategory.treesNature => context.l10n.coloringCategoryNature,
            DrawingCategory.rooms => context.l10n.coloringCategoryRooms,
          }),
          selected: category == value,
          onSelected: (_) => onCategory(value),
        ),
      const SizedBox(width: 8),
      for (final value in DrawingDifficulty.values)
        FilterChip(
          label: Text(context.l10n.coloringDifficulty(value.name)),
          selected: difficulty == value,
          onSelected: (selected) => onDifficulty(selected ? value : null),
        ),
      const SizedBox(width: 8),
      FilterChip(
        label: Text(context.l10n.coloringAllModes),
        selected: mode == null,
        onSelected: (_) => onMode(null),
      ),
      for (final value in ColoringMode.values)
        FilterChip(
          label: Text(
            value == ColoringMode.guided
                ? context.l10n.coloringGuidedMode
                : context.l10n.coloringFreeMode,
          ),
          selected: mode == value,
          onSelected: (_) => onMode(value),
        ),
    ],
  );
}

class _DrawingCard extends StatelessWidget {
  const _DrawingCard({
    required this.definition,
    required this.enabled,
    required this.singleColumn,
    required this.onStart,
  });

  final DrawingDefinition definition;
  final bool enabled;
  final bool singleColumn;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final preview = IgnorePointer(
      child: ColoringCanvas(
        definition: definition,
        assignments: const {},
        onRegionTap: (_) {},
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onStart : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (singleColumn)
              AspectRatio(aspectRatio: 16 / 9, child: preview)
            else
              Expanded(child: preview),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.coloringDrawingTitle(definition.title),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.coloringDrawingDescription(
                      definition.description,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.coloringDifficultyBadge(
                      definition.difficulty.name,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueSection extends StatelessWidget {
  const _ContinueSection({
    required this.projects,
    required this.catalog,
    required this.onResume,
  });

  final List<ColoringProject> projects;
  final List<DrawingDefinition> catalog;
  final ValueChanged<ColoringProject> onResume;

  @override
  Widget build(BuildContext context) {
    final active = projects
        .where((project) => !project.completed)
        .take(4)
        .toList();
    if (active.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.coloringContinue,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final project in active)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(
                context.l10n.coloringDrawingTitle(
                  catalog
                          .where((item) => item.id == project.drawingId)
                          .firstOrNull
                          ?.title ??
                      '',
                ),
              ),
              subtitle: Text(
                context.l10n.coloringProjectSummary(
                  context.l10n.coloringModeSummary(project.mode.name),
                  project.assignments.length,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onResume(project),
            ),
        ],
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: Text(context.l10n.coloringRetryCatalog),
    ),
  );
}
