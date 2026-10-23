import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../picker/presentation/color_explorer.dart';
import '../application/history_providers.dart';
import '../domain/saved_color.dart';

class ColorHistorySection extends ConsumerStatefulWidget {
  const ColorHistorySection({super.key});

  @override
  ConsumerState<ColorHistorySection> createState() =>
      _ColorHistorySectionState();
}

class _ColorHistorySectionState extends ConsumerState<ColorHistorySection> {
  late final TextEditingController _search;
  final _pending = <String>{};

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: ref.read(historyFilterProvider).query,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _mutate(SavedColor color, Future<void> Function() action) async {
    if (_pending.contains(color.id)) return;
    setState(() => _pending.add(color.id));
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update your color. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pending.remove(color.id));
    }
  }

  Future<void> _delete(SavedColor color) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Delete saved color?'),
        content: Text('Remove ${color.name} (${color.hex}) from your library?'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: context.appColors.textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: context.appColors.textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _mutate(
        color,
        () => ref.read(colorHistoryProvider.notifier).deleteColor(color.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(historyFilterProvider);
    final colors = ref.watch(filteredColorsProvider);
    final allColors = ref.watch(colorHistoryProvider).asData?.value;
    ref.listen(historyFilterProvider, (_, next) {
      if (_search.text != next.query) {
        _search.value = TextEditingValue(
          text: next.query,
          selection: TextSelection.collapsed(offset: next.query.length),
        );
      }
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Saved colors',
          subtitle: 'Your discoveries, always close at hand.',
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const ValueKey('history-search'),
          controller: _search,
          onChanged: ref.read(historyFilterProvider.notifier).setQuery,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Search saved colors',
            hintText: 'Name or HEX',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: filter.query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () =>
                        ref.read(historyFilterProvider.notifier).setQuery(''),
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              key: const ValueKey('favorites-filter'),
              label: const Text('Favorites only'),
              avatar: Icon(
                filter.favoritesOnly
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 20,
              ),
              selected: filter.favoritesOnly,
              showCheckmark: false,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: (_) =>
                  ref.read(historyFilterProvider.notifier).toggleFavorites(),
            ),
            if (colors.asData case final data?)
              Semantics(
                liveRegion: true,
                child: Text(
                  '${data.value.length} ${data.value.length == 1 ? 'color' : 'colors'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        colors.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading saved colors',
                value: MediaQuery.disableAnimationsOf(context) ? .7 : null,
              ),
            ),
          ),
          error: (_, _) => EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load your colors',
            message: 'Your library could not be opened. Please try again.',
            action: SecondaryButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: () {
                ref.read(colorHistoryProvider.notifier).retry();
              },
            ),
          ),
          data: (saved) {
            if (allColors?.isEmpty ?? saved.isEmpty) {
              return EmptyState(
                icon: Icons.bookmark_border_rounded,
                title: 'No saved colors yet',
                message:
                    'Explore a shade and save it to start your collection.',
                action: PrimaryButton(
                  label: 'Explore a color',
                  icon: Icons.add_rounded,
                  onPressed: () => showColorEntry(context),
                ),
              );
            }
            if (saved.isEmpty) {
              return EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matching colors',
                message: 'Try another name or HEX, or clear your filters.',
                action: SecondaryButton(
                  label: 'Clear filters',
                  onPressed: ref.read(historyFilterProvider.notifier).clear,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final color in saved) ...[
                  _SavedColorTile(
                    key: ValueKey('saved-${color.id}'),
                    color: color,
                    busy: _pending.contains(color.id),
                    onFavorite: () => _mutate(
                      color,
                      () => ref
                          .read(colorHistoryProvider.notifier)
                          .setFavorite(color.id, !color.isFavorite),
                    ),
                    onDelete: () => _delete(color),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                SecondaryButton(
                  label: 'Explore a color',
                  icon: Icons.add_rounded,
                  onPressed: () => showColorEntry(context),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SavedColorTile extends StatelessWidget {
  const _SavedColorTile({
    super.key,
    required this.color,
    required this.busy,
    required this.onFavorite,
    required this.onDelete,
  });

  final SavedColor color;
  final bool busy;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    void explore() => showColorDetails(
      context,
      RgbColor.fromHex(color.hex),
      source: color.source,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: context.appColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'Explore ${color.name}, ${color.hex}',
            button: true,
            onTap: explore,
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.medium),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('history-color-${color.id}'),
                onTap: explore,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: displayColor(RgbColor.fromHex(color.hex)),
                            borderRadius: BorderRadius.circular(AppRadii.small),
                            border: Border.all(
                              color: context.appColors.outline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              color.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(color.hex, style: AppTypography.mono),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'From ${color.source.name}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  key: ValueKey('favorite-${color.id}'),
                  tooltip: color.isFavorite
                      ? 'Remove ${color.name} from favorites'
                      : 'Add ${color.name} to favorites',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: busy ? null : onFavorite,
                  isSelected: color.isFavorite,
                  selectedIcon: const Icon(Icons.favorite_rounded),
                  icon: const Icon(Icons.favorite_border_rounded),
                ),
                IconButton(
                  key: ValueKey('delete-${color.id}'),
                  tooltip: 'Delete ${color.name}',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: busy ? null : onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
