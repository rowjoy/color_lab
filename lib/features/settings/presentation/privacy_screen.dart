import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'settings_page.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => SettingsPage(
    title: context.l10n.settingsPrivacyEntry,
    children: [
      Text(context.l10n.privacyBody),
      const SizedBox(height: 24),
      Text(context.l10n.privacyLibraries),
      const SizedBox(height: 24),
      Text(context.l10n.privacyControls),
    ],
  );
}
