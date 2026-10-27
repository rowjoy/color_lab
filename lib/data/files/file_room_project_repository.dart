import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../features/room_studio/data/room_project_codec.dart';
import '../../features/room_studio/domain/room_project.dart';
import '../../features/room_studio/domain/room_project_repository.dart';
import '../schema/corrupt_record.dart';
import '../schema/repository_snapshot.dart';
import '../schema/schema_registry.dart';
import '../storage/local_data_manager.dart';

/// The filesystem mutation boundary. All paths are checked by the owner before
/// calling it; flush/close errors propagate without acknowledging a revision.
class RoomProjectFileIo {
  const RoomProjectFileIo();

  Future<void> writeFlushed(String path, Uint8List bytes) async {
    final handle = await File(path).open(mode: FileMode.writeOnly);
    try {
      await handle.writeFrom(bytes);
      await handle.flush();
    } finally {
      await handle.close();
    }
  }

  Future<void> renameFile(String source, String destination) async {
    await File(source).rename(destination);
  }

  Future<void> renameDirectory(String source, String destination) async {
    await Directory(source).rename(destination);
  }

  Future<void> removeFile(String path) async {
    await File(path).delete();
  }

  Future<void> removeLink(String path) async {
    await Link(path).delete();
  }

  Future<void> removeDirectory(String path) async {
    await Directory(path).delete();
  }
}

