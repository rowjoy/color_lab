import 'dart:io';

/// Keeps inventory and filesystem writes real; fails only the chosen delete.
/// Install with IOOverrides.runWithIOOverrides, or temporarily as the global
/// override when Flutter callbacks must remain in the binding's original zone.
final class FailingModelRemovalIO extends IOOverrides {
  FailingModelRemovalIO({required this.ownedPaths, required this.failOn});
  final Set<String> ownedPaths;
  final String failOn;
  final List<String> deletedPaths = [];
  bool enabled = true;

  @override
  File createFile(String path) {
    final file = super.createFile(path);
    return ownedPaths.contains(path) ? _RemovalFile(file, this) : file;
  }

  // All fixture paths are regular files/directories. Use the native stat
  // boundary: the SDK's base IOOverrides.fseGetType reports these as missing.
  @override
  Future<FileSystemEntityType> fseGetType(
    String path,
    bool followLinks,
  ) async => (await super.stat(path)).type;
}

final class _RemovalFile implements File {
  _RemovalFile(this.delegate, this.boundary);
  final File delegate;
  final FailingModelRemovalIO boundary;
  @override
  String get path => delegate.path;
  @override
  Future<int> length() => delegate.length();
  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) =>
      delegate.open(mode: mode);
  @override
  Stream<List<int>> openRead([int? start, int? end]) =>
      delegate.openRead(start, end);
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    if (boundary.enabled && path == boundary.failOn) {
      throw FileSystemException('injected private removal failure', path);
    }
    final result = await delegate.delete(recursive: recursive);
    boundary.deletedPaths.add(path);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
