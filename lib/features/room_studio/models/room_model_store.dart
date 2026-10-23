import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path_provider/path_provider.dart';

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
  const RoomModelDownloadException({this.cancelled = false});
  final bool cancelled;
}

final class _Load {
  final result = Completer<RoomModelBytes>();
  HttpClient? client;
  bool cancelled = false;
}

/// No I/O occurs until load(). Files live in persistent app-private support
/// storage, never temporary cache. Only pinned, complete bytes reach inference.
final class RoomModelStore {
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

  int get _totalBytes => _artifacts.fold(0, (sum, a) => sum + a.bytes);
  RoomModelDownloadProgress get progress => _progress;
  Stream<RoomModelDownloadProgress> get changes => _changes.stream;

  Future<RoomModelBytes> load() {
    if (_closed) {
      return Future.error(const RoomModelDownloadException(cancelled: true));
    }
    final previous = _active;
    if (previous != null) {
      if (!previous.cancelled) return previous.result.future;
      // A retry waits for old I/O/partial cleanup; it never inherits cancellation.
      return previous.result.future.then(
        (_) => load(),
        onError: (Object _, StackTrace _) => load(),
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

  Future<bool> _valid(File file, RoomModelArtifact artifact) async {
    if (!await file.exists() || await file.length() != artifact.bytes) {
      return false;
    }
    final digest = await crypto.sha256.bind(file.openRead()).first;
    return digest.toString() == artifact.sha256;
  }

  Future<void> _run(_Load operation) async {
    var completed = 0;
    try {
      _emit(RoomModelDownloadStage.checking, 0);
      final root = await _directory();
      _check(operation);
      final files = <File>[];
      for (final artifact in _artifacts) {
        _check(operation);
        final file = File(
          '${root.path}/room_models/${artifact.sha256}/${artifact.name}',
        );
        if (!await _valid(file, artifact)) {
          _check(operation);
          await _download(operation, artifact, file, completed);
        }
        _check(operation);
        completed += artifact.bytes;
        files.add(file);
      }
      final semantic = await files[0].readAsBytes();
      final depth = await files[1].readAsBytes();
      _check(operation);
      _emit(RoomModelDownloadStage.ready, completed);
      operation.result.complete(
        RoomModelBytes(semantic: semantic, depth: depth),
      );
    } catch (error, stack) {
      final cancelled = _closed || operation.cancelled;
      _emit(
        cancelled
            ? RoomModelDownloadStage.cancelled
            : RoomModelDownloadStage.failed,
        completed,
      );
      operation.result.completeError(
        RoomModelDownloadException(cancelled: cancelled),
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
    await target.parent.create(recursive: true);
    _check(operation);
    if (await partial.exists()) await partial.delete();
    IOSink? sink;
    try {
      final client = operation.client ??= _clientFactory()
        ..connectionTimeout = _timeout;
      _emit(RoomModelDownloadStage.downloading, completed, artifact.name);
      final request = await client
          .getUrl(Uri.parse(artifact.url))
          .timeout(_timeout);
      _check(operation);
      final response = await request.close().timeout(_timeout);
      _check(operation);
      if (response.statusCode != HttpStatus.ok ||
          (response.contentLength >= 0 &&
              response.contentLength != artifact.bytes)) {
        throw const RoomModelDownloadException();
      }
      var received = 0;
      Stream<List<int>> chunks() async* {
        await for (final bytes in response.timeout(_timeout)) {
          _check(operation);
          received += bytes.length;
          if (received > artifact.bytes) {
            throw const RoomModelDownloadException();
          }
          _emit(
            RoomModelDownloadStage.downloading,
            completed + received,
            artifact.name,
          );
          yield bytes;
        }
      }

      sink = partial.openWrite();
      await sink.addStream(chunks());
      await sink.close();
      sink = null;
      _check(operation);
      if (received != artifact.bytes) throw const RoomModelDownloadException();
      _emit(
        RoomModelDownloadStage.verifying,
        completed + received,
        artifact.name,
      );
      if (!await _valid(partial, artifact)) {
        throw const RoomModelDownloadException();
      }
      _check(operation);
      await partial.rename(target.path);
    } finally {
      try {
        await sink?.close();
      } catch (_) {
        // A source-stream failure can also fail close(). Still remove its part.
      } finally {
        if (await partial.exists()) await partial.delete();
      }
    }
  }

  void cancel() {
    final operation = _active;
    if (operation == null || operation.cancelled) return;
    operation.cancelled = true;
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
