import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../application/theme_mode_provider.dart';

enum _SettingsAction { replay }

Future<void> showAppSettings(BuildContext context) async {
  final action = await showModalBottomSheet<_SettingsAction>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: AppMotion.sheetAnimation(context),
    builder: (_) => const SettingsSheet(),
  );
  if (context.mounted && action == _SettingsAction.replay) {
    await context.push('/welcome');
  }
}

class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});
  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  bool _saving = false;
  String? _error;

  Future<void> _setMode(ThemeMode? mode) async {
    if (_saving || mode == null || mode == ref.read(themeModeProvider)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(themeModeProvider.notifier).setMode(mode);
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't save your appearance. Try again.");
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Make yourself at home',
                  subtitle: 'Choose your canvas.',
                ),
              ),
              IconCircleButton(
                icon: Icons.close_rounded,
                label: 'Close settings',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          RadioGroup<ThemeMode>(
            groupValue: ref.watch(themeModeProvider),
            onChanged: _setMode,
            child: Column(
              children: [
                for (final mode in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    enabled: !_saving,
                    title: Text(switch (mode) {
                      ThemeMode.system => 'Follow system',
                      ThemeMode.light => 'Light',
                      ThemeMode.dark => 'Dark',
                    }),
                    value: mode,
                  ),
              ],
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              _saving
                  ? 'Saving appearance…'
                  : 'Your choice is saved on this device.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appColors.textPrimary,
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            title: 'A little orientation',
            subtitle: 'A fresh look at the basics, whenever you like.',
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: 'Replay welcome tour',
            icon: Icons.auto_awesome_outlined,
            onPressed: _saving
                ? null
                : () => Navigator.of(context).pop(_SettingsAction.replay),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            title: 'Your colors stay yours',
            subtitle:
                'Photos, saved colors and preferences stay on your device. No account or cloud upload is needed.',
          ),
          const SizedBox(height: AppSpacing.lg),
          const AboutListTile(
            icon: Icon(Icons.info_outline_rounded),
            applicationName: 'Color Lab',
            applicationVersion: '1.0.0',
            child: Text('About Color Lab & licenses'),
          ),
        ],
      ),
    ),
  );
}
