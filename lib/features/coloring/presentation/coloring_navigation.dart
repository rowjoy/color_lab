import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../learning/domain/learning_palette_copy.dart';

Future<void> openLearningPaletteInColoring(
  BuildContext context,
  LearningPaletteCopy palette,
) => context.push<void>('/coloring', extra: palette);
