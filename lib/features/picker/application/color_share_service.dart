import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/color/color_presentation.dart';

abstract interface class ColorShareService {
  Future<void> shareColor({
    required RgbColor color,
    String? name,
    required Rect origin,
  });
}

final colorShareServiceProvider = Provider<ColorShareService>(
  (ref) => PlatformColorShareService(),
);

class PlatformColorShareService implements ColorShareService {
  @override
  Future<void> shareColor({
    required RgbColor color,
    String? name,
    required Rect origin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        text: formatColorShare(color, name: name),
        title: 'Share color',
        subject: 'Color Lab ${color.hex}',
        sharePositionOrigin: origin,
      ),
    );
  }
}
