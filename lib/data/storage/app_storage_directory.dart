import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

const legacyPrivateDataDirectoryName = 'color_lab';

Directory resolveAppStorageDirectory(Directory candidate) {
  final path = candidate.path;
  final normalized = path.replaceFirst(RegExp(r'[\\/]+$'), '');
  final separatorIndex = normalized.lastIndexOf(RegExp(r'[\\/]'));
  final finalComponent = normalized.substring(separatorIndex + 1);
  if (finalComponent == legacyPrivateDataDirectoryName) {
    return candidate;
  }
  final parent = normalized.isEmpty ? Platform.pathSeparator : normalized;
  return Directory(
    '$parent${parent.endsWith(Platform.pathSeparator) ? '' : Platform.pathSeparator}'
    '$legacyPrivateDataDirectoryName',
  );
}

final appStorageDirectoryProvider = FutureProvider<Directory>(
  (ref) async =>
      resolveAppStorageDirectory(await getApplicationDocumentsDirectory()),
  retry: (retryCount, error) => null,
);
