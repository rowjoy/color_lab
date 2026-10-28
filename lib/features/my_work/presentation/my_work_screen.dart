import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/color/color_models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../history/application/history_providers.dart';
import '../../history/domain/saved_color.dart';
import '../../learning/application/learning_providers.dart';
import '../../learning/domain/learning_palette_copy.dart';
import '../../learning/presentation/learning_work_section.dart';
import '../../palette/application/saved_palettes_providers.dart';
import '../../palette/domain/saved_palette.dart';
import '../../picker/presentation/color_explorer.dart';
import '../../room_studio/application/room_designs_providers.dart';
import '../../room_studio/domain/illustrated_room.dart';
import '../../room_studio/domain/saved_room_design.dart';
import '../../room_studio/presentation/illustrated_room_navigation.dart';
import '../../shell/presentation/studio_page.dart';
import '../../coloring/presentation/my_artwork_section.dart';
import '../../coloring/presentation/coloring_navigation.dart';

class MyWorkScreen extends ConsumerWidget {
  const MyWorkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => StudioPage(
    name: 'MyWork',
    children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: SecondaryButton(
          key: const ValueKey('my-work-back'),
          label: context.l10n.back,
          icon: Icons.arrow_back_rounded,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      StudioHeading(
        eyebrow: context.l10n.myWorkEyebrow,
        title: context.l10n.myWorkTitle,
        description: context.l10n.myWorkDescription,
      ),
      const MyArtworkSection(),
      const SizedBox(height: AppSpacing.xxl),
      _LibrarySection(
        key: const ValueKey('my-work-room-projects'),
        title: context.l10n.roomProjectsTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.roomProjectsDescription),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              key: const ValueKey('my-work-open-projects'),
              label: context.l10n.roomProjectsTitle,
              icon: Icons.photo_library_outlined,
              onPressed: () => context.push('/rooms/projects'),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xxl),
      _LibrarySection(
        key: const ValueKey('my-work-learning-experiments'),
        title: context.l10n.myWorkExperimentsTitle,
        child: _experiments(context, ref),
      ),
      const SizedBox(height: AppSpacing.xxl),
      _LibrarySection(
        key: const ValueKey('my-work-colors'),
        title: context.l10n.myWorkColorsTitle,
        child: _colors(context, ref),
      ),
      const SizedBox(height: AppSpacing.xxl),
      _LibrarySection(
        key: const ValueKey('my-work-palettes'),
        title: context.l10n.myWorkPalettesTitle,
        child: _palettes(context, ref),
      ),
      const SizedBox(height: AppSpacing.xxl),
      _LibrarySection(
        key: const ValueKey('my-work-room-designs'),
        title: context.l10n.myWorkRoomDesignsTitle,
        child: _roomDesigns(context, ref),
      ),
    ],
  );

  Widget _experiments(BuildContext context, WidgetRef ref) => ref
      .watch(learningSessionProvider)
      .when(
        data: (session) {
          final records = session.visible.experiments;
          final content = records.isEmpty
              ? EmptyState(
                  key: const ValueKey('my-work-experiments-empty'),
                  icon: Icons.science_outlined,
                  title: context.l10n.learningNotebookEmptyTitle,
                  message: context.l10n.learningNotebookEmptyBody,
                  action: SecondaryButton(
                    label: context.l10n.learningOpenNotebook,
                    onPressed: () => context.push('/learn/notebook'),
                  ),
                )
              : LearningWorkSection(
                  records: records,
                  onOpen: (record) =>
                      context.push('/learn/experiment/${record.id}'),
                  onDelete: ref
                      .read(learningSessionProvider.notifier)
                      .deleteExperiment,
                  onUseInRoom: (record) => openLearningPaletteInIllustratedRoom(
                    context,
                    LearningPaletteCopy(
                      colors: record.resultHexes.map(RgbColor.fromHex),
                      returnLocation: '/my-work',
                    ),
                  ),
                  onUseInColoring: (record) => openLearningPaletteInColoring(
                    context,
                    LearningPaletteCopy(
                      colors: record.resultHexes.map(RgbColor.fromHex),
                      returnLocation: '/my-work',
                    ),
                  ),
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (session.saveError != null) ...[
                ErrorState(
                  key: const ValueKey('my-work-experiments-save-error'),
                  title: context.l10n.learningSaveError,
                  message: context.l10n.learningExperimentSaveFailed,
                  action: SecondaryButton(
                    label: context.l10n.learningRetrySave,
                    onPressed: session.saving
                        ? null
                        : () async {
                            try {
                              await ref
                                  .read(learningSessionProvider.notifier)
                                  .retryVisible();
                            } on Object {
                              // The controller retains the retryable error.
                            }
                          },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              content,
            ],
          );
        },
        error: (error, stackTrace) => ErrorState(
          key: const ValueKey('my-work-experiments-error'),
          title: context.l10n.learningLoadErrorTitle,
          message: context.l10n.learningLoadErrorBody,
          action: SecondaryButton(
            label: context.l10n.tryAgain,
            onPressed: () => ref.invalidate(learningSessionProvider),
          ),
        ),
        loading: () => LoadingState(
          key: const ValueKey('my-work-experiments-loading'),
          title: context.l10n.learningLoadingTitle,
          message: context.l10n.learningLoadingBody,
        ),
      );

  Widget _colors(BuildContext context, WidgetRef ref) => ref
      .watch(colorHistoryProvider)
      .when(
        data: (colors) => colors.isEmpty
            ? EmptyState(
                key: const ValueKey('my-work-colors-empty'),
                icon: Icons.colorize_outlined,
                title: context.l10n.myWorkColorsEmpty,
                message: context.l10n.myWorkColorsEmptyBody,
                action: SecondaryButton(
                  label: context.l10n.myWorkExploreColors,
                  onPressed: () => context.push('/capture'),
                ),
              )
            : _ColorRecords(colors: colors),
        error: (error, stackTrace) => ErrorState(
          key: const ValueKey('my-work-colors-error'),
          title: context.l10n.myWorkColorsError,
          message: context.l10n.myWorkErrorBody,
          action: SecondaryButton(
            key: const ValueKey('my-work-colors-retry'),
            label: context.l10n.tryAgain,
            onPressed: ref.read(colorHistoryProvider.notifier).retry,
          ),
        ),
        loading: () => LoadingState(
          key: const ValueKey('my-work-colors-loading'),
          title: context.l10n.myWorkColorsLoading,
          message: context.l10n.myWorkLoadingBody,
        ),
      );

  Widget _palettes(BuildContext context, WidgetRef ref) => ref
      .watch(savedPalettesProvider)
      .when(
        data: (palettes) => palettes.isEmpty
            ? EmptyState(
                key: const ValueKey('my-work-palettes-empty'),
                icon: Icons.palette_outlined,
                title: context.l10n.myWorkPalettesEmpty,
                message: context.l10n.myWorkPalettesEmptyBody,
                action: SecondaryButton(
                  label: context.l10n.myWorkCreatePalette,
                  onPressed: () => context.push('/harmonies'),
                ),
              )
            : _PaletteRecords(palettes: palettes),
        error: (error, stackTrace) => ErrorState(
          key: const ValueKey('my-work-palettes-error'),
          title: context.l10n.myWorkPalettesError,
          message: context.l10n.myWorkErrorBody,
          action: SecondaryButton(
            key: const ValueKey('my-work-palettes-retry'),
            label: context.l10n.tryAgain,
            onPressed: ref.read(savedPalettesProvider.notifier).retry,
          ),
        ),
        loading: () => LoadingState(
          key: const ValueKey('my-work-palettes-loading'),
          title: context.l10n.myWorkPalettesLoading,
          message: context.l10n.myWorkLoadingBody,
        ),
      );

  Widget _roomDesigns(BuildContext context, WidgetRef ref) => ref
      .watch(savedRoomDesignsProvider)
      .when(
        data: (designs) => designs.isEmpty
            ? EmptyState(
                key: const ValueKey('my-work-room-designs-empty'),
                icon: Icons.meeting_room_outlined,
                title: context.l10n.myWorkRoomDesignsEmpty,
                message: context.l10n.myWorkRoomDesignsEmptyBody,
                action: SecondaryButton(
                  label: context.l10n.myWorkTryRoom,
                  onPressed: () => context.push('/room/illustrated'),
                ),
              )
            : _RoomDesignRecords(designs: designs),
        error: (error, stackTrace) => ErrorState(
          key: const ValueKey('my-work-room-designs-error'),
          title: context.l10n.myWorkRoomDesignsError,
          message: context.l10n.myWorkErrorBody,
          action: SecondaryButton(
            key: const ValueKey('my-work-room-designs-retry'),
            label: context.l10n.tryAgain,
            onPressed: ref.read(savedRoomDesignsProvider.notifier).retry,
          ),
        ),
        loading: () => LoadingState(
          key: const ValueKey('my-work-room-designs-loading'),
          title: context.l10n.myWorkRoomDesignsLoading,
          message: context.l10n.myWorkLoadingBody,
        ),
      );
}

class _LibrarySection extends StatelessWidget {
  const _LibrarySection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => StudioCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    ),
  );
}

