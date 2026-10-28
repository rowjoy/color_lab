import '../../../core/color/color_models.dart';

final class ColoringEdit {
  const ColoringEdit({
    required this.regionId,
    required this.before,
    required this.after,
  });

  factory ColoringEdit.fromMap(Object? value) {
    if (value is! Map ||
        value.keys.toSet().difference({
          'regionId',
          'before',
          'after',
        }).isNotEmpty ||
        !value.containsKey('regionId') ||
        !value.containsKey('before') ||
        !value.containsKey('after') ||
        value['regionId'] is! String) {
      throw const FormatException('Invalid coloring edit.');
    }
    final before = value['before'];
    final after = value['after'];
    if (before != null && before is! String ||
        after != null && after is! String) {
      throw const FormatException('Invalid coloring edit color.');
    }
    return ColoringEdit(
      regionId: value['regionId'] as String,
      before: before == null ? null : RgbColor.fromHex(before as String),
      after: after == null ? null : RgbColor.fromHex(after as String),
    );
  }

  final String regionId;
  final RgbColor? before;
  final RgbColor? after;

  Map<String, Object?> toMap() => {
    'regionId': regionId,
    'before': before?.hex,
    'after': after?.hex,
  };
}
