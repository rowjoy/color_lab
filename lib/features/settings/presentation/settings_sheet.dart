import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
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
        setState(() => _error = context.l10n.settingsSaveError);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SectionHeader(
                    title: l10n.settingsAppearanceTitle,
                    subtitle: l10n.settingsAppearanceSubtitle,
                  ),
                ),
                IconCircleButton(
                  icon: Icons.close_rounded,
                  label: l10n.closeSettings,
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
                        ThemeMode.system => l10n.themeFollowSystem,
                        ThemeMode.light => l10n.themeLight,
                        ThemeMode.dark => l10n.themeDark,
                      }),
                      value: mode,
                    ),
                ],
              ),
            ),
            Semantics(
              liveRegion: true,
              child: Text(
                _saving ? l10n.savingAppearance : l10n.appearanceSavedOnDevice,
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
            SectionHeader(
              title: l10n.settingsOrientationTitle,
              subtitle: l10n.settingsOrientationSubtitle,
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: l10n.replayWelcomeTour,
              icon: Icons.auto_awesome_outlined,
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).pop(_SettingsAction.replay),
            ),
            const SizedBox(height: AppSpacing.xxl),
            SectionHeader(
              title: l10n.settingsPrivacyTitle,
              subtitle: l10n.settingsPrivacySubtitle,
            ),
            const SizedBox(height: AppSpacing.lg),
            AboutListTile(
              icon: const Icon(Icons.info_outline_rounded),
              applicationName: l10n.appName,
              applicationVersion: '1.0.0',
              child: Text(l10n.aboutAndLicenses(l10n.appName)),
            ),
          ],
        ),
      ),
    );
  }
}
