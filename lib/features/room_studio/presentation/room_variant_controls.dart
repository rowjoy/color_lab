import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../application/room_mask_controller.dart';
import '../application/room_project_session_controller.dart';
import '../application/room_recolor_provider.dart';
import '../application/room_variant_controller.dart';
import '../domain/room_mask_state.dart';
import '../domain/room_project.dart';

String _failureText(BuildContext context, RoomVariantFailure failure) =>
    switch (failure) {
      RoomVariantFailure.invalidName => context.l10n.roomVariantInvalidName,
      RoomVariantFailure.duplicateName => context.l10n.roomVariantDuplicateName,
      RoomVariantFailure.limit => context.l10n.roomVariantLimit,
      RoomVariantFailure.finalVariant => context.l10n.roomVariantFinal,
      RoomVariantFailure.invalidId ||
      RoomVariantFailure.missing ||
      RoomVariantFailure.unavailable => context.l10n.roomVariantUnavailable,
    };

class RoomVariantControls extends ConsumerStatefulWidget {
  const RoomVariantControls({super.key});
  @override
  ConsumerState<RoomVariantControls> createState() =>
      _RoomVariantControlsState();
}

class _RoomVariantControlsState extends ConsumerState<RoomVariantControls> {
  RoomVariantFailure? _failure;
  bool _deleteChanged = false;
  bool _confirmingDelete = false;

  Future<void> _command(Future<void> Function() action) async {
    setState(() {
      _failure = null;
      _deleteChanged = false;
    });
    try {
      await action();
    } on RoomVariantException catch (error) {
      if (mounted) setState(() => _failure = error.failure);
    }
  }