final class _Queue {
  Future<void> pending = Future.value();
  int owners = 0;
  Future<T> run<T>(Future<T> Function() action) {
    final result = pending.then((_) => action());
    pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

/// Owns only `<private color_lab root>/room_projects`. Files are flushed before
/// atomically replacing `current`. This guarantees process-interruption
/// recovery, not device power-loss durability (Dart has no directory-fsync
/// barrier here). All app access to this tree uses one serialized owner queue.
final class FileRoomProjectRepository
    implements RoomProjectRepository, LocalDataOwner {
  FileRoomProjectRepository._(this._root, this._io, this._queue);
  static final _queues = <String, _Queue>{};
  static const _codec = RoomProjectCodec();
  static final _random = Random.secure();

  static Future<FileRoomProjectRepository> open({
    required String directory,
    RoomProjectFileIo io = const RoomProjectFileIo(),
  }) async {
    try {
      final base = Directory(directory).absolute;
      final baseType = await FileSystemEntity.type(
        base.path,
        followLinks: false,
      );
      if (baseType == FileSystemEntityType.link ||
          (baseType != FileSystemEntityType.directory &&
              baseType != FileSystemEntityType.notFound)) {
        throw const RoomProjectStorageException(
          RoomProjectStorageFailure.invalidId,
        );
      }
      await base.create(recursive: true);
      // Resolve the trusted application-storage parent once (e.g. iOS/macOS
      // system aliases). No component inside the owned tree follows links.
      final root =
          '${await base.resolveSymbolicLinks()}/${SchemaRegistry.roomProjects.storageName}';
      final queue = _queues.putIfAbsent(root, _Queue.new);
      queue.owners++;
      final repository = FileRoomProjectRepository._(root, io, queue);
      try {
        await queue.run(() async {
          await repository._ensureDirectory('');
          await repository._ensureDirectory('projects');
          await repository._collectOrphans();
        });
      } catch (_) {
        await repository.close();
        rethrow;
      }
      return repository;
    } on RoomProjectStorageException {
      rethrow;
    } catch (_) {
      throw const RoomProjectStorageException();
    }
  }

  final String _root;
  final RoomProjectFileIo _io;
  final _Queue _queue;
  Future<void>? _closing;

  Future<T> _serialize<T>(Future<T> Function() action) {
    if (_closing != null) {
      return Future.error(
        const RoomProjectStorageException(RoomProjectStorageFailure.closed),
      );
    }
    return _queue.run(() async {
      try {
        return await action();
      } on RoomProjectConflict {
        rethrow;
      } on RoomProjectStorageException {
        rethrow;
      } on FormatException {
        throw const RoomProjectStorageException(
          RoomProjectStorageFailure.corrupt,
        );
      } catch (_) {
        throw const RoomProjectStorageException();
      }
    });
  }

  static void _checkId(String id) {
    if (!RoomProjectLimits.validId(id)) {
      throw const RoomProjectStorageException(
        RoomProjectStorageFailure.invalidId,
      );
    }
  }

  String _absolute(String relative) =>
      relative.isEmpty ? _root : '$_root/$relative';

  Future<void> _checkParent() async {
    // The canonical app-storage parent must not be redirected after open.
    // Checking only room_projects would miss a symlink in its parent path.
    final ancestors = <Directory>[];
    var directory = Directory(_root).parent;
    while (directory.path != directory.parent.path) {
      ancestors.add(directory);
      directory = directory.parent;
    }
    for (final ancestor in ancestors.reversed) {
      if (await FileSystemEntity.type(ancestor.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const RoomProjectStorageException(
          RoomProjectStorageFailure.corrupt,
        );
      }
    }
  }

  /// Checks every existing owned ancestor, not only the final filename.
  Future<FileSystemEntityType> _type(
    String relative, {
    bool allowFinalLink = false,
  }) async {
    await _checkParent();
    final components = relative.isEmpty ? <String>[] : relative.split('/');
    if (components.any(
      (c) =>
          c == '.' ||
          c == '..' ||
          !RegExp(r'^[A-Za-z0-9_.-]{1,180}$').hasMatch(c),
    )) {
      throw const RoomProjectStorageException(
        RoomProjectStorageFailure.invalidId,
      );
    }
    var path = _root;
    for (var i = 0; i <= components.length; i++) {
      final type = await FileSystemEntity.type(path, followLinks: false);
      final last = i == components.length;
      if (type == FileSystemEntityType.link && !(last && allowFinalLink)) {
        throw const RoomProjectStorageException(
          RoomProjectStorageFailure.corrupt,
        );
      }
      if (last || type == FileSystemEntityType.notFound) return type;
      if (type != FileSystemEntityType.directory) {
        throw const FormatException('Invalid owned directory.');
      }
      path = '$path/${components[i]}';
    }
    throw const FormatException('Invalid owned path.');
  }

  Future<void> _ensureDirectory(String relative) async {
    final parts = relative.isEmpty ? <String>[] : relative.split('/');
    for (var i = 0; i <= parts.length; i++) {
      final prefix = parts.take(i).join('/');
      final type = await _type(prefix);
      if (type == FileSystemEntityType.notFound) {
        await Directory(_absolute(prefix)).create();
      } else if (type != FileSystemEntityType.directory) {
        throw const FormatException('Invalid owned directory.');
      }
    }
  }

  Future<Uint8List> _readBytes(String relative, int maxBytes) async {
    if (await _type(relative) != FileSystemEntityType.file) {
      throw const FormatException('Missing project file.');
    }
    final handle = await File(_absolute(relative)).open();
    try {
      final length = await handle.length();
      if (length < 1 || length > maxBytes) {
        throw const FormatException('Project file exceeds bounds.');
      }
      final bytes = await handle.read(length + 1);
      if (bytes.length != length) {
        throw const FormatException('Project file changed while reading.');
      }
      return bytes;
    } finally {
      await handle.close();
    }
  }

  Future<void> _writeNew(String relative, Uint8List bytes) async {
    if (await _type(relative) != FileSystemEntityType.notFound) {
      throw const FormatException('Immutable file already exists.');
    }
    await _io.writeFlushed(_absolute(relative), bytes);
  }

  Future<_Pointer?> _pointer(String id) async {
    _checkId(id);
    final path = 'projects/$id/current';
    if (await _type(path) == FileSystemEntityType.notFound) return null;
    return _Pointer.decode(
      await _readBytes(path, RoomProjectLimits.maxPointerBytes),
      id,
    );
  }

  Future<RoomProjectManifest> _manifest(String id, _Acknowledged entry) async {
    final bytes = await _readBytes(
      'projects/$id/revisions/${entry.revision}/manifest.json',
      RoomProjectLimits.maxManifestBytes,
    );
    if (sha256.convert(bytes).toString() != entry.manifestHash) {
      throw const FormatException('Manifest checksum mismatch.');
    }
    final manifest = _codec.readManifest(bytes);
    if (manifest.projectId != id || manifest.revision != entry.revision) {
      throw const FormatException('Manifest identity mismatch.');
    }
    return manifest;
  }

  Future<RoomProjectReadResult?> _read(String id) async {
    final _Pointer? pointer;
    try {
      pointer = await _pointer(id);
    } catch (_) {
      await _quarantine(id, 'pointer', {'reason': 'invalidPointer'});
      rethrow;
    }
    if (pointer == null) return null;
    final rejected = <int>[];
    for (final entry in pointer.ancestry) {
      try {
        final manifest = await _manifest(id, entry);
        final assets = <String, Uint8List>{};
        for (final asset in manifest.assets.entries) {
          final reference = asset.value;
          if (reference == null || assets.containsKey(reference.path)) continue;
          try {
            assets[reference.path] = await _readBytes(
              'projects/$id/${reference.path}',
              reference.length,
            );
          } catch (_) {
            if (asset.key != 'thumbnail') rethrow;
          }
        }
        final decoded = _codec.decode(manifest, assets);
        RoomProjectRecoveryWarning? warning;
        if (rejected.isNotEmpty || decoded.thumbnailUnavailable) {
          warning = RoomProjectRecoveryWarning(
            reason: rejected.isNotEmpty
                ? RoomProjectRecoveryReason.earlierRevision
                : RoomProjectRecoveryReason.thumbnailUnavailable,
            acknowledgedRevision: pointer.revision,
            recoveredRevision: entry.revision,
            rejectedRevisions: rejected,
            thumbnailUnavailable: decoded.thumbnailUnavailable,
          );
          if (decoded.thumbnailUnavailable) {
            await _quarantine(id, 'thumbnail-${entry.revision}', {
              'reason': 'invalidThumbnail',
              'revision': entry.revision,
            });
          }
        }
        return RoomProjectReadResult(
          snapshot: decoded.snapshot,
          acknowledgedRevision: pointer.revision,
          warning: warning,
        );
      } catch (_) {
        rejected.add(entry.revision);
        await _quarantine(id, 'revision-${entry.revision}', {
          'reason': 'invalidRevision',
          'revision': entry.revision,
          'expectedManifestSha256': entry.manifestHash,
        });
      }
    }
    throw const RoomProjectStorageException(RoomProjectStorageFailure.corrupt);
  }

  Future<void> _quarantine(
    String id,
    String key,
    Map<String, Object> metadata,
  ) async {
    // Retain original bytes in place; only non-sensitive, immutable diagnostic
    // metadata is added. A full disk must not suppress a usable fallback.
    try {
      _checkId(id);
      await _ensureDirectory('projects/$id/quarantine');
      final path = 'projects/$id/quarantine/$key.json';
      if (await _type(path) == FileSystemEntityType.notFound) {
        await _writeNew(
          path,
          Uint8List.fromList(
            utf8.encode(jsonEncode({'schemaVersion': 1, ...metadata})),
          ),
        );
      }
    } catch (_) {
      /* Best effort; unreadable originals remain untouched. */
    }
  }

  @override
  Future<RoomProjectReadResult?> read(String projectId) =>
      _serialize(() => _read(projectId));

  @override
  Future<RepositorySnapshot<RoomProjectSummary>> listSnapshot() =>
      _serialize(() async {
        final records = <RoomProjectSummary>[];
        final corrupt = <CorruptRecord>[];
        if (await _type('projects') == FileSystemEntityType.notFound) {
          return RepositorySnapshot(records: records, corruptRecords: corrupt);
        }
        await for (final entry in Directory(
          _absolute('projects'),
        ).list(followLinks: false)) {
          final id = entry.path.split(Platform.pathSeparator).last;
          try {
            _checkId(id);
            if (await _type('projects/$id') != FileSystemEntityType.directory) {
              throw const FormatException('Invalid project entry.');
            }
            final result = await _read(id);
            if (result != null) {
              records.add(RoomProjectSummary.fromReadResult(result));
            }
          } catch (_) {
            corrupt.add(
              CorruptRecord(
                collectionId: SchemaRegistry.roomProjects.id,
                storageKey: id,
                reason: 'Stored project could not be read safely.',
              ),
            );
          }
        }
        records.sort((a, b) {
          final date = b.updatedAt.compareTo(a.updatedAt);
          return date == 0 ? a.projectId.compareTo(b.projectId) : date;
        });
        return RepositorySnapshot(records: records, corruptRecords: corrupt);
      });

  @override
  Future<RoomProjectSnapshot> save(
    RoomProjectSnapshot snapshot, {
    required int expectedRevision,
  }) => _serialize(() async {
    _checkId(snapshot.projectId);
    if (!RoomProjectLimits.validRevision(expectedRevision)) {
      throw const RoomProjectStorageException(RoomProjectStorageFailure.limit);
    }
    final id = snapshot.projectId;
    final pointer = await _pointer(id);
    final actual = pointer?.revision ?? 0;
    if (actual != expectedRevision) {
      throw RoomProjectConflict(
        expectedRevision: expectedRevision,
        actualRevision: actual,
      );
    }
    if (actual >= RoomProjectLimits.maxRevisions ||
        actual >= RoomProjectLimits.maxRevision) {
      throw const RoomProjectStorageException(RoomProjectStorageFailure.limit);
    }
    final committed = snapshot.copyWith(revision: actual + 1);
    final encoding = _codec.encode(committed);
    await _ensureDirectory('projects/$id/assets');
    await _ensureDirectory('projects/$id/revisions');
    await _cleanProject(id, pointer);
    final nonce =
        '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(0x7fffffff)}';
    final stage = 'projects/$id/revisions/.stage-${committed.revision}-$nonce';
    await _ensureDirectory(stage);
    for (final asset in encoding.assets.entries) {
      final target = 'projects/$id/${asset.key}';
      final type = await _type(target);
      if (type == FileSystemEntityType.file) {
        final existing = await _readBytes(target, asset.value.length);
        if (sha256.convert(existing) != sha256.convert(asset.value)) {
          throw const FormatException('Immutable asset changed.');
        }
      } else if (type == FileSystemEntityType.notFound) {
        final stagedAsset = '$stage/${asset.key.split('/').last}';
        await _writeNew(stagedAsset, asset.value);
        if (await _type(target) != FileSystemEntityType.notFound) {
          throw const FormatException('Asset publication collision.');
        }
        await _io.renameFile(_absolute(stagedAsset), _absolute(target));
      } else {
        throw const FormatException('Invalid asset type.');
      }
    }
    await _writeNew('$stage/manifest.json', encoding.manifestBytes);
    final revisionDirectory = 'projects/$id/revisions/${committed.revision}';
    if (await _type(revisionDirectory) != FileSystemEntityType.notFound) {
      throw const FormatException('Immutable revision already exists.');
    }
    await _io.renameDirectory(_absolute(stage), _absolute(revisionDirectory));
    final next = _Pointer(id, [
      _Acknowledged(
        committed.revision,
        sha256.convert(encoding.manifestBytes).toString(),
      ),
      ...?pointer?.ancestry,
    ]);
    final pendingPointer = 'projects/$id/.current-$nonce';
    await _writeNew(pendingPointer, next.encode());
    await _type('projects/$id/current');
    await _io.renameFile(
      _absolute(pendingPointer),
      _absolute('projects/$id/current'),
    );
    return committed;
  });

  Future<void> _collectOrphans() async {
    await for (final entry in Directory(
      _absolute('projects'),
    ).list(followLinks: false)) {
      final id = entry.path.split(Platform.pathSeparator).last;
      if (!RoomProjectLimits.validId(id)) continue;
      try {
        await _cleanProject(id, await _pointer(id));
      } catch (_) {
        /* Preserve unknown/corrupt data; isolate other projects. */
      }
    }
  }

  Future<void> _cleanProject(String id, _Pointer? pointer) async {
    if (await _type('projects/$id') != FileSystemEntityType.directory) return;
    final acknowledged = {
      for (final entry in pointer?.ancestry ?? <_Acknowledged>[])
        '${entry.revision}',
    };
    final referenced = <String>{};
    var allManifestsValid = true;
    for (final entry in pointer?.ancestry ?? <_Acknowledged>[]) {
      try {
        final manifest = await _manifest(id, entry);
        referenced.addAll(
          manifest.assets.values.whereType<RoomProjectAssetReference>().map(
            (a) => a.path,
          ),
        );
      } catch (_) {
        allManifestsValid = false;
      }
    }
    final revisions = 'projects/$id/revisions';
    if (await _type(revisions) == FileSystemEntityType.directory) {
      await for (final entry in Directory(
        _absolute(revisions),
      ).list(followLinks: false)) {
        final name = entry.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.stage-') ||
            (RegExp(r'^[1-9][0-9]{0,9}$').hasMatch(name) &&
                !acknowledged.contains(name))) {
          await _removeTree('$revisions/$name', allowLink: true);
        }
      }
    }
    await for (final entry in Directory(
      _absolute('projects/$id'),
    ).list(followLinks: false)) {
      final name = entry.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.current-')) {
        await _removeTree('projects/$id/$name', allowLink: true);
      }
    }
    final assets = 'projects/$id/assets';
    if (allManifestsValid &&
        await _type(assets) == FileSystemEntityType.directory) {
      await for (final entry in Directory(
        _absolute(assets),
      ).list(followLinks: false)) {
        final name = entry.path.split(Platform.pathSeparator).last;
        if (RegExp(
              r'^[a-f0-9]{64}\.(png|mask|intent\.bin|history\.bin)$',
            ).hasMatch(name) &&
            !referenced.contains('assets/$name')) {
          await _removeTree('$assets/$name', allowLink: true);
        }
      }
    }
  }

  Future<List<_OwnedEntry>> _walk(
    String relative, {
    bool includeRoot = false,
  }) async {
    final result = <_OwnedEntry>[];
    Future<void> visit(String path, String key, int depth) async {
      if (depth > 16 || result.length >= 100000 || key.length > 2048) {
        throw const LocalDataException();
      }
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) return;
      if (key.isNotEmpty && (includeRoot || key != relative)) {
        result.add(_OwnedEntry(key, type));
      }
      if (type == FileSystemEntityType.directory) {
        await for (final child in Directory(path).list(followLinks: false)) {
          final name = child.path.split(Platform.pathSeparator).last;
          await visit(child.path, key.isEmpty ? name : '$key/$name', depth + 1);
        }
      } else if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.link) {
        throw const LocalDataException();
      }
    }

