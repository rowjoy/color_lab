import 'dart:io';
import 'dart:async';
import 'package:hive/hive.dart';

/// Real Hive with a one-shot flush failure; mutation/cache/rollback stay real.
final class Task5RoomFaultBox implements Box<dynamic> {
  Task5RoomFaultBox(this.delegate);
  final Box<dynamic> delegate;
  bool failNextFlush = false;
  Future<void>? nextFlushGate;
  Completer<void>? nextFlushStarted;
  @override
  Iterable<dynamic> get keys => delegate.keys;
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, dynamic value) => delegate.put(key, value);
  @override
  Future<void> delete(dynamic key) => delegate.delete(key);
  @override
  Future<void> flush() async {
    final gate = nextFlushGate;
    nextFlushGate = null;
    nextFlushStarted?.complete();
    nextFlushStarted = null;
    if (gate != null) await gate;
    if (failNextFlush) {
      failNextFlush = false;
      throw const FileSystemException('Injected review flush failure');
    }
    await delegate.flush();
  }

  @override
  Future<void> close() => delegate.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
