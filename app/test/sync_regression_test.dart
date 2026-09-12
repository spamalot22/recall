import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/account/secure_account_store.dart';
import 'package:recall_app/src/data/local_database.dart';
import 'package:recall_app/src/security/record_cipher.dart';
import 'package:recall_app/src/sync/sync_execution_lock.dart';
import 'package:recall_app/src/sync/sync_service.dart';

const _a = '0198a3b4-8e80-7000-8000-000000000001';
const _b = '0198a3b4-8e80-7000-8000-000000000002';
const _c = '0198a3b4-8e80-7000-8000-000000000003';
final _now = DateTime.utc(2026, 9, 5, 12);

void main() {
  late _SyncFixture fixture;
  setUp(() async => fixture = await _SyncFixture.create());
  tearDown(() => fixture.close());

  test(
    'upload then failed pull does not skip older remote notes on retry',
    () async {
      await fixture.remoteNote(_b, body: 'Other device');
      await fixture.localNote(_a);
      fixture.failPull = true;
      await expectLater(fixture.sync.sync(), throwsA(isA<SyncException>()));
      expect(await fixture.db.readPullRevision(), 0);
      fixture.failPull = false;
      await fixture.sync.sync();
      expect(
        (await fixture.db.select(fixture.db.notes).get()).map((n) => n.id),
        containsAll([_a, _b]),
      );
      expect(await fixture.db.readPullRevision(), 2);
    },
  );

  test(
    'same-second edit during upload survives its acknowledgement and echo',
    () async {
      await fixture.localNote(_a, body: 'Before');
      fixture.afterPush = () async {
        await (fixture.db.update(fixture.db.notes)
              ..where((n) => n.id.equals(_a)))
            .write(const NotesCompanion(body: Value('Edited during upload')));
      };
      await fixture.sync.sync();
      expect(
        (await fixture.db.select(fixture.db.notes).getSingle()).body,
        'Edited during upload',
      );
      expect(await fixture.sync.pendingChangeCount(), 1);
      fixture.afterPush = null;
      await fixture.sync.sync();
      final payload = await fixture.decrypt(fixture.records[_a]!);
      expect((payload['note'] as Map)['body'], 'Edited during upload');
      expect(await fixture.sync.pendingChangeCount(), 0);
    },
  );

  test(
    'local edits during pull are preserved alongside the remote note',
    () async {
      await fixture.localNote(_a);
      await fixture.sync.sync();
      await fixture.remoteNote(_a, body: 'Remote edit');
      fixture.beforePull = () async {
        await (fixture.db.update(fixture.db.notes)
              ..where((n) => n.id.equals(_a)))
            .write(const NotesCompanion(body: Value('Local edit')));
      };
      await fixture.sync.sync();
      final notes = await fixture.db.select(fixture.db.notes).get();
      expect(
        notes.map((n) => n.body),
        containsAll(['Local edit', 'Remote edit']),
      );
      expect(notes.singleWhere((n) => n.id == _a).body, 'Local edit');
    },
  );

  test('restores negative card positions', () async {
    await fixture.remoteNote(_a, sortOrder: -5);
    await fixture.sync.sync();
    expect(
      (await fixture.db.select(fixture.db.notes).getSingle()).sortOrder,
      -5,
    );
  });

  test('invalid record rolls back the entire page and cursor', () async {
    await fixture.remoteNote(_a);
    await fixture.remoteNote(_b);
    fixture.records[_b]!['type'] = 'tombstone';
    await expectLater(fixture.sync.sync(), throwsA(isA<SyncException>()));
    expect(await fixture.db.select(fixture.db.notes).get(), isEmpty);
    expect(await fixture.db.readPullRevision(), 0);
  });

  test('rejects a payload relabelled as another note', () async {
    await fixture.remoteNote(_a);
    fixture.records[_a]!['id'] = _b;
    await expectLater(fixture.sync.sync(), throwsA(isA<SyncException>()));
    expect(await fixture.db.select(fixture.db.notes).get(), isEmpty);
  });

  test('a forged conflict cannot overwrite an unrelated synced note', () async {
    await fixture.localNote(_b, body: 'Keep this note');
    await fixture.sync.sync();
    await fixture.remoteNote(_a, body: 'Different note');
    fixture.records[_a]!['id'] = _b;
    fixture.records[_a]!['conflictOfRecordId'] = _a;
    await expectLater(fixture.sync.sync(), throwsA(isA<SyncException>()));
    expect(
      (await fixture.db.select(fixture.db.notes).getSingle()).body,
      'Keep this note',
    );
  });

  test(
    'rejects duplicate acknowledgements without clearing pending changes',
    () async {
      await fixture.localNote(_a);
      await fixture.localNote(_b);
      fixture.duplicateAcknowledgements = true;
      await expectLater(fixture.sync.sync(), throwsA(isA<SyncException>()));
      expect(
        (await fixture.db.select(fixture.db.syncRecords).get()).every(
          (r) => r.hasLocalChanges,
        ),
        isTrue,
      );
    },
  );

  test('batches large uploads below the server request limit', () async {
    for (final id in [_a, _b, _c]) {
      await fixture.localNote(id, body: 'x' * 250000);
    }
    await fixture.sync.sync();
    expect(fixture.pushSizes, hasLength(2));
    expect(fixture.pushSizes.every((size) => size < 1024 * 1024), isTrue);
  });

  test(
    'permanent deletion while disconnected is uploaded on reconnect',
    () async {
      await fixture.localNote(_a);
      await fixture.sync.sync();
      final session = fixture.accounts.session;
      fixture.accounts.session = null;
      await fixture.sync.permanentlyDeleteNote(_a);
      fixture.accounts.session = session;
      await fixture.sync.sync();
      expect(fixture.records[_a]!['type'], 'tombstone');
      expect(await fixture.db.select(fixture.db.notes).get(), isEmpty);
      expect(await fixture.db.pendingDeletionIds(), isEmpty);
    },
  );
}