class _ColorRecords extends StatelessWidget {
  const _ColorRecords({required this.colors});

  final List<SavedColor> colors;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < colors.length; index++) ...[
        _ColorRecord(color: colors[index]),
        if (index != colors.length - 1) const SizedBox(height: AppSpacing.sm),
      ],
    ],
  );
}

class _ColorRecord extends StatelessWidget {
  const _ColorRecord({required this.color});

  final SavedColor color;

  @override
  Widget build(BuildContext context) => _RecordSurface(
    key: ValueKey('my-work-color-${color.id}'),
    onTap: () => showColorDetails(
      context,
      RgbColor.fromHex(color.hex),
      source: color.source,
    ),
    child: Row(
      children: [
        Container(
          width: AppTouchTargets.minimum,
          height: AppTouchTargets.minimum,
          decoration: BoxDecoration(
            color: displayColor(RgbColor.fromHex(color.hex)),
            shape: BoxShape.circle,
            border: Border.all(color: context.appColors.outline),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(color.name, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(color.hex, style: AppTypography.mono),
            ],
          ),
        ),
        if (color.isFavorite)
          Icon(Icons.favorite_rounded, color: context.appColors.primary),
      ],
    ),
  );
}

class _PaletteRecords extends StatelessWidget {
  const _PaletteRecords({required this.palettes});

