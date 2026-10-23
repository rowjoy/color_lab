import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import 'saved_palettes_section.dart';

class SavedPalettesScreen extends StatelessWidget {
  const SavedPalettesScreen({super.key, this.returnToHarmony = false});
  final bool returnToHarmony;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Saved palettes'),
      leading: IconCircleButton(
        icon: Icons.arrow_back_rounded,
        label: 'Back',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/palette');
          }
        },
      ),
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const ValueKey('screen-SavedPalettes'),
        padding: AppSpacing.screenPadding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SavedPalettesSection(returnToHarmony: returnToHarmony),
          ),
        ),
      ),
    ),
  );
}