class _SyncFixture {
  _SyncFixture(this.server, this.db, this.accounts) {
    sync = SyncService(db, accounts, executionLock: const _ImmediateLock());
    server.listen(_respond);
  }

  final HttpServer server;
  final LocalDatabase db;
  final _Accounts accounts;
  late final SyncService sync;
  final records = <String, Map<String, Object?>>{};
  final pushSizes = <int>[];
  int revision = 0;
  bool failPull = false;
  bool duplicateAcknowledgements = false;
  Future<void> Function()? afterPush;
  Future<void> Function()? beforePull;
  final cipher = RecordCipher();

  static Future<_SyncFixture> create() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _SyncFixture(
      server,
      LocalDatabase.forTesting(NativeDatabase.memory()),
      _Accounts(
        StoredSession(
          account: StoredAccount(
            serverUrl: 'http://127.0.0.1:${server.port}',
            userId: 'user',
            email: 'test@example.com',
            deviceId: 'device',
          ),
          accessToken: 'access',
          refreshToken: 'refresh',
          masterKey: SecretKeyData(List.filled(32, 1)),
        ),
      ),
    );
  }

  Future<void> localNote(String id, {String body = ''}) => db
      .into(db.notes)
      .insert(
        NotesCompanion.insert(
          id: id,
          body: Value(body),
          createdAt: _now,
          updatedAt: _now,
        ),
      );

  Future<void> remoteNote(
    String id, {
    String body = '',
    int sortOrder = 0,
  }) async {
    final payload = {
      'schema': 1,
      'note': {
        'id': id,
        'title': '',
        'body': body,
        'noteType': 'text',
        'mood': 'clear',
        'moodIsAutomatic': true,
        'moodConfidence': 0.0,
        'moodModelVersion': 0,
        'isPinned': false,
        'isArchived': false,
        'sortOrder': sortOrder,
        'trashedAt': null,
        'createdAt': _now.toIso8601String(),
        'updatedAt': _now.toIso8601String(),
      },
      'checklistItems': <Object?>[],
    };
    records[id] = {
      'id': id,
      'type': 'note',
      'payloadVersion': 1,
      'serverRevision': ++revision,
      'encryptedPayload': await cipher.encryptJson(
        value: payload,
        masterKey: accounts.session!.masterKey,
      ),
    };
  }

  Future<Map<String, Object?>> decrypt(Map<String, Object?> record) =>
      cipher.decryptJson(
        encryptedValue: record['encryptedPayload'] as String,
        masterKey: accounts.session!.masterKey,
      );

  Future<void> _respond(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    final body = jsonDecode(raw) as Map;
    request.response.headers.contentType = ContentType.json;
    Object response;
    if (request.uri.path == '/sync/push') {
      pushSizes.add(utf8.encode(raw).length);
      final accepted = <Map<String, Object?>>[];
      for (final rawRecord in body['records'] as List) {
        final record = Map<String, Object?>.from(rawRecord as Map);
        records[record['id'] as String] = {
          ...record,
          'serverRevision': ++revision,
        };
        accepted.add({
          'clientRecordId': record['id'],
          'serverRevision': revision,
          'conflict': false,
        });
      }
      await afterPush?.call();
      response = {
        'accepted': duplicateAcknowledgements
            ? [accepted.first, accepted.first]
            : accepted,
      };
    } else if (failPull) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      response = {'error': 'temporarily_unavailable'};
    } else {
      await beforePull?.call();
      final page =
          records.values
              .where(
                (r) =>
                    (r['serverRevision'] as int) >
                    (body['afterServerRevision'] as int),
              )
              .toList()
            ..sort(
              (a, b) => (a['serverRevision'] as int).compareTo(
                b['serverRevision'] as int,
              ),
            );
      // Mirror the server's bounded pages.
      var size = 0;
      final bounded = page.takeWhile((r) {
        size += jsonEncode(r).length;
        return size < 900000;
      }).toList();
      response = {
        'records': bounded,
        'cursor': {
          'lastServerRevision': bounded.isEmpty
              ? body['afterServerRevision']
              : bounded.last['serverRevision'],
          'hasMore': bounded.length < page.length,
        },
      };
    }
    request.response.write(jsonEncode(response));
    await request.response.close();
  }

  Future<void> close() async {
    await server.close(force: true);
    await db.close();
  }
}

class _Accounts extends SecureAccountStore {
  _Accounts(this.session);
  StoredSession? session;
  @override
  Future<StoredSession?> readSession() async => session;
}

class _ImmediateLock implements SyncExecutionLock {
  const _ImmediateLock();
  @override
  Future<T> synchronized<T>(Future<T> Function() operation) => operation();
}
