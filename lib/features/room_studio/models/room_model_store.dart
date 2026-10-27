import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path_provider/path_provider.dart';
import '../../../data/storage/local_data_manager.dart';

const roomModelArtifacts = [
  RoomModelArtifact(
    name: 'room_seg.tflite',
    url:
        'https://github.com/rowjoy/color_lab/releases/download/room-models-v1/room_seg.tflite',
    bytes: 1978000,
    sha256: 'da8b3822a22fde45ecaf0ff32022287eff58b500096971b04f3c1b292da66a3c',
  ),
  RoomModelArtifact(
    name: 'room_depth.tflite',
    url:
        'https://github.com/rowjoy/color_lab/releases/download/room-models-v1/room_depth.tflite',
    bytes: 66338288,
    sha256: '93d871071edff1218973ce25ee27ce95ccd20450c70a55e1b89efa3f5a772cdd',
  ),
];

final class RoomModelArtifact {
  const RoomModelArtifact({
    required this.name,
    required this.url,
    required this.bytes,
    required this.sha256,
  });

  final String name;
  final String url;
  final int bytes;
  final String sha256;
}

final class RoomModelBytes {
  const RoomModelBytes({required this.semantic, required this.depth});
  final Uint8List semantic;
  final Uint8List depth;
}

enum RoomModelDownloadStage {
  idle,
  checking,
  downloading,
  verifying,
  ready,
  failed,
  storageFull,
  cancelled,
}

final class RoomModelDownloadProgress {
  const RoomModelDownloadProgress({
    required this.stage,
    required this.receivedBytes,
    required this.totalBytes,
    this.modelName,
  });

  final RoomModelDownloadStage stage;
  final int receivedBytes;
  final int totalBytes;
  final String? modelName;

  double get fraction => totalBytes == 0 ? 0 : receivedBytes / totalBytes;
  bool get busy => switch (stage) {
    RoomModelDownloadStage.checking ||
    RoomModelDownloadStage.downloading ||
    RoomModelDownloadStage.verifying => true,
    _ => false,
  };
}

final class RoomModelDownloadException implements Exception {
  const RoomModelDownloadException({
    this.cancelled = false,
    this.storageFull = false,
  });
  final bool cancelled;
  final bool storageFull;
}

final class _Load {
  final result = Completer<List<File>>();
  HttpClient? client;
  bool cancelled = false;
}

/// No I/O occurs until prepare()/load(). Files live in persistent app-private support
/// storage, never temporary cache. Only pinned, complete bytes reach inference.
final class RoomModelStore implements LocalDataOwner {
  RoomModelStore({
    Future<Directory> Function()? directory,
    List<RoomModelArtifact> artifacts = roomModelArtifacts,
    HttpClient Function()? clientFactory,
    Duration timeout = const Duration(seconds: 30),
  }) : _directory = directory ?? getApplicationSupportDirectory,
       _artifacts = List.unmodifiable(artifacts),
       _clientFactory = clientFactory ?? HttpClient.new,
       _timeout = timeout {
    if (_artifacts.length != 2 ||
        _artifacts[0].name != 'room_seg.tflite' ||
        _artifacts[1].name != 'room_depth.tflite' ||
        _artifacts.any(
          (a) => a.bytes <= 0 || !RegExp(r'^[a-f0-9]{64}$').hasMatch(a.sha256),
        )) {
      throw ArgumentError('Expected pinned room segmentation and depth models');
    }
    _progress = RoomModelDownloadProgress(
      stage: RoomModelDownloadStage.idle,
      receivedBytes: 0,
      totalBytes: _totalBytes,
    );
  }

  final Future<Directory> Function() _directory;
  final List<RoomModelArtifact> _artifacts;
  final HttpClient Function() _clientFactory;
  final Duration _timeout;
  final _changes = StreamController<RoomModelDownloadProgress>.broadcast();
  late RoomModelDownloadProgress _progress;
  _Load? _active;
  bool _closed = false;
  int _cancellationGeneration = 0;
  Future<void> _maintenance = Future.value();
  bool _maintaining = false;

  /// Enumerates only pinned model files and their partials. Never creates files,
  /// verifies a model for inference, or initiates a network request.
  Future<LocalDataManifest> inventory() async {
    final files = await _ownedFiles();
    final entries = <String, String>{};
    var bytes = 0;
    for (final file in files) {
      final size = await file.length();
      final digest = await crypto.sha256.bind(file.openRead()).first;
      entries[file.path] = '$size:$digest';
      bytes += size;
    }
    return LocalDataManifest(entries, bytes);
  }