    await visit(_absolute(relative), relative, 0);
    return result;
  }

  Future<void> _removeEntries(List<_OwnedEntry> entries) async {
    entries.sort((a, b) {
      final depth = b.relative
          .split('/')
          .length
          .compareTo(a.relative.split('/').length);
      return depth == 0 ? a.relative.compareTo(b.relative) : depth;
    });
    for (final entry in entries) {
      await _checkParent();
      final path = _absolute(entry.relative);
      // Paths come from a no-follow inventory. Recheck each ancestor against
      // redirection; links themselves may be removed, never their targets.
      final parts = entry.relative.split('/');
      var ancestor = _root;
      if (await FileSystemEntity.type(ancestor, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const LocalDataException();
      }
      for (final component in parts.take(parts.length - 1)) {
        ancestor = '$ancestor/$component';
        if (await FileSystemEntity.type(ancestor, followLinks: false) !=
            FileSystemEntityType.directory) {
          throw const LocalDataException();
        }
      }
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type != entry.type) throw const LocalDataException();
      if (type == FileSystemEntityType.link) {
        await _io.removeLink(path);
      } else if (type == FileSystemEntityType.file) {
        await _io.removeFile(path);
      } else if (type == FileSystemEntityType.directory) {
        await _io.removeDirectory(path);
      }
    }
  }

  Future<void> _removeTree(String relative, {bool allowLink = false}) async {
    final type = await _type(relative, allowFinalLink: allowLink);
    if (type == FileSystemEntityType.notFound) return;
    await _removeEntries(await _walk(relative, includeRoot: true));
  }

  @override
  Future<void> delete(String projectId) => _serialize(() async {
    _checkId(projectId);
    await _removeTree('projects/$projectId');
  });

  Future<LocalDataManifest> _inventory() async {
    if (await _type('') == FileSystemEntityType.notFound) {
      return LocalDataManifest({}, 0, recordCount: 0);
    }
    final entries = <String, String>{};
    var bytes = 0;
    var revisions = 0;
    final projectIds = <String>{};
    for (final entry in await _walk('')) {
      final path = _absolute(entry.relative);
      if (entry.type == FileSystemEntityType.file) {
        final file = File(path);
        final length = await file.length();
        final hash = await sha256.bind(file.openRead()).first;
        entries[entry.relative] = 'file:$length:$hash';
        bytes += length;
      } else if (entry.type == FileSystemEntityType.link) {
        entries[entry.relative] =
            'link:${sha256.convert(utf8.encode(await Link(path).target()))}';
      } else {
        entries[entry.relative] = 'directory';
        final components = entry.relative.split('/');
        if (components.length == 2 &&
            components.first == 'projects' &&
            RoomProjectLimits.validId(components[1])) {
          projectIds.add(components[1]);
        }
        if (components.length == 4 &&
            components.first == 'projects' &&
            components[2] == 'revisions' &&
            RegExp(r'^[1-9][0-9]{0,9}$').hasMatch(components[3])) {
          revisions++;
        }
      }
    }
    return LocalDataManifest(
      entries,
      bytes,
      recordCount: projectIds
          .where((id) => entries.containsKey('projects/$id/current'))
          .length,
      revisionCount: revisions,
    );
  }

  @override
  Future<T> withMaintenance<T>(
    Future<T> Function(LocalDataLease lease) action,
  ) => _serialize(() async {
    final lease = _RoomProjectLease(this);
    try {
      return await action(lease);
    } finally {
      lease.active = false;
    }
  });

  @override
  Future<void> close() => _closing ??= _queue.pending.then((_) {
    _queue.owners--;
    if (_queue.owners == 0 && identical(_queues[_root], _queue)) {
      _queues.remove(_root);
    }
  });
}

