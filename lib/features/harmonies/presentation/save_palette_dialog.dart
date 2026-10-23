import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../palette/application/saved_palettes_providers.dart';
import '../../palette/domain/saved_palette.dart';

Future<SavedPalette?> showSavePaletteDialog(
  BuildContext context, {
  required RgbColor base,
  required HarmonyMode mode,
  required List<RgbColor> colors,
}) => showDialog<SavedPalette>(
  context: context,
  builder: (_) => _SavePaletteDialog(
    base: base,
    mode: mode,
    colors: List.unmodifiable(colors),
  ),
);

class _SavePaletteDialog extends ConsumerStatefulWidget {
  const _SavePaletteDialog({
    required this.base,
    required this.mode,
    required this.colors,
  });
  final RgbColor base;
  final HarmonyMode mode;
  final List<RgbColor> colors;

  @override
  ConsumerState<_SavePaletteDialog> createState() => _SavePaletteDialogState();
}

class _SavePaletteDialogState extends ConsumerState<_SavePaletteDialog> {
  late final _name = TextEditingController(text: '${widget.mode.label} study');
  String? _nameError, _saveError;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Give this palette a name.');
      return;
    }
    setState(() {
      _busy = true;
      _nameError = null;
      _saveError = null;
    });
    try {
      // These widget values are the captured recipe, not a later live draft.
      final saved = await ref
          .read(savedPalettesProvider.notifier)
          .savePalette(
            name: name,
            base: widget.base,
            mode: widget.mode,
            colors: widget.colors,
          );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted) {
        setState(() => _saveError = "Couldn't save this palette. Try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: const Text('Save palette'),
      content: SizedBox(
        width: AppSpacing.huge * 6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.mode.label} · ${widget.colors.length} shades',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const ValueKey('palette-name-input'),
              controller: _name,
              enabled: !_busy,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Palette name',
                errorText: _nameError,
                errorMaxLines: 3,
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              onSubmitted: (_) => _save(),
            ),
            if (_saveError != null) ...[
              Semantics(liveRegion: true, child: Text(_saveError!)),
              const SizedBox(height: AppSpacing.lg),
            ],
            PrimaryButton(
              key: const ValueKey('confirm-save-palette'),
              label: 'Save',
              isLoading: _busy,
              onPressed: _busy ? null : _save,
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: 'Cancel',
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
