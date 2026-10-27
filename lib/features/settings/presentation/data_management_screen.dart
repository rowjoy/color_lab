import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/storage/local_data_manager.dart';
import '../../../l10n/l10n.dart';
import '../application/local_data_providers.dart';
import 'settings_page.dart';

class DataManagementScreen extends ConsumerStatefulWidget {
  const DataManagementScreen({super.key});
  @override
  ConsumerState<DataManagementScreen> createState() =>
      _DataManagementScreenState();
}

class _DataManagementScreenState extends ConsumerState<DataManagementScreen> {
  final _selected = <LocalDataCategory>{};
  DataDeletionPreview? _preview;
  bool _busy = false;
  String? _message;

  Future<bool> _confirm({
    required bool destructive,
    required DataDeletionPreview preview,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(
            destructive
                ? context.l10n.dataConfirmTitle
                : context.l10n.dataReviewTitle,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final category in preview.categories)
                Text(categoryLabel(context.l10n, category)),
              const SizedBox(height: 16),
              Text(
                context.l10n.dataPreviewSummary(
                  preview.recordCount,
                  preview.estimatedBytes,
                ),
              ),
              if (preview.revisionCount > 0)
                Text(
                  context.l10n.dataRoomProjectRevisionSummary(
                    preview.revisionCount,
                  ),
                ),
              if (destructive) ...[
                const SizedBox(height: 16),
                Text(context.l10n.dataConfirmBody),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: ValueKey(destructive ? 'confirm-data' : 'review-data'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                destructive
                    ? context.l10n.dataDelete
                    : context.l10n.dataContinue,
              ),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _review() async {
    if (_busy || _selected.isEmpty) return;
    final selected = Set<LocalDataCategory>.of(_selected);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final manager = ref.read(localDataManagerProvider);
      final preview = await manager.preview(selected);
      if (!mounted) return;
      setState(() => _preview = preview);
      if (!await _confirm(destructive: false, preview: preview) || !mounted) {
        return;
      }
      if (!await _confirm(destructive: true, preview: preview) || !mounted) {
        return;
      }
      await manager.delete(selected);
      if (!mounted) return;
      refreshDeletedData(ref, selected);
      setState(() {
        _preview = null;
        _selected.clear();
        _message = context.l10n.dataSuccess;
      });
    } catch (_) {
      if (mounted) setState(() => _message = context.l10n.dataError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SettingsPage(
    canLeave: !_busy,
    title: context.l10n.settingsDataEntry,
    children: [
      Text(context.l10n.dataIntro),
      const SizedBox(height: 16),
      for (final category in LocalDataCategory.values)
        CheckboxListTile(
          key: ValueKey('category-${category.name}'),
          contentPadding: EdgeInsets.zero,
          value: _selected.contains(category),
          title: Text(categoryLabel(context.l10n, category)),
          subtitle: category.available
              ? null
              : Text(context.l10n.dataUnavailable),
          onChanged: _busy || !category.available
              ? null
              : (value) => setState(() {
                  if (value == true) {
                    _selected.add(category);
                  } else {
                    _selected.remove(category);
                  }
                  _preview = null;
                  _message = null;
                }),
        ),
      const SizedBox(height: 16),
      if (_preview != null && !_busy)
        Text(
          context.l10n.dataPreviewSummary(
            _preview!.recordCount,
            _preview!.estimatedBytes,
          ),
        ),
      if (_preview != null && !_busy && _preview!.revisionCount > 0)
        Text(
          context.l10n.dataRoomProjectRevisionSummary(_preview!.revisionCount),
        ),
      if (_message != null) Semantics(liveRegion: true, child: Text(_message!)),
      FilledButton(
        key: const ValueKey('preview-data'),
        onPressed: _busy || _selected.isEmpty ? null : _review,
        child: Text(context.l10n.dataPreview),
      ),
      if (_busy) const Center(child: CircularProgressIndicator()),
    ],
  );
}

String categoryLabel(AppLocalizations l10n, LocalDataCategory category) =>
    switch (category) {
      LocalDataCategory.preferences => l10n.dataPreferences,
      LocalDataCategory.savedColors => l10n.dataSavedColors,
      LocalDataCategory.savedPalettes => l10n.dataSavedPalettes,
      LocalDataCategory.illustratedRooms => l10n.dataIllustratedRooms,
      LocalDataCategory.gameProfiles => l10n.dataGames,
      LocalDataCategory.modelCache => l10n.dataModels,
      LocalDataCategory.roomProjects => l10n.dataRoomProjects,
      LocalDataCategory.coloringProjects => l10n.dataColoringProjects,
      LocalDataCategory.learningProgress => l10n.dataLearningProgress,
    };