  final List<SavedPalette> palettes;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < palettes.length; index++) ...[
        _RecordSurface(
          key: ValueKey('my-work-palette-${palettes[index].id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                palettes[index].name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              PaletteBar(
                colors: palettes[index].colors.map(displayColor).toList(),
              ),
            ],
          ),
        ),
        if (index != palettes.length - 1) const SizedBox(height: AppSpacing.sm),
      ],
    ],
  );
}

class _RoomDesignRecords extends StatelessWidget {
  const _RoomDesignRecords({required this.designs});

  final List<SavedRoomDesign> designs;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < designs.length; index++) ...[
        _RoomDesignRecord(design: designs[index]),
        if (index != designs.length - 1) const SizedBox(height: AppSpacing.sm),
      ],
    ],
  );
}

class _RoomDesignRecord extends StatelessWidget {
  const _RoomDesignRecord({required this.design});

  final SavedRoomDesign design;

  @override
  Widget build(BuildContext context) {
    final template = IllustratedRoomCatalog.maybeById(design.templateId);
    final colors = design.colors;
    return _RecordSurface(
      key: ValueKey('my-work-room-design-${design.id}'),
      onTap: template == null
          ? null
          : () => unawaited(openIllustratedSavedDesign(context, design)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(design.name, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            template?.title ?? context.l10n.myWorkUnavailableRoom,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PaletteBar(
            colors: [
              colors.wall,
              colors.ceiling,
              colors.floor,
              colors.furniture,
            ].map(displayColor).toList(),
          ),
        ],
      ),
    );
  }
}

class _RecordSurface extends StatelessWidget {
  const _RecordSurface({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.appColors.surfaceElevated,
    borderRadius: BorderRadius.circular(AppRadii.medium),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTouchTargets.minimum),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: child,
        ),
      ),
    ),
  );
}
