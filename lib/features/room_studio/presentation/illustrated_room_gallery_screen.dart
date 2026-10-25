import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../application/illustrated_room_controller.dart';
import '../domain/illustrated_room.dart';
import '../domain/illustrated_room_draft.dart';
import 'illustrated_room_navigation.dart';
import 'illustrated_room_svg.dart';
import 'saved_room_designs_sheet.dart';

class IllustratedRoomGalleryScreen extends ConsumerWidget {
  const IllustratedRoomGalleryScreen({super.key, this.templates});

  final List<IllustratedRoomTemplate>? templates;

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/room');
    }
  }

  Future<void> _openSavedDesign(BuildContext context) async {
    await showSavedRoomDesigns(
      context,
      onOpen: (design) => openIllustratedSavedDesign(context, design),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = templates ?? IllustratedRoomCatalog.all;
    final session = ref.watch(illustratedRoomProvider);
    final useCompactActions = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      key: const ValueKey('screen-IllustratedRoomGallery'),
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('room-gallery-back'),
          tooltip: 'Back to Room',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Choose a room'),
        actions: [
          if (useCompactActions)
            IconButton(
              key: const ValueKey('room-gallery-saved-designs'),
              tooltip: 'Saved designs',
              onPressed: () => _openSavedDesign(context),
              icon: const Icon(Icons.collections_bookmark_outlined),
            )
          else
            TextButton.icon(
              key: const ValueKey('room-gallery-saved-designs'),
              onPressed: () => _openSavedDesign(context),
              icon: const Icon(Icons.collections_bookmark_outlined),
              label: const Text('Saved designs'),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: CustomScrollView(
        key: const ValueKey('room-gallery-scroll'),
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Text(
                'Start in black & white, then test complete looks or your own '
                'colors.',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.crossAxisExtent < 720 ? 1 : 2;
                const spacing = AppSpacing.lg;
                final itemWidth =
                    (constraints.crossAxisExtent - spacing * (columns - 1)) /
                    columns;
                final itemHeight =
                    itemWidth / 1.5 + _roomCardFooterExtent(context);
                return SliverGrid(
                  key: const ValueKey('room-template-grid'),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    mainAxisExtent: itemHeight,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final template = rooms[index];
                      final retained = session.draftFor(template.id);
                      return _RoomTemplateCard(
                        template: template,
                        showDraftBadge: _showsDraftBadge(retained),
                        onOpen: () {
                          ref
                              .read(illustratedRoomProvider.notifier)
                              .openTemplate(template);
                          context.push('/room/illustrated/${template.id}');
                        },
                      );
                    },
                    childCount: rooms.length,
                    addAutomaticKeepAlives: false,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

bool _showsDraftBadge(IllustratedRoomDraft? draft) =>
    draft != null &&
    (draft.mode != IllustratedRoomVisualMode.grayscale ||
        draft.isDirty ||
        draft.savedDesignId != null);

double _roomCardFooterExtent(BuildContext context) {
  final textTheme = Theme.of(context).textTheme;
  final textScaler = MediaQuery.textScalerOf(context);
  final textDirection = Directionality.of(context);

  double textHeight(TextStyle? style, {int lines = 1}) {
    final painter = TextPainter(
      text: TextSpan(text: List.filled(lines, 'Ag').join('\n'), style: style),
      maxLines: lines,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  final titleHeight = textHeight(textTheme.titleMedium);
  final draftBadgeHeight = textHeight(textTheme.bodyMedium) + AppSpacing.xs * 2;
  final summaryHeight = textHeight(textTheme.bodySmall, lines: 2);
  final contentHeight =
      AppSpacing.md * 2 +
      math.max(titleHeight, draftBadgeHeight) +
      AppSpacing.xs +
      summaryHeight;
  return math.max(132, contentHeight.ceilToDouble() + AppSpacing.xs);
}

class _RoomTemplateCard extends StatefulWidget {
  const _RoomTemplateCard({
    required this.template,
    required this.showDraftBadge,
    required this.onOpen,
  });

  final IllustratedRoomTemplate template;
  final bool showDraftBadge;
  final VoidCallback onOpen;

  @override
  State<_RoomTemplateCard> createState() => _RoomTemplateCardState();
}

class _RoomTemplateCardState extends State<_RoomTemplateCard> {
  bool _failed = false;
  int _retryToken = 0;

  void _handleError() {
    if (mounted && !_failed) setState(() => _failed = true);
  }

  void _retry() {
    setState(() {
      _failed = false;
      _retryToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    return Semantics(
      key: ValueKey('room-template-${template.id}'),
      container: true,
      button: true,
      onTap: widget.onOpen,
      label: '${template.title}, black-and-white color-testing template',
      excludeSemantics: !_failed,
      explicitChildNodes: _failed,
      child: Material(
        color: context.appColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
          side: BorderSide(color: context.appColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          excludeFromSemantics: true,
          onTap: widget.onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                key: ValueKey('room-template-preview-${template.id}'),
                aspectRatio: template.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      key: ValueKey('room-template-loading-${template.id}'),
                      decoration: BoxDecoration(
                        color: context.appColors.surface,
                      ),
                      child: Icon(
                        Icons.chair_outlined,
                        size: 42,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                    if (_failed)
                      _CardFailure(templateId: template.id, onRetry: _retry)
                    else
                      ExcludeSemantics(
                        child: IllustratedRoomSvg(
                          draft: IllustratedRoomDraft.grayscale(template),
                          fit: BoxFit.cover,
                          alignment: Alignment(
                            template.focalPoint.x,
                            template.focalPoint.y,
                          ),
                          retryToken: _retryToken,
                          onError: _handleError,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              template.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (widget.showDraftBadge)
                            Container(
                              key: ValueKey(
                                'room-template-draft-${template.id}',
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: context.appColors.primary.withValues(
                                  alpha: .14,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                                border: Border.all(
                                  color: context.appColors.primary,
                                ),
                              ),
                              child: const Text('Draft'),
                            ),
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        template.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardFailure extends StatelessWidget {
  const _CardFailure({required this.templateId, required this.onRetry});

  final String templateId;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.appColors.surface,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined),
            const SizedBox(height: AppSpacing.xs),
            const Text('Preview unavailable'),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              key: ValueKey('room-template-retry-$templateId'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  );
}
