import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/color/color_engine.dart';

final roomColorProvider = NotifierProvider<RoomColorController, RgbColor>(
  RoomColorController.new,
);

class RoomColorController extends Notifier<RgbColor> {
  @override
  RgbColor build() => RgbColor.fromHex('#A7B5A0');
  void setColor(RgbColor color) => state = color;
}
