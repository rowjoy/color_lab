import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../history/application/history_providers.dart';
import '../../history/domain/saved_color.dart';

/// Chooses an ingredient without changing the mixer draft or saved library.
Future<RgbColor?> showMixerColorPicker(
  BuildContext context, {
  RgbColor? initialColor,
}) => showModalBottomSheet<RgbColor>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  sheetAnimationStyle: AppMotion.sheetAnimation(context),
  builder: (_) => MixerColorPicker(initialColor: initialColor),
);

class MixerColorPicker extends ConsumerStatefulWidget {
  const MixerColorPicker({super.key, this.initialColor});

  final RgbColor? initialColor;

  @override
  ConsumerState<MixerColorPicker> createState() => _MixerColorPickerState();
}

class _MixerColorPickerState extends ConsumerState<MixerColorPicker> {
  late final TextEditingController _hex = TextEditingController(
    text: widget.initialColor?.hex ?? '#6C5CE7',
  );
  String _query = '';
  String? _error;

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final color = RgbColor.fromHex(_hex.text.trim());
      Navigator.of(context).pop(color);
    } on FormatException {
      setState(() => _error = 'Enter a 3 or 6 digit HEX color.');
    }
  }

  Widget _savedLibrary(List<SavedColor> colors) {
    final matches = colors
        .where(
          (color) =>
              color.name.toLowerCase().contains(_query) ||
              color.hex.toLowerCase().contains(_query),
        )
        .toList();
    if (colors.isEmpty) return const Text('No saved colors yet.');
    if (matches.isEmpty) return const Text('No matching saved colors.');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: ListView.builder(
        shrinkWrap: true,
        primary: false,
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final saved = matches[index];
          final rgb = RgbColor.fromHex(saved.hex);
          return ListTile(
            key: ValueKey('mixer-saved-${saved.hex}'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            minTileHeight: AppSpacing.huge,
            leading: Container(
              width: AppSpacing.huge,
              height: AppSpacing.huge,
              decoration: BoxDecoration(
                color: Color.fromARGB(255, rgb.red, rgb.green, rgb.blue),
                borderRadius: BorderRadius.circular(AppRadii.small),
                border: Border.all(color: context.appColors.outline),
              ),
            ),
            title: Text(saved.name),
            subtitle: Text(saved.hex, style: AppTypography.mono),
            onTap: () => Navigator.of(context).pop(rgb),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(colorHistoryProvider);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: math.max(
                0,
                math.min(
                  constraints.maxHeight - keyboard,
                  MediaQuery.sizeOf(context).height * .9,
                ),
              ),
            ),
            child: SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Choose a color',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconCircleButton(
                        icon: Icons.close_rounded,
                        label: 'Close color picker',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextField(
                    key: const ValueKey('mixer-hex-input'),
                    controller: _hex,
                    decoration: InputDecoration(
                      labelText: 'HEX color',
                      hintText: '#6C5CE7',
                      errorText: _error,
                      errorMaxLines: 3,
                    ),
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(label: 'Use this color', onPressed: _submit),
                  const SizedBox(height: AppSpacing.xxl),
                  Semantics(
                    header: true,
                    child: Text(
                      'Saved library',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const ValueKey('mixer-library-search'),
                    decoration: const InputDecoration(
                      labelText: 'Search saved colors',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    autocorrect: false,
                    onChanged: (query) =>
                        setState(() => _query = query.trim().toLowerCase()),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  history.when(
                    data: _savedLibrary,
                    loading: () => Align(
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Loading saved colors',
                        value: MediaQuery.disableAnimationsOf(context)
                            ? .7
                            : null,
                      ),
                    ),
                    error: (_, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Could not load your saved colors.'),
                        const SizedBox(height: AppSpacing.md),
                        SecondaryButton(
                          label: 'Retry library',
                          onPressed: () =>
                              ref.read(colorHistoryProvider.notifier).retry(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
