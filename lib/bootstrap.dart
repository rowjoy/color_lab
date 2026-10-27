import 'package:flutter/material.dart';

import 'app.dart';

/// Mounts the router immediately; Room models stay lazy until a real-room
/// action explicitly requests them.
class ColorLabBootstrap extends StatelessWidget {
  const ColorLabBootstrap({super.key});

  @override
  Widget build(BuildContext context) => const ColorLabApp();
}
