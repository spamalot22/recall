import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/sync/sync_execution_lock.dart';

void main() {
  late Directory directory;
  late String path;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('recall-lock-test-');
    path = '${directory.path}/lock.sqlite';
  });
  tearDown(() async => directory.delete(recursive: true));

  test('serializes independent lock instances in the same isolate', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final order = <String>[];
    final first = FileSyncExecutionLock(databasePath: path).synchronized(
      () async {
        order.add('first');
        entered.complete();
        await release.future;
        order.add('released');
      },
    );
    await entered.future;
    final second = FileSyncExecutionLock(databasePath: path).synchronized(
      () async {
        order.add('second');
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(order, ['first']);
    release.complete();
    await first;
    await second;
    expect(order, ['first', 'released', 'second']);
  });

  test('excludes background isolates and releases after errors', () async {
    final events = ReceivePort();
    final iterator = StreamIterator<dynamic>(events);
    final worker = await Isolate.spawn(_holdLock, (path, events.sendPort));
    addTearDown(() {
      worker.kill(priority: Isolate.immediate);
      events.close();
    });
    expect(await iterator.moveNext(), isTrue);
    final release = iterator.current as SendPort;
    var entered = false;
    final next = FileSyncExecutionLock(databasePath: path).synchronized(
      () async {
        entered = true;
        throw StateError('operation failed');
      },
    );
    final failure = expectLater(next, throwsStateError);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(entered, isFalse);
    release.send(null);
    await failure;
    expect(entered, isTrue);
    expect(
      await FileSyncExecutionLock(
        databasePath: path,
      ).synchronized(() async => 42),
      42,
    );
    await iterator.cancel();
  });
}

Future<void> _holdLock((String, SendPort) args) async {
  final release = ReceivePort();
  try {
    await FileSyncExecutionLock(databasePath: args.$1).synchronized(() async {
      args.$2.send(release.sendPort);
      await release.first;
    });
  } finally {
    release.close();
  }
}
