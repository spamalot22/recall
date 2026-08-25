import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/account/secure_account_store.dart';
import 'package:recall_app/src/data/local_database.dart';
import 'package:recall_app/src/sync/sync_execution_lock.dart';
import 'package:recall_app/src/sync/sync_service.dart';

void main() {
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