  Future<void> _delete(RoomColorVariant variant) async {
    if (_confirmingDelete) return;
    final captured = ref.read(roomProjectSessionProvider);
    if (captured == null ||
        captured.variants.length < 2 ||
        !captured.variants.any((v) => identical(v, variant))) {
      return;
    }
    final survivor = captured.variants.firstWhere((v) => v.id != variant.id);
    final switchesSelection = captured.activeVariantId == variant.id;
    final clearsComparison = captured.comparisonBaselineVariantId == variant.id;
    _confirmingDelete = true;
    var confirmed = false;
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: Text(context.l10n.roomVariantDeleteTitle(variant.name)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.roomVariantDeleteConsequence(variant.name)),
              if (switchesSelection) ...[
                const SizedBox(height: 12),
                Text(context.l10n.roomVariantDeleteSelection(survivor.name)),
              ],
              if (clearsComparison) ...[
                const SizedBox(height: 12),
                Text(context.l10n.roomVariantDeleteBaseline),
              ],
            ],
          ),
          actions: [
            TextButton(
              key: const ValueKey('room-variant-delete-cancel'),
              onPressed: () {
                if (!confirmed) Navigator.pop(dialogContext, false);
              },
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: const ValueKey('room-variant-delete-confirm'),
              onPressed: () {
                // A second tap can arrive before the dialog's exit animation.
                if (confirmed) return;
                confirmed = true;
                Navigator.pop(dialogContext, true);
              },
              child: Text(context.l10n.roomVariantDelete),
            ),
          ],
        ),
      );
      if (!mounted || accepted != true) return;
      final current = ref.read(roomProjectSessionProvider);
      // Acknowledgements may change durable state while this dialog is open.
      // Reopen or any visible edit changes these immutable identities, so the
      // displayed target, survivor and baseline consequences must be reviewed.
      if (current == null ||
          current.projectId != captured.projectId ||
          !identical(current.variantSet, captured.variantSet) ||
          !identical(current.visible, captured.visible) ||
          current.name != captured.name ||
          !current.variants.any((v) => identical(v, variant))) {
        setState(() {
          _failure = null;
          _deleteChanged = true;
        });
        return;
      }
      await _command(
        () => ref.read(roomVariantProvider.notifier).deleteVariant(variant.id),
      );
    } finally {
      _confirmingDelete = false;
    }
  }

  Future<void> _name([RoomColorVariant? variant]) async {
    final project = ref.read(roomProjectSessionProvider)?.projectId;
    final name = TextEditingController(text: variant?.name ?? '');
    RoomVariantFailure? failure;
    var submitting = false;
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => PopScope(
          canPop: !submitting,
          child: AlertDialog(
            scrollable: true,
            title: Text(
              variant == null
                  ? context.l10n.roomVariantCreate
                  : context.l10n.roomVariantRename,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('room-variant-name'),
                  controller: name,
                  enabled: !submitting,
                  autofocus: true,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: context.l10n.roomVariantName,
                  ),
                ),
                if (failure != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(_failureText(context, failure!)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                key: const ValueKey('room-variant-submit'),
                onPressed: submitting
                    ? null
                    : () async {
                        // Guard immediately too: a second tap can precede the rebuild.
                        if (submitting) return;
                        update(() {
                          submitting = true;
                          failure = null;
                        });
                        try {
                          if (ref.read(roomProjectSessionProvider)?.projectId !=
                              project) {
                            throw const RoomVariantException(
                              RoomVariantFailure.unavailable,
                            );
                          }
                          final controller = ref.read(
                            roomVariantProvider.notifier,
                          );
                          // Command validation and visible publication happen synchronously.
                          // Close after it settles; project save status owns storage failures.
                          if (variant == null) {
                            await controller.createVariant(name.text);
                          } else {
                            await controller.renameVariant(
                              variant.id,
                              name.text,
                            );
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } on RoomVariantException catch (error) {
                          if (dialogContext.mounted) {
                            update(() {
                              submitting = false;
                              failure = error.failure;
                            });
                          }
                        }
                      },
                child: Text(context.l10n.roomVariantApply),
              ),
            ],
          ),
        ),
      ),
    );
    await Navigator.of(context, rootNavigator: true).push(route);
    // Keep the controller alive until the route's exit animation is disposed.
    await route.completed;
    name.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final set = ref.watch(roomVariantProvider);
    if (set == null) {
      return _deleteChanged
          ? Semantics(
              liveRegion: true,
              child: Text(context.l10n.roomVariantDeleteChanged),
            )
          : const SizedBox.shrink();
    }
    final editor = ref.watch(roomMaskProvider);
    final enabled = editor.stage == RoomMaskStage.ready && !editor.editBusy;
    final controller = ref.read(roomVariantProvider.notifier);
    return Column(
      key: const ValueKey('room-variant-controls'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.roomVariantsTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < set.variants.length; i++)
          Builder(
            builder: (context) {
              final variant = set.variants[i];
              final selected = variant.id == set.activeVariantId;
              final label = context.l10n.roomVariantLabel(
                i < 26 ? String.fromCharCode(65 + i) : '${i + 1}',
                variant.name,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      selected: selected,
                      child: OutlinedButton(
                        key: ValueKey('room-variant-select-${variant.id}'),
                        onPressed: enabled
                            ? () => _command(
                                () => controller.selectVariant(variant.id),
                              )
                            : null,
                        child: Text(
                          selected
                              ? context.l10n.roomVariantSelected(label)
                              : label,
                        ),
                      ),
                    ),
                    if (variant.id == set.comparisonBaselineVariantId)
                      Text(context.l10n.roomVariantBaseline(label)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          key: ValueKey('room-variant-rename-${variant.id}'),
                          onPressed: enabled ? () => _name(variant) : null,
                          child: Text(context.l10n.roomVariantRename),
                        ),
                        TextButton(
                          key: ValueKey('room-variant-pin-${variant.id}'),
                          onPressed: enabled
                              ? () => _command(
                                  () => controller.pinComparisonBaseline(
                                    variant.id,
                                  ),
                                )
                              : null,
                          child: Text(context.l10n.roomVariantPin),
                        ),
                        TextButton(
                          key: ValueKey('room-variant-delete-${variant.id}'),
                          onPressed: enabled && set.variants.length > 1
                              ? () => _delete(variant)
                              : null,
                          child: Text(context.l10n.roomVariantDelete),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              key: const ValueKey('room-variant-create'),
              onPressed: enabled ? () => _name() : null,
              child: Text(context.l10n.roomVariantCreate),
            ),
            if (set.comparisonBaselineVariantId != null)
              OutlinedButton(
                key: const ValueKey('room-comparison-clear'),
                onPressed: enabled
                    ? () => _command(controller.clearComparison)
                    : null,
                child: Text(context.l10n.roomComparisonClear),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          set.variants.length == 1
              ? context.l10n.roomComparisonNeedVariant
              : set.comparisonBaselineVariantId == set.activeVariantId
              ? context.l10n.roomComparisonSelectOther
              : context.l10n.roomComparisonGuide,
        ),
        if (_failure != null)
          Semantics(
            liveRegion: true,
            child: Text(_failureText(context, _failure!)),
          ),
        if (_deleteChanged)
          Semantics(
            liveRegion: true,
            child: Text(context.l10n.roomVariantDeleteChanged),
          ),
      ],
    );
  }
}

