import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredAccount {
  const StoredAccount({
    required this.serverUrl,
    required this.userId,
    required this.email,
    required this.deviceId,
  });

  final String serverUrl;
  final String userId;
  final String email;
  final String deviceId;
}

class StoredSession {
  const StoredSession({
    required this.account,
    required this.accessToken,
    required this.refreshToken,
    required this.masterKey,
  });

  final StoredAccount account;
  final String accessToken;
  final String refreshToken;
  final SecretKeyData masterKey;
}

class ProfileAccountMismatchException implements Exception {
  const ProfileAccountMismatchException();
}

class SecureAccountStore {
  SecureAccountStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _serverUrlKey = 'account.server_url';
  static const _userIdKey = 'account.user_id';
  static const _emailKey = 'account.email';
  static const _deviceIdKey = 'account.device_id';
  static const _accessTokenKey = 'session.access_token';
  static const _refreshTokenKey = 'session.refresh_token';
  static const _masterKeyKey = 'crypto.master_key';
  static const _databaseKeyKey = 'crypto.database_key';
  static const _profileUserIdKey = 'profile.user_id';

  final FlutterSecureStorage _storage;

  Future<StoredSession?> readSession() async {
    final values = await Future.wait([
      _storage.read(key: _serverUrlKey),
      _storage.read(key: _userIdKey),
      _storage.read(key: _emailKey),
      _storage.read(key: _deviceIdKey),
      _storage.read(key: _accessTokenKey),
      _storage.read(key: _refreshTokenKey),
      _storage.read(key: _masterKeyKey),
    ]);
    if (values.any((value) => value == null || value.isEmpty)) {
      return null;
    }

    late final List<int> masterKeyBytes;
    try {
      masterKeyBytes = base64Url.decode(values[6]!);
    } on FormatException {
      return null;
    }
    if (masterKeyBytes.length != 32) {
      return null;
    }

    return StoredSession(
      account: StoredAccount(
        serverUrl: values[0]!,
        userId: values[1]!,
        email: values[2]!,
        deviceId: values[3]!,
      ),
      accessToken: values[4]!,
      refreshToken: values[5]!,
      masterKey: SecretKeyData(masterKeyBytes),
    );
  }

  Future<void> writeSession(StoredSession session) async {
    if (session.masterKey.bytes.length != 32) {
      throw ArgumentError.value(
        session.masterKey.bytes.length,
        'session.masterKey',
        'Recall master keys must be 256 bits.',
      );
    }
    await assertProfileCompatible(session.account.userId);

    await Future.wait([
      _storage.write(key: _serverUrlKey, value: session.account.serverUrl),
      _storage.write(key: _userIdKey, value: session.account.userId),
      _storage.write(key: _emailKey, value: session.account.email),
      _storage.write(key: _deviceIdKey, value: session.account.deviceId),
      _storage.write(key: _accessTokenKey, value: session.accessToken),
      _storage.write(key: _refreshTokenKey, value: session.refreshToken),
      _storage.write(
        key: _masterKeyKey,
        value: base64UrlEncode(session.masterKey.bytes),
      ),
      _storage.write(key: _profileUserIdKey, value: session.account.userId),
    ]);
  }

  Future<void> assertProfileCompatible(String userId) async {
    final profileUserId = await _storage.read(key: _profileUserIdKey);
    if (profileUserId != null && profileUserId != userId) {
      throw const ProfileAccountMismatchException();
    }
  }

  Future<String> readOrCreateDatabaseKey() async {
    final existing = await _storage.read(key: _databaseKeyKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated = base64UrlEncode(
      SecretKeyData.random(length: 32).bytes,
    ).replaceAll('=', '');
    await _storage.write(key: _databaseKeyKey, value: generated);
    return generated;
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _serverUrlKey),
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _emailKey),
      _storage.delete(key: _deviceIdKey),
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _masterKeyKey),
    ]);
  }
}
