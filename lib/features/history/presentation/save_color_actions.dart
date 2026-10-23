import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../application/history_providers.dart';
import '../domain/saved_color.dart';

class SaveColorActions extends ConsumerStatefulWidget {
  const SaveColorActions({
    super.key,
    required this.color,
    required this.name,
    required this.source,
  });

  final RgbColor color;
  final String? name;
  final ColorSource source;

  @override
  ConsumerState<SaveColorActions> createState() => _SaveColorActionsState();
}

class _SaveColorActionsState extends ConsumerState<SaveColorActions> {
  bool _busy = false;
  String? _message;

  Future<void> _perform(
    Future<void> Function() action,
    String errorMessage,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      // Tactile feedback must not delay or misreport a durable storage result.
      unawaited(HapticFeedback.selectionClick().catchError((Object _) {}));
    } catch (_) {
      if (mounted) setState(() => _message = errorMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(colorHistoryProvider);
    if (history.hasError && !history.hasValue) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Your saved colors couldn't be opened. Please try again.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: 'Retry storage',
            icon: Icons.refresh_rounded,
            onPressed: () => ref.read(colorHistoryProvider.notifier).retry(),
          ),
        ],
      );
    }
    final saved = history.asData?.value
        .where((color) => color.hex == widget.color.hex)
        .firstOrNull;
    final loading =
        history.isLoading || _busy || (saved == null && widget.name == null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_message != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              _message!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (saved == null)
          PrimaryButton(
            label: 'Save color',
            icon: Icons.bookmark_add_outlined,
            isLoading: loading,
            onPressed: loading
                ? null
                : () => _perform(() async {
                    await ref
                        .read(colorHistoryProvider.notifier)
                        .saveColor(
                          widget.color,
                          name: widget.name!,
                          source: widget.source,
                        );
                  }, "Couldn't save this color. Try again."),
          )
        else ...[
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Saved to library',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: saved.isFavorite ? 'In your favorites' : 'Add to favorites',
            icon: saved.isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            isLoading: _busy,
            onPressed: _busy
                ? null
                : () => _perform(
                    () => ref
                        .read(colorHistoryProvider.notifier)
                        .setFavorite(saved.id, !saved.isFavorite),
                    "Couldn't update this favorite. Try again.",
                  ),
          ),
        ],
      ],
    );
  }
}
