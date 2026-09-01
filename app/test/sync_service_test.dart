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

void main() {
  test('sync includes manual card order inside encrypted note data', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final serverUrl = 'http://${server.address.address}:${server.port}';
    final session = _session(serverUrl, 'access', 'refresh');
    final accountStore = _MemoryAccountStore(session);
    String? encryptedPayload;

    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/sync/push') {
        final records = (body as Map<String, Object?>)['records'] as List;
        final record = Map<String, Object?>.from(records.single as Map);
        encryptedPayload = record['encryptedPayload'] as String;
        request.response.write(
          jsonEncode({
            'accepted': [
              {
                'clientRecordId': record['id'],
                'serverRevision': 1,
                'conflict': false,
              },
            ],
          }),
        );
      } else {
        request.response.write(
          jsonEncode({
            'records': <Object?>[],
            'cursor': {'lastServerRevision': 1, 'hasMore': false},
          }),
        );
      }
      await request.response.close();
    });

    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime.utc(2026, 8, 26, 10);
    await database
        .into(database.notes)
        .insert(
          NotesCompanion.insert(
            id: '0198a3b4-8e80-7000-8000-000000000001',
            title: const Value('Private note'),
            sortOrder: const Value(7),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.reminders)
        .insert(
          RemindersCompanion.insert(
            id: '0198a3b4-8e80-7000-8000-000000000002',
            noteId: '0198a3b4-8e80-7000-8000-000000000001',
            nextFireAt: DateTime.utc(2026, 8, 31, 22),
            timezone: 'UTC',
            recurrenceKind: const Value('monthly'),
            recurrenceJson: const Value('{"version":1,"interval":2}'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await SyncService(
      database,
      accountStore,
      executionLock: const _ImmediateSyncExecutionLock(),
    ).sync();

    final payload = await RecordCipher().decryptJson(
      encryptedValue: encryptedPayload!,
      masterKey: session.masterKey,
    );
    final note = Map<String, Object?>.from(payload['note']! as Map);
    final reminder = Map<String, Object?>.from(payload['reminder']! as Map);
    expect(note['sortOrder'], 7);
    expect(reminder['recurrenceKind'], 'monthly');
    expect(reminder['recurrenceJson'], '{"version":1,"interval":2}');
  });

  test(
    'sync recovers when another isolate rotated the refresh token',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final serverUrl = 'http://${server.address.address}:${server.port}';
      final stale = _session(serverUrl, 'stale-access', 'stale-refresh');
      final current = _session(serverUrl, 'current-access', 'current-refresh');
      final accountStore = _MemoryAccountStore(stale);

      final requests = <String>[];
      server.listen((request) async {
        requests.add(request.uri.path);
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/sync/pull' &&
            request.headers.value(HttpHeaders.authorizationHeader) ==
                'Bearer current-access') {
          request.response.write(
            jsonEncode({
              'records': <Object?>[],
              'cursor': {'lastServerRevision': 0, 'hasMore': false},
            }),
          );
        } else if (request.uri.path == '/auth/refresh') {
          accountStore.session = current;
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.write(
            jsonEncode({'error': 'invalid_refresh_token'}),
          );
        } else {
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.write(jsonEncode({'error': 'unauthorized'}));
        }
        await request.response.close();
      });

      final database = LocalDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final result = await SyncService(
        database,
        accountStore,
        executionLock: const _ImmediateSyncExecutionLock(),
      ).sync();

      expect(result.connected, isTrue);
      expect(requests, ['/sync/pull', '/auth/refresh', '/sync/pull']);
    },
  );

  test('sync reports a genuinely rejected refresh token as expired', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final serverUrl = 'http://${server.address.address}:${server.port}';
    final accountStore = _MemoryAccountStore(
      _session(serverUrl, 'stale-access', 'stale-refresh'),
    );

    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'error': request.uri.path == '/auth/refresh'
              ? 'invalid_refresh_token'
              : 'unauthorized',
        }),
      );
      await request.response.close();
    });

    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final sync = SyncService(
      database,
      accountStore,
      executionLock: const _ImmediateSyncExecutionLock(),
    ).sync();

    await expectLater(
      sync,
      throwsA(
        isA<SyncException>().having(
          (error) => error.message,
          'message',
          'Your Recall backup session has expired. Sign in again.',
        ),
      ),
    );
  });
}

StoredSession _session(String serverUrl, String access, String refresh) {
  return StoredSession(
    account: StoredAccount(
      serverUrl: serverUrl,
      userId: 'user-id',
      email: 'user@example.com',
      deviceId: 'device-id',
    ),
    accessToken: access,
    refreshToken: refresh,
    masterKey: SecretKeyData(List<int>.filled(32, 1)),
  );
}

class _MemoryAccountStore extends SecureAccountStore {
  _MemoryAccountStore(this.session);

  StoredSession? session;

  @override
  Future<StoredSession?> readSession() async => session;

  @override
  Future<void> writeSession(StoredSession value) async {
    session = value;
  }
}

class _ImmediateSyncExecutionLock implements SyncExecutionLock {
  const _ImmediateSyncExecutionLock();

  @override
  Future<T> synchronized<T>(Future<T> Function() operation) => operation();
}
