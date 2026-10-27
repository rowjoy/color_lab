import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/storage/local_data_manager.dart';
import '../../../l10n/l10n.dart';
import '../../room_studio/application/room_model_download_providers.dart';
import 'settings_page.dart';

class ModelStorageScreen extends ConsumerStatefulWidget {
  const ModelStorageScreen({super.key});
  @override
  ConsumerState<ModelStorageScreen> createState() => _ModelStorageScreenState();
}

class _ModelStorageScreenState extends ConsumerState<ModelStorageScreen> {
  LocalDataManifest? _inventory;
  bool _busy = true;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final inventory = await ref.read(roomModelStoreProvider).inventory();
      if (mounted) setState(() => _inventory = inventory);
    } catch (_) {
      if (mounted) setState(() => _message = context.l10n.modelsError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.modelsConfirm),
          content: Text(context.l10n.modelsIntro),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.modelsRemove),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await ref.read(roomModelStoreProvider).remove();
      if (!mounted) return;
      _message = context.l10n.modelsRemoved;
      await _load();
    } catch (_) {
      if (mounted) setState(() => _message = context.l10n.modelsRemovalError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(roomModelDownloadProgressProvider, (previous, next) {
      if (!_busy &&
          previous?.value?.busy == true &&
          next.value?.busy == false) {
        setState(() => _busy = true);
        _load();
      }
    });
    final progress = ref.watch(roomModelDownloadProgressProvider).value;
    final canRemove =
        (_inventory?.entries.isNotEmpty ?? false) || (progress?.busy ?? false);
    return SettingsPage(
      title: context.l10n.settingsModelsEntry,
      children: [
        Text(context.l10n.modelsIntro),
        const SizedBox(height: 24),
        if (_inventory != null)
          Text(
            _inventory!.entries.isEmpty
                ? context.l10n.modelsEmpty
                : context.l10n.modelsSummary(
                    _inventory!.entries.length,
                    _inventory!.estimatedBytes,
                  ),
          ),
        if (_message != null)
          Semantics(liveRegion: true, child: Text(_message!)),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy || !canRemove ? null : _remove,
          child: Text(context.l10n.modelsRemove),
        ),
        if (_message != null && !_busy)
          TextButton(
            onPressed: () {
              setState(() {
                _busy = true;
                _message = null;
              });
              _load();
            },
            child: Text(context.l10n.modelsRefresh),
          ),
        if (_busy) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
