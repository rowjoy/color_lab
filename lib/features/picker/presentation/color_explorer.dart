import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/color/color_presentation.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/assets/color_name_asset_loader.dart';
import '../../history/domain/saved_color.dart';
import '../../history/presentation/save_color_actions.dart';
import '../../room_studio/application/room_color_provider.dart';
import '../../formula/application/formula_providers.dart';
import '../../harmonies/application/harmony_controller.dart';
import '../application/color_share_service.dart';

final colorNamerProvider = FutureProvider<ColorNamer>(
  (ref) => ColorNameAssetLoader().load(),
);

Color displayColor(RgbColor color) =>
    Color.fromARGB(255, color.red, color.green, color.blue);

Future<void> showColorDetails(
  BuildContext context,
  RgbColor color, {
  ColorSource source = ColorSource.manual,
  Object? heroTag,
  Future<void> Function()? onOpenHarmonies,
}) async {
  var selected = color;
  // Replace the sheet on harmony selection: repeated exploration never grows
  // an unbounded navigator stack. A PageRoute allows a real swatch Hero flight.
  while (context.mounted) {
    final routeColor = selected;
    final routeHeroTag = heroTag;
    final route = PageRouteBuilder<_DetailAction>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: .55),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: AppMotion.duration(context),
      reverseTransitionDuration: AppMotion.duration(context),
      pageBuilder: (routeContext, animation, secondaryAnimation) => SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Theme.of(routeContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.large),
            ),
            clipBehavior: Clip.antiAlias,
            child: ColorDetails(
              color: routeColor,
              source: source,
              heroTag: routeHeroTag,
              onHarmony: (next) => Navigator.of(
                routeContext,
              ).pop(_DetailAction(next, _DetailDestination.neighbor)),
              onRoom: () => Navigator.of(
                routeContext,
              ).pop(_DetailAction(routeColor, _DetailDestination.room)),
              onFormula: () => Navigator.of(
                routeContext,
              ).pop(_DetailAction(routeColor, _DetailDestination.formula)),
              onHarmonies: () => Navigator.of(
                routeContext,
              ).pop(_DetailAction(routeColor, _DetailDestination.harmonies)),
            ),
          ),
        ),
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  ),
                ),
            child: child,
          ),
    );
    final result = await Navigator.of(context).push<_DetailAction>(route);
    await route.completed;
    if (!context.mounted || result == null) return;
    if (result.destination == _DetailDestination.formula) {
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(formulaTargetProvider.notifier).setColor(result.color);
      if (GoRouterState.of(context).uri.path != '/formula') {
        await context.push<void>('/formula');
      }
      return;
    }
    if (result.destination == _DetailDestination.harmonies) {
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(harmonyDraftProvider.notifier).setBase(result.color);
      // Collections opened by an editor can return to that existing editor.
      // The selected base is updated above for either navigation policy.
      if (onOpenHarmonies != null) {
        await onOpenHarmonies();
      } else if (GoRouterState.of(context).uri.path != '/harmonies') {
        await context.push<void>('/harmonies');
      }
      return;
    }
    if (result.destination == _DetailDestination.room) {
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(roomColorProvider.notifier).setColor(result.color);
      context.go('/room');
      return;
    }
    selected = result.color;
    heroTag = null;
  }
}

enum _DetailDestination { neighbor, room, formula, harmonies }

class _DetailAction {
  const _DetailAction(this.color, this.destination);
  final RgbColor color;
  final _DetailDestination destination;
}

Future<void> showColorEntry(BuildContext context) async {
  final color = await showModalBottomSheet<RgbColor>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: AppMotion.sheetAnimation(context),
    builder: (_) => const _ColorEntry(),
  );
  if (color != null && context.mounted) await showColorDetails(context, color);
}

class _ColorEntry extends StatefulWidget {
  const _ColorEntry();

  @override
  State<_ColorEntry> createState() => _ColorEntryState();
}

class _ColorEntryState extends State<_ColorEntry> {
  final _controller = TextEditingController(text: '#6C5CE7');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      Navigator.of(context).pop(RgbColor.fromHex(_controller.text.trim()));
    } on FormatException {
      setState(() => _error = 'Enter a 3 or 6 digit HEX color.');
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.xxl,
      AppSpacing.xxl,
      AppSpacing.xxl,
      AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Start with a shade',
            subtitle: 'Enter any HEX color to get to know it.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          TextField(
            key: const ValueKey('hex-input'),
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'HEX color',
              hintText: '#6C5CE7',
              errorText: _error,
            ),
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            maxLength: 7,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'View color',
            onPressed: _submit,
            icon: Icons.arrow_forward_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    ),
  );
}

class ColorDetails extends ConsumerStatefulWidget {
  const ColorDetails({
    super.key,
    required this.color,
    this.source = ColorSource.manual,
    this.heroTag,
    this.onHarmony,
    this.onRoom,
    this.onFormula,
    this.onHarmonies,
  });
  final RgbColor color;
  final ColorSource source;
  final Object? heroTag;
  final ValueChanged<RgbColor>? onHarmony;
  final VoidCallback? onRoom;
  final VoidCallback? onFormula;
  final VoidCallback? onHarmonies;
  @override
  ConsumerState<ColorDetails> createState() => _ColorDetailsState();
}

class _ColorDetailsState extends ConsumerState<ColorDetails> {
  bool _sharing = false;
  String? _shareError;

  Future<void> _share(BuildContext anchor, String? name) async {
    if (_sharing) return;
    final box = anchor.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _sharing = true;
      _shareError = null;
    });
    try {
      await ref
          .read(colorShareServiceProvider)
          .shareColor(color: widget.color, name: name, origin: origin);
    } catch (_) {
      if (mounted) {
        setState(
          () => _shareError = 'Could not share this color. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final name = ref
        .watch(colorNamerProvider)
        .asData
        ?.value
        .nearest(color)
        .name;
    final swatch = Container(
      height: MediaQuery.sizeOf(context).height * .4,
      decoration: BoxDecoration(
        color: displayColor(color),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.large),
        ),
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                if (widget.heroTag != null)
                  Hero(tag: widget.heroTag!, child: swatch)
                else
                  swatch,
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: IconCircleButton(
                    icon: Icons.close_rounded,
                    label: 'Close color details',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    name ?? 'Your color',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'A closer look. Tap any value to copy.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SaveColorActions(
                    color: color,
                    source: widget.source,
                    name: name,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  for (final value in colorFormatValues(color).entries)
                    ValueRow(label: value.key, value: value.value),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(
                    title: 'In good company',
                    subtitle: 'Neighboring hues and a complementary shade.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final harmony in detailHarmony(color))
                        SizedBox(
                          key: ValueKey('harmony-${harmony.hex}'),
                          child: ColorChip(
                            color: displayColor(harmony),
                            label: harmony.hex,
                            onTap: widget.onHarmony == null
                                ? null
                                : () => widget.onHarmony!(harmony),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Builder(
                    builder: (anchor) => SecondaryButton(
                      label: 'Share color',
                      icon: Icons.ios_share_rounded,
                      isLoading: _sharing,
                      onPressed: () => _share(anchor, name),
                    ),
                  ),
                  if (_shareError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _shareError!,
                          style: TextStyle(color: context.appColors.error),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    label: 'Find color formula',
                    icon: Icons.science_outlined,
                    onPressed: widget.onFormula,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    label: 'Explore harmonies',
                    icon: Icons.palette_outlined,
                    onPressed: widget.onHarmonies,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    label: 'Use in Room',
                    icon: Icons.chair_outlined,
                    onPressed: widget.onRoom,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