final class _OwnedEntry {
  const _OwnedEntry(this.relative, this.type);
  final String relative;
  final FileSystemEntityType type;
}

final class _RoomProjectLease implements LocalDataLease {
  _RoomProjectLease(this.owner);
  final FileRoomProjectRepository owner;
  bool active = true;
  @override
  Future<LocalDataManifest> inventory() async {
    if (!active) throw const LocalDataException();
    return owner._inventory();
  }

  @override
  Future<void> erase(LocalDataManifest manifest) async {
    if (!active || !manifest.sameAs(await inventory())) {
      throw const LocalDataException();
    }
    await owner._removeEntries(await owner._walk(''));
  }
}

final class _Acknowledged {
  const _Acknowledged(this.revision, this.manifestHash);
  final int revision;
  final String manifestHash;
  Map<String, Object> toMap() => {
    'revision': revision,
    'manifestSha256': manifestHash,
  };
}

final class _Pointer {
  const _Pointer(this.projectId, this.ancestry);
  final String projectId;
  final List<_Acknowledged> ancestry;
  int get revision => ancestry.first.revision;
  Map<String, Object> get _payload => {
    'schemaVersion': 1,
    'projectId': projectId,
    'ancestry': ancestry.map((e) => e.toMap()).toList(),
  };
  Uint8List encode() {
    final payload = _payload;
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          ...payload,
          'checksum': sha256
              .convert(utf8.encode(jsonEncode(payload)))
              .toString(),
        }),
      ),
    );
  }

  factory _Pointer.decode(Uint8List bytes, String projectId) {
    try {
      if (bytes.length > RoomProjectLimits.maxPointerBytes) {
        throw const FormatException();
      }
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic> ||
          value.length != 4 ||
          value['schemaVersion'] is! int ||
          value['schemaVersion'] != 1 ||
          value['projectId'] != projectId ||
          value['checksum'] is! String) {
        throw const FormatException();
      }
      final raw = value['ancestry'];
      if (raw is! List ||
          raw.isEmpty ||
          raw.length > RoomProjectLimits.maxRevisions) {
        throw const FormatException();
      }
      final ancestry = <_Acknowledged>[];
      for (var i = 0; i < raw.length; i++) {
        final entry = raw[i];
        if (entry is! Map<String, dynamic> ||
            entry.length != 2 ||
            entry['revision'] is! int ||
            entry['revision'] != raw.length - i ||
            entry['manifestSha256'] is! String ||
            !RegExp(
              r'^[a-f0-9]{64}$',
            ).hasMatch(entry['manifestSha256'] as String)) {
          throw const FormatException();
        }
        ancestry.add(
          _Acknowledged(
            entry['revision'] as int,
            entry['manifestSha256'] as String,
          ),
        );
      }
      final pointer = _Pointer(projectId, ancestry);
      if (sha256
              .convert(utf8.encode(jsonEncode(pointer._payload)))
              .toString() !=
          value['checksum']) {
        throw const FormatException();
      }
      return pointer;
    } catch (_) {
      throw const FormatException('Invalid Room project pointer.');
    }
  }
}
