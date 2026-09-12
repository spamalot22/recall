import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/account/secure_account_store.dart';

StoredSession _session(String token) => StoredSession(
  account: const StoredAccount(
    serverUrl: 'http://192.168.1.2:8787',
    userId: 'user',
    email: 'test@example.invalid',
    deviceId: 'device',
  ),
  accessToken: 'access-$token',
  refreshToken: 'refresh-$token',
  masterKey: SecretKeyData(List.filled(32, 7)),
);

Map<String, String> _legacy() => {
  'account.server_url': _session('old').account.serverUrl,
  'account.user_id': 'user',
  'account.email': 'test@example.invalid',
  'account.device_id': 'device',
  'session.access_token': 'access-old',
  'session.refresh_token': 'refresh-old',
  'crypto.master_key': base64UrlEncode(_session('old').masterKey.bytes),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('stores and reads the complete session as one secure value', () async {
    final store = SecureAccountStore();
    await store.writeSession(_session('new'));
    final result = await store.readSession();
    expect(result?.accessToken, 'access-new');
    expect(result?.refreshToken, 'refresh-new');
    expect(result?.masterKey.bytes, List.filled(32, 7));
    final raw = await const FlutterSecureStorage().readAll();
    expect(raw.keys, unorderedEquals(['profile.user_id', 'session.v2']));
  });

  test(
    'legacy credentials remain readable and migrate on the next write',
    () async {
      FlutterSecureStorage.setMockInitialValues(_legacy());
      final store = SecureAccountStore();
      expect((await store.readSession())?.accessToken, 'access-old');
      await store.writeSession(_session('new'));
      expect((await store.readSession())?.accessToken, 'access-new');
      expect(
        await const FlutterSecureStorage().read(key: 'crypto.master_key'),
        isNull,
      );
    },
  );

  test(
    'failed session replacement leaves the previous token pair intact',
    () async {
      final storage = _FailingStorage();
      final store = SecureAccountStore(storage: storage);
      await store.writeSession(_session('old'));
      storage.failSessionWrite = true;
      await expectLater(store.writeSession(_session('new')), throwsStateError);
      final session = await store.readSession();
      expect(session?.accessToken, 'access-old');
      expect(session?.refreshToken, 'refresh-old');
    },
  );

  test(
    'a signed-out or corrupt v2 value never revives legacy credentials',
    () async {
      for (final value in ['null', '{broken', '{}']) {
        FlutterSecureStorage.setMockInitialValues({
          ..._legacy(),
          'session.v2': value,
        });
        expect(await SecureAccountStore().readSession(), isNull);
      }
    },
  );

  test('logout preserves profile binding and the local database key', () async {
    FlutterSecureStorage.setMockInitialValues({
      'crypto.database_key': 'existing-key',
    });
    final store = SecureAccountStore();
    await store.writeSession(_session('old'));
    await store.clearSession();
    expect(await store.readSession(), isNull);
    expect(
      await const FlutterSecureStorage().read(key: 'crypto.database_key'),
      'existing-key',
    );
    await expectLater(
      store.assertProfileCompatible('other'),
      throwsA(isA<ProfileAccountMismatchException>()),
    );
  });
}

class _FailingStorage extends FlutterSecureStorage {
  bool failSessionWrite = false;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (key == 'session.v2' && failSessionWrite) {
      throw StateError('Interrupted write');
    }
    return super.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}