  Future<List<File>> _ownedFiles() async {
    final root = await _directory();
    final modelRoot = Directory('${root.path}/room_models');
    // Never follow a redirected cache directory or file into user storage.
    if (await FileSystemEntity.type(modelRoot.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const LocalDataException();
    }
    final files = <File>[];
    for (final artifact in _artifacts) {
      final directory = '${modelRoot.path}/${artifact.sha256}';
      if (await FileSystemEntity.type(directory, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const LocalDataException();
      }
      for (final suffix in ['', '.part']) {
        final file = File('$directory/${artifact.name}$suffix');
        final type = await FileSystemEntity.type(file.path, followLinks: false);
        if (type == FileSystemEntityType.link) throw const LocalDataException();
        if (type == FileSystemEntityType.file) files.add(file);
      }
    }
    return files;
  }

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _maintenance.then((_) async {
      if (_closed) throw const LocalDataException();
      _maintaining = true;
      try {
        return await action();
      } finally {
        _maintaining = false;
      }
    });
    _maintenance = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  @override
  Future<T> withMaintenance<T>(
    Future<T> Function(LocalDataLease) action,
  ) => _exclusive(() async {
    // Exact previews must not silently cancel downloads. A busy cache can
    // be removed explicitly from Model storage or reviewed after completion.
    if (_active != null) throw const LocalDataException();
    return action(_ModelLease(this));
  });

  Future<void> _erase(LocalDataManifest manifest) async {
    if (!manifest.sameAs(await inventory())) throw const LocalDataException();
    cancel();
    for (final file in await _ownedFiles()) {
      if (manifest.entries.containsKey(file.path)) await file.delete();
    }
    _emit(RoomModelDownloadStage.idle, 0);
  }

  /// Exclusive explicit removal cancels and drains old I/O before enumerating
  /// its files. New prepares fail while removal owns the cache.
  Future<void> remove() => _exclusive(() async {
    final active = _active;
    cancel();
    try {
      await active?.result.future;
    } catch (_) {
      /* cancelled work */
    }
    await _erase(await inventory());
  });

  int get _totalBytes => _artifacts.fold(0, (sum, a) => sum + a.bytes);
  RoomModelDownloadProgress get progress => _progress;
  Stream<RoomModelDownloadProgress> get changes => _changes.stream;
  int get cancellationGeneration => _cancellationGeneration;

  /// Cache-only availability: never constructs a client or promotes a partial.
  Future<bool> check() async {
    if (_closed || _maintaining) {
      throw const RoomModelDownloadException(cancelled: true);
    }
    final generation = _cancellationGeneration;
    _emit(RoomModelDownloadStage.checking, 0);
    try {
      final files = await _checkedFiles(await _directory());
      var completed = 0;
      for (var index = 0; index < _artifacts.length; index++) {
        final artifact = _artifacts[index];
        final file = files[index];
        if (!await _valid(file, artifact)) {
          if (!_closed && generation == _cancellationGeneration) {
            _emit(RoomModelDownloadStage.idle, completed);
          }
          return false;
        }
        completed += artifact.bytes;
      }
      if (_closed || generation != _cancellationGeneration) {
        throw const RoomModelDownloadException(cancelled: true);
      }
      _emit(RoomModelDownloadStage.ready, completed);
      return true;
    } catch (error) {
      final cancelled = _closed || generation != _cancellationGeneration;
      final capacity = _isCapacity(error);
      if (!cancelled) {
        _emit(
          capacity
              ? RoomModelDownloadStage.storageFull
              : RoomModelDownloadStage.failed,
          0,
        );
      }
      throw RoomModelDownloadException(
        cancelled: cancelled,
        storageFull: capacity,
      );
    }
  }

  static bool _isCapacity(Object error) {
    if (error is! FileSystemException) return false;
    // Errno values overlap across operating systems. Only native no-space and
    // disk-quota codes may turn an I/O failure into storage-full guidance.
    final codes = Platform.isWindows
        ? const {39, 112, 1295}
        : Platform.isMacOS || Platform.isIOS
        ? const {28, 69}
        : const {28, 122};
    return codes.contains(error.osError?.errorCode);
  }

  /// Explicitly downloads missing files without allocating inference buffers.
  Future<void> prepare() async {
    await _prepareFiles();
  }

  Future<RoomModelBytes> load() async {
    final generation = _cancellationGeneration;
    final files = await _prepareFiles();
    try {
      await _assertBoundary(files[0]);
      final semantic = await files[0].readAsBytes();
      await _assertBoundary(files[0]);
      await _assertBoundary(files[1]);
      final depth = await files[1].readAsBytes();
      await _assertBoundary(files[1]);
      if (_closed || generation != _cancellationGeneration) {
        throw const RoomModelDownloadException(cancelled: true);
      }
      return RoomModelBytes(semantic: semantic, depth: depth);
    } on RoomModelDownloadException {
      rethrow;
    } catch (_) {
      throw RoomModelDownloadException(
        cancelled: _closed || generation != _cancellationGeneration,
      );
    }
  }

  Future<List<File>> _prepareFiles() {
    if (_closed || _maintaining) {
      return Future.error(const RoomModelDownloadException(cancelled: true));
    }
    final previous = _active;
    if (previous != null) {
      if (!previous.cancelled) return previous.result.future;
      // A retry waits for old I/O/partial cleanup; it never inherits cancellation.
      final generation = _cancellationGeneration;
      Future<List<File>> retryIfCurrent() {
        if (generation != _cancellationGeneration) {
          return Future.error(
            const RoomModelDownloadException(cancelled: true),
          );
        }
        return _prepareFiles();
      }

      return previous.result.future.then(
        (_) => retryIfCurrent(),
        onError: (Object _, StackTrace _) => retryIfCurrent(),
      );
    }
    final operation = _Load();
    _active = operation;
    unawaited(_run(operation));
    return operation.result.future;
  }

  void _check(_Load operation) {
    if (_closed || operation.cancelled) {
      throw const RoomModelDownloadException(cancelled: true);
    }
  }

  void _emit(RoomModelDownloadStage stage, int received, [String? name]) {
    _progress = RoomModelDownloadProgress(
      stage: stage,
      receivedBytes: received,
      totalBytes: _totalBytes,
      modelName: name,
    );
    if (!_closed) _changes.add(_progress);
  }

  /// Check every owned component without following links, before touching any
  /// artifact. The support directory itself is supplied by the app; these are
  /// the cache-owned descendants, which must never redirect into other data.
  Future<List<File>> _checkedFiles(Directory root) async {
    final files = [
      for (final artifact in _artifacts)
        File('${root.path}/room_models/${artifact.sha256}/${artifact.name}'),
    ];
    for (final file in files) {
      await _assertBoundary(file);
    }
    return files;
  }

  Future<void> _assertBoundary(File target) async {
    for (final entry in [
      (target.parent.parent.path, FileSystemEntityType.directory),
      (target.parent.path, FileSystemEntityType.directory),
      (target.path, FileSystemEntityType.file),
      ('${target.path}.part', FileSystemEntityType.file),
    ]) {
      final type = await FileSystemEntity.type(entry.$1, followLinks: false);
      if (type != FileSystemEntityType.notFound && type != entry.$2) {
        throw const RoomModelDownloadException();
      }
    }
  }

  File _finalTarget(File file) => file.path.endsWith('.part')
      ? File(file.path.substring(0, file.path.length - 5))
      : file;

  Future<bool> _valid(File file, RoomModelArtifact artifact) async {
    await _assertBoundary(_finalTarget(file));
    if (!await file.exists() || await file.length() != artifact.bytes) {
      return false;
    }
    final digest = await crypto.sha256.bind(file.openRead()).first;
    await _assertBoundary(_finalTarget(file));
    return digest.toString() == artifact.sha256;
  }

  Future<void> _run(_Load operation) async {
    var completed = 0;
    try {
      _emit(RoomModelDownloadStage.checking, 0);
      final root = await _directory();
      _check(operation);
      final files = await _checkedFiles(root);
      for (var index = 0; index < _artifacts.length; index++) {
        _check(operation);
        final artifact = _artifacts[index];
        final file = files[index];
        if (!await _valid(file, artifact)) {
          _check(operation);
          await _download(operation, artifact, file, completed);
        }
        _check(operation);
        completed += artifact.bytes;
      }
      _check(operation);
      _emit(RoomModelDownloadStage.ready, completed);
      operation.result.complete(files);
    } catch (error, stack) {
      final cancelled = _closed || operation.cancelled;
      if (!cancelled) {
        _emit(
          _isCapacity(error)
              ? RoomModelDownloadStage.storageFull
              : RoomModelDownloadStage.failed,
          completed,
        );
      }
      operation.result.completeError(
        RoomModelDownloadException(
          cancelled: cancelled,
          storageFull: _isCapacity(error),
        ),
        stack,
      );
    } finally {
      operation.client?.close(force: true);
      if (identical(_active, operation)) _active = null;
    }
  }

  Future<void> _download(
    _Load operation,
    RoomModelArtifact artifact,
    File target,
    int completed,
  ) async {
    final partial = File('${target.path}.part');
    await _assertBoundary(target);
    _check(operation);
    await target.parent.create(recursive: true);
    await _assertBoundary(target);
    _check(operation);
    var offset = await partial.exists() ? await partial.length() : 0;
    _check(operation);
    if (offset > artifact.bytes) {
      await partial.delete();
      offset = 0;
    }
    if (offset == artifact.bytes) {
      _emit(
        RoomModelDownloadStage.verifying,
        completed + offset,
        artifact.name,
      );
      if (!await _valid(partial, artifact)) {
        await partial.delete();
        throw const RoomModelDownloadException();
      }
      _check(operation);
      await _assertBoundary(target);
      _check(operation);
      await partial.rename(target.path);
      return;
    }
    _check(operation);
    final client = operation.client ??= _clientFactory()
      ..connectionTimeout = _timeout
      ..autoUncompress = false;
    var cleanFallback = false;
    while (true) {
      _check(operation);
      _emit(
        RoomModelDownloadStage.downloading,
        completed + offset,
        artifact.name,
      );
      final request = await client
          .getUrl(Uri.parse(artifact.url))
          .timeout(_timeout);
      _check(operation);
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (offset > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
      }
      final response = await request.close().timeout(_timeout);
      _check(operation);
      final ranges = response.headers[HttpHeaders.contentRangeHeader];
      final range = ranges != null && ranges.length == 1 ? ranges.single : null;
      final match = range == null
          ? null
          : RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(range);
      final validRange =
          offset > 0 &&
          response.statusCode == HttpStatus.partialContent &&
          match != null &&
          int.tryParse(match[1]!) == offset &&
          int.tryParse(match[2]!) == artifact.bytes - 1 &&
          int.tryParse(match[3]!) == artifact.bytes &&
          (response.contentLength < 0 ||
              response.contentLength == artifact.bytes - offset);
      final validFull =
          response.statusCode == HttpStatus.ok &&
          (response.contentLength < 0 ||
              response.contentLength == artifact.bytes);
      if (!validRange && !validFull) {
        await response.listen((_) {}).cancel();
        if (offset > 0 && !cleanFallback) {
          offset = 0;
          cleanFallback = true;
          continue;
        }
        throw const RoomModelDownloadException();
      }
      // A server ignoring Range supplies a full response. Truncate before
      // consuming that same response, never append it to the retained prefix.
      if (validFull) offset = 0;
      var received = offset;
      var oversize = false;
      // Network waits allow other app work to run. Recheck immediately before
      // opening a writer, and again before promotion; old validation is not a
      // permission to follow a subsequently replaced cache entry.
      await _assertBoundary(target);
      _check(operation);
      final sink = partial.openWrite(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      try {
        Stream<List<int>> chunks() async* {
          await for (final bytes in response.timeout(_timeout)) {
            _check(operation);
            received += bytes.length;
            if (received > artifact.bytes) {
              oversize = true;
              throw const RoomModelDownloadException();
            }
            yield bytes;
            _check(operation);
            _emit(
              RoomModelDownloadStage.downloading,
              completed + received,
              artifact.name,
            );
          }
        }

        await sink.addStream(chunks());
        await sink.flush();
      } finally {
        try {
          await sink.close();
        } finally {
          if (oversize && await partial.exists()) await partial.delete();
        }
      }
      _check(operation);
      if (received != artifact.bytes) throw const RoomModelDownloadException();
      _emit(
        RoomModelDownloadStage.verifying,
        completed + received,
        artifact.name,
      );
      if (!await _valid(partial, artifact)) {
        await partial.delete();
        throw const RoomModelDownloadException();
      }
      _check(operation);
      await _assertBoundary(target);
      _check(operation);
      await partial.rename(target.path);
      return;
    }
  }

  void cancel() {
    // Also invalidate setup that is still awaiting the bundled descriptor and
    // has not reached load() yet. A subsequent explicit request gets a new epoch.
    _cancellationGeneration++;
    final operation = _active;
    if (operation == null || operation.cancelled) return;
    operation.cancelled = true;
    _emit(
      RoomModelDownloadStage.cancelled,
      _progress.receivedBytes,
      _progress.modelName,
    );
    operation.client?.close(force: true);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final operation = _active;
    cancel();
    try {
      await operation?.result.future;
    } catch (_) {
      // Disposal consumes its own cancelled operation, not a new request.
    }
    await _changes.close();
  }
}

final class _ModelLease implements LocalDataLease {
  _ModelLease(this.store);
  final RoomModelStore store;
  @override
  Future<LocalDataManifest> inventory() => store.inventory();
  @override
  Future<void> erase(LocalDataManifest manifest) => store._erase(manifest);
}
