import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/buttons.dart';
import '../application/illustrated_room_controller.dart';
import '../application/room_designs_providers.dart';
import '../domain/illustrated_room.dart';
import '../domain/saved_room_design.dart';

Future<void> showSavedRoomDesigns(
  BuildContext context, {
  required Future<bool> Function(SavedRoomDesign) onOpen,
  String? initialTemplateId,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  sheetAnimationStyle: AppMotion.sheetAnimation(context),
  builder: (context) => SavedRoomDesignsSheet(
    initialTemplateId: initialTemplateId,
    onOpen: onOpen,
  ),
);

Future<SavedRoomDesign?> showSaveRoomDesignDialog(
  BuildContext context, {
  required String initialName,
  String? templateId,
}) => showDialog<SavedRoomDesign>(
  context: context,
  useRootNavigator: true,
  builder: (context) => _RoomDesignNameDialog.save(
    initialName: initialName,
    templateId: templateId,
  ),
);

class SavedRoomDesignsSheet extends StatelessWidget {
  const SavedRoomDesignsSheet({
    super.key,
    required this.onOpen,
    this.initialTemplateId,
  });

  final Future<bool> Function(SavedRoomDesign) onOpen;
  final String? initialTemplateId;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * .88;
    return SizedBox(
      height: height,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'My room designs',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconCircleButton(
                    icon: Icons.close_rounded,
                    label: 'Close room designs',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: SavedRoomDesignsList(
                  initialTemplateId: initialTemplateId,
                  onOpen: (design) async {
                    final opened = await onOpen(design);
                    if (opened && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SavedRoomDesignsList extends ConsumerStatefulWidget {
  const SavedRoomDesignsList({
    super.key,
    required this.onOpen,
    this.initialTemplateId,
  });

  final Future<void> Function(SavedRoomDesign) onOpen;
  final String? initialTemplateId;

  @override
  ConsumerState<SavedRoomDesignsList> createState() =>
      _SavedRoomDesignsListState();
}

class _SavedRoomDesignsListState extends ConsumerState<SavedRoomDesignsList> {
  late String? _templateId;
  String? _openingDesignId;

  String? _validTemplateId(String? value) =>
      IllustratedRoomCatalog.maybeById(value ?? '') == null ? null : value;

  @override
  void initState() {
    super.initState();
    _templateId = _validTemplateId(widget.initialTemplateId);
  }

  @override
  void didUpdateWidget(SavedRoomDesignsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTemplateId != widget.initialTemplateId) {
      _templateId = _validTemplateId(widget.initialTemplateId);
    }
  }

  Future<void> _openDesign(SavedRoomDesign design) async {
    if (_openingDesignId != null) return;
    setState(() => _openingDesignId = design.id);
    try {
      await widget.onOpen(design);
    } finally {
      if (mounted) setState(() => _openingDesignId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final designs = ref.watch(savedRoomDesignsProvider);
    final count = designs.asData?.value.length ?? 0;
    final filterHeight = math.min(
      88.0,
      math.max(52.0, 32 + MediaQuery.textScalerOf(context).scale(16)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: count == 1 ? '1 saved design' : '$count saved designs',
          child: SizedBox(
            height: filterHeight,
            child: ListView(
              key: const ValueKey('room-design-filters'),
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  key: const ValueKey('room-design-filter-all'),
                  label: 'All',
                  selected: _templateId == null,
                  onSelected: () => setState(() => _templateId = null),
                ),
                for (final template in IllustratedRoomCatalog.all) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _FilterChip(
                    key: ValueKey('room-design-filter-${template.id}'),
                    label: _roomFilterLabel(template),
                    selected: _templateId == template.id,
                    onSelected: () => setState(() => _templateId = template.id),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: designs.when(
            data: (items) {
              final visible = _templateId == null
                  ? items
                  : items
                        .where((design) => design.templateId == _templateId)
                        .toList(growable: false);
              if (items.isEmpty) return const _EmptyDesigns();
              if (visible.isEmpty) {
                final room = IllustratedRoomCatalog.maybeById(_templateId!)!;
                return Center(
                  child: Text(
                    'No saved ${_roomFilterLabel(room).toLowerCase()} designs yet.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.separated(
                key: const ValueKey('room-design-list'),
                itemCount: visible.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) => _SavedDesignRow(
                  design: visible[index],
                  onOpen: _openDesign,
                  openEnabled: _openingDesignId == null,
                  opening: _openingDesignId == visible[index].id,
                ),
              );
            },
            loading: () => Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading room designs',
                value: MediaQuery.disableAnimationsOf(context) ? .7 : null,
              ),
            ),
            error: (error, stackTrace) => _LibraryError(
              onRetry: () =>
                  ref.read(savedRoomDesignsProvider.notifier).retry(),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) {
        if (value || !selected) onSelected();
      },
    ),
  );
}

class _SavedDesignRow extends ConsumerWidget {
  const _SavedDesignRow({
    required this.design,
    required this.onOpen,
    required this.openEnabled,
    required this.opening,
  });

  final SavedRoomDesign design;
  final Future<void> Function(SavedRoomDesign) onOpen;
  final bool openEnabled;
  final bool opening;

  Future<void> _rename(BuildContext context) async {
    await showDialog<SavedRoomDesign>(
      context: context,
      useRootNavigator: true,
      builder: (context) => _RoomDesignNameDialog.rename(
        initialName: design.name,
        designId: design.id,
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: const Text('Delete this design?'),
        content: Text('“${design.name}” will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('room-confirm-delete'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _performDelete(context, ref);
    }
  }

  Future<void> _performDelete(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;
    try {
      await ref.read(illustratedRoomProvider.notifier).deleteDesign(design.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not delete this room design.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              if (context.mounted) {
                unawaited(_performDelete(context, ref));
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = IllustratedRoomCatalog.maybeById(design.templateId);
    final available = template != null;
    return Semantics(
      container: true,
      enabled: available && openEnabled,
      liveRegion: opening,
      value: opening ? 'Opening' : null,
      child: Material(
        color: context.appColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          side: BorderSide(color: context.appColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('room-design-row-${design.id}'),
          onTap: available && openEnabled ? () async => onOpen(design) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            design.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            available
                                ? '${template.title} · ${_shortDate(design.updatedAt)}'
                                : 'Temporarily unavailable',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: context.appColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: ValueKey('room-design-rename-${design.id}'),
                      tooltip: 'Rename ${design.name}',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: openEnabled ? () => _rename(context) : null,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      key: ValueKey('room-design-delete-${design.id}'),
                      tooltip: 'Delete ${design.name}',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: openEnabled
                          ? () => _delete(context, ref)
                          : null,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final surface in IllustratedRoomSurface.values)
                      _DesignSwatch(
                        key: ValueKey(
                          'room-design-swatch-${design.id}-${surface.name}',
                        ),
                        label:
                            template?.surfaceLabels.labelFor(surface) ??
                            _fallbackSurfaceLabel(surface),
                        color: design.colors.colorFor(surface),
                      ),
                  ],
                ),
                if (opening) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const LinearProgressIndicator(
                    semanticsLabel: 'Opening room design',
                    value: .65,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomDesignNameDialog extends ConsumerStatefulWidget {
  const _RoomDesignNameDialog._({
    required this.initialName,
    required this.designId,
    required this.templateId,
  });

  const _RoomDesignNameDialog.save({
    required String initialName,
    String? templateId,
  }) : this._(initialName: initialName, designId: null, templateId: templateId);

  const _RoomDesignNameDialog.rename({
    required String initialName,
    required String designId,
  }) : this._(initialName: initialName, designId: designId, templateId: null);

  final String initialName;
  final String? designId;
  final String? templateId;

  @override
  ConsumerState<_RoomDesignNameDialog> createState() =>
      _RoomDesignNameDialogState();
}

class _RoomDesignNameDialogState extends ConsumerState<_RoomDesignNameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  String? _validationError;
  String? _storageError;
  bool _isSaving = false;

  bool get _isRename => widget.designId != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty || name.runes.length > 60) {
      setState(() {
        _validationError = 'Enter 1–60 characters.';
        _storageError = null;
      });
      return;
    }
    setState(() {
      _validationError = null;
      _storageError = null;
      _isSaving = true;
    });
    try {
      final saved = _isRename
          ? await ref
                .read(illustratedRoomProvider.notifier)
                .renameDesign(widget.designId!, name)
          : await ref
                .read(illustratedRoomProvider.notifier)
                .saveDesign(name, templateId: widget.templateId);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _storageError = _isRename
            ? 'Could not rename this room design.'
            : 'Could not save your room design.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_isRename ? 'Rename room design' : 'Save room design'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: ValueKey(
              _isRename ? 'room-design-rename-input' : 'room-design-name-input',
            ),
            controller: _name,
            autofocus: true,
            enabled: !_isSaving,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Design name',
              errorText: _validationError,
            ),
            onChanged: (_) {
              if (_validationError != null || _storageError != null) {
                setState(() {
                  _validationError = null;
                  _storageError = null;
                });
              }
            },
            onSubmitted: (_) {
              if (!_isSaving) _submit();
            },
          ),
          if (_storageError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              label: _storageError,
              excludeSemantics: true,
              child: Text(
                _storageError!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.error,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        key: ValueKey(_isRename ? 'room-confirm-rename' : 'room-confirm-save'),
        onPressed: _isSaving ? null : _submit,
        child: Text(_isSaving ? 'Saving…' : (_isRename ? 'Rename' : 'Save')),
      ),
    ],
  );
}

class _DesignSwatch extends StatelessWidget {
  const _DesignSwatch({super.key, required this.label, required this.color});

  final String label;
  final RgbColor color;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label, ${color.hex}',
    excludeSemantics: true,
    child: Container(
      constraints: const BoxConstraints(minWidth: 92, minHeight: 38),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: context.appColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _display(color),
              shape: BoxShape.circle,
              border: Border.all(color: context.appColors.outline),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  color.hex,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: context.appColors.textSecondary,
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

class _EmptyDesigns extends StatelessWidget {
  const _EmptyDesigns();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.collections_bookmark_outlined,
          size: 48,
          color: context.appColors.textSecondary,
        ),
        const SizedBox(height: AppSpacing.md),
        const Text('No saved room designs yet.'),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Choose colors in the room editor, then save your design here.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          label: 'Could not load your room designs.',
          excludeSemantics: true,
          child: const Text('Could not load your room designs.'),
        ),
        const SizedBox(height: AppSpacing.md),
        SecondaryButton(
          key: const ValueKey('room-designs-retry'),
          label: 'Retry',
          onPressed: onRetry,
        ),
      ],
    ),
  );
}

String _fallbackSurfaceLabel(IllustratedRoomSurface surface) =>
    switch (surface) {
      IllustratedRoomSurface.wall => 'Wall',
      IllustratedRoomSurface.ceiling => 'Ceiling',
      IllustratedRoomSurface.floor => 'Floor',
      IllustratedRoomSurface.furniture => 'Furniture',
    };

String _roomFilterLabel(IllustratedRoomTemplate template) =>
    template.title.endsWith(' room')
    ? template.title.substring(0, template.title.length - 5)
    : template.title;

String _shortDate(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)}';
}

Color _display(RgbColor color) =>
    Color.fromARGB(255, color.red, color.green, color.blue);
