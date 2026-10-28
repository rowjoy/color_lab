/// Validates schema-1 path data without depending on Flutter geometry.
List<List<Object>> validateVectorPathCommands(
  Object? value, {
  required double width,
  required double height,
  required bool fillable,
}) {
  Never fail(String message) => throw FormatException(message);
  if (value is! List) fail('Expected command list');
  final commands = <List<Object>>[];
  var started = false;
  var closed = true;
  for (final raw in value) {
    if (raw is! List || raw.isEmpty) fail('Invalid command');
    final arity = const {'M': 2, 'L': 2, 'Q': 4, 'C': 6, 'Z': 0}[raw[0]];
    if (arity == null || raw.length != arity + 1) {
      fail('Unsupported command/arity');
    }
    final op = raw[0] as String;
    if (!started && op != 'M') fail('Path must start with M');
    if (op == 'M') {
      if (fillable && !closed) fail('Unclosed contour');
      started = true;
      closed = false;
    } else if (closed) {
      fail('Command after Z needs M');
    }
    final command = <Object>[op];
    for (var i = 1; i < raw.length; i++) {
      final coordinate = raw[i];
      final maximum = i.isOdd ? width : height;
      if (coordinate is! num ||
          !coordinate.isFinite ||
          coordinate < 0 ||
          coordinate > maximum) {
        fail('Coordinate/dimension out of bounds');
      }
      command.add(coordinate.toDouble());
    }
    if (op == 'Z') closed = true;
    commands.add(command);
  }
  if (!started || (fillable && !closed)) fail('Empty/unclosed fill');
  return commands;
}