/// Local divider state never enters a project or a save intent. Both images use
/// full-image coordinates so changing the clip reveals a real aligned split.
class RoomComparisonPreview extends ConsumerStatefulWidget {
  const RoomComparisonPreview({super.key, this.showOriginal = false});
  final bool showOriginal;
  @override
  ConsumerState<RoomComparisonPreview> createState() =>
      _RoomComparisonPreviewState();
}

class _RoomComparisonPreviewState extends ConsumerState<RoomComparisonPreview> {
  double _divider = .5;
  final _sliderFocus = FocusNode();
  @override
  void dispose() {
    _sliderFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(roomProjectSessionProvider);
    final activeKey = roomActiveRecolorKey(session);
    final baselineKey = roomBaselineRecolorKey(session);
    if (session == null || activeKey == null || baselineKey == null) {
      return const SizedBox.shrink();
    }
    final active = ref.watch(roomRecolorPreviewProvider);
    final baseline = ref.watch(roomComparisonPreviewProvider);
    final ready =
        !active.isLoading &&
        !active.hasError &&
        !baseline.isLoading &&
        !baseline.hasError &&
        active.value?.key == activeKey &&
        baseline.value?.key == baselineKey;
    final draft = session.visible;
    final activeLabel = context.l10n.roomComparisonActive(
      session.variantSet.active.name,
    );
    final baselineLabel = context.l10n.roomComparisonBaseline(
      session.variantSet.baseline!.name,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.roomComparisonTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(activeLabel),
        Text(baselineLabel),
        if (widget.showOriginal)
          Image.memory(
            draft.photo.previewBytes,
            key: const ValueKey('room-comparison-original-image'),
            semanticLabel: context.l10n.roomComparisonOriginal,
          )
        else if (ready) ...[
          LayoutBuilder(
            builder: (context, constraints) => AspectRatio(
              aspectRatio: draft.photo.width / draft.photo.height,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) => setState(
                  () => _divider =
                      (details.localPosition.dx / constraints.maxWidth).clamp(
                        0,
                        1,
                      ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      baseline.value!.pngBytes,
                      key: const ValueKey('room-comparison-baseline-image'),
                      fit: BoxFit.contain,
                      semanticLabel: baselineLabel,
                      gaplessPlayback: false,
                    ),
                    ClipRect(
                      clipper: _DividerClipper(_divider),
                      child: Image.memory(
                        active.value!.pngBytes,
                        key: const ValueKey('room-comparison-active-image'),
                        fit: BoxFit.contain,
                        semanticLabel: activeLabel,
                        gaplessPlayback: false,
                      ),
                    ),
                    Positioned(
                      left: constraints.maxWidth * _divider - 1,
                      top: 0,
                      bottom: 0,
                      child: const IgnorePointer(
                        child: ColoredBox(
                          color: Colors.white,
                          child: SizedBox(width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Semantics(
            label: context.l10n.roomComparisonDivider,
            child: Slider(
              key: const ValueKey('room-comparison-divider'),
              focusNode: _sliderFocus,
              value: _divider,
              divisions: 100,
              semanticFormatterCallback: (value) =>
                  context.l10n.roomComparisonPosition((value * 100).round()),
              onChangeStart: (_) => _sliderFocus.requestFocus(),
              onChanged: (value) => setState(() => _divider = value),
            ),
          ),
        ] else ...[
          Semantics(
            liveRegion: true,
            child: Text(
              active.hasError || baseline.hasError
                  ? context.l10n.roomComparisonFailed
                  : context.l10n.roomComparisonUpdating,
            ),
          ),
          if (active.hasError || baseline.hasError)
            OutlinedButton(
              onPressed: () {
                ref.invalidate(roomRecolorPreviewProvider);
                ref.invalidate(roomComparisonPreviewProvider);
              },
              child: Text(context.l10n.tryAgain),
            ),
        ],
      ],
    );
  }
}

class _DividerClipper extends CustomClipper<Rect> {
  const _DividerClipper(this.fraction);
  final double fraction;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);
  @override
  bool shouldReclip(_DividerClipper oldClipper) =>
      fraction != oldClipper.fraction;
}
