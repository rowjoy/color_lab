import 'package:flutter/widgets.dart';

class ColorLabelScope extends InheritedWidget {
  const ColorLabelScope({
    super.key,
    required this.alwaysShow,
    required super.child,
  });
  final bool alwaysShow;
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ColorLabelScope>()
          ?.alwaysShow ??
      false;
  @override
  bool updateShouldNotify(ColorLabelScope oldWidget) =>
      alwaysShow != oldWidget.alwaysShow;
}
