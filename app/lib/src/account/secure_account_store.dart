import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../sync/sync_execution_lock.dart';

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
  static const _sessionKey = 'session.v2';

  final FlutterSecureStorage _storage;

  Future<StoredSession?> readSession() async {
    final encoded = await _storage.read(key: _sessionKey);
    if (encoded != null) {
      try {
        final data = jsonDecode(encoded);
        if (data is! Map<String, dynamic>) return null;
        final fields = [
          'serverUrl',
          'userId',
          'email',
          'deviceId',
          'accessToken',
          'refreshToken',
          'masterKey',
        ];
        if (fields.any(
          (key) => data[key] is! String || (data[key] as String).isEmpty,
        )) {
          return null;
        }
        final key = base64Url.decode(data['masterKey'] as String);
        if (key.length != 32) return null;
        return StoredSession(
          account: StoredAccount(
            serverUrl: data['serverUrl'] as String,
            userId: data['userId'] as String,
            email: data['email'] as String,
            deviceId: data['deviceId'] as String,
          ),
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
          masterKey: SecretKeyData(key),
        );
      } on FormatException {
        return null;
      }
    }
    // Older installations are read without rewriting credentials during a read.
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

    await _storage.write(key: _profileUserIdKey, value: session.account.userId);
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode({
        'serverUrl': session.account.serverUrl,
        'userId': session.account.userId,
        'email': session.account.email,
        'deviceId': session.account.deviceId,
        'accessToken': session.accessToken,
        'refreshToken': session.refreshToken,
        'masterKey': base64UrlEncode(session.masterKey.bytes),
      }),
    );
    try {
      await _clearLegacySession();
    } on Object {
      // The complete new session is already committed in secure storage.
    }
  }

  Future<void> assertProfileCompatible(String userId) async {
    final profileUserId = await _storage.read(key: _profileUserIdKey);
    if (profileUserId != null && profileUserId != userId) {
      throw const ProfileAccountMismatchException();
    }
  }

  Future<String> readOrCreateDatabaseKey() => const FileSyncExecutionLock(
    name: 'recall-database-key',
  ).synchronized(_readOrCreateDatabaseKey);

  Future<String> _readOrCreateDatabaseKey() async {
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
    // Keep a signed-out marker so interrupted legacy cleanup cannot resurrect
    // old credentials on the next launch.
    await _storage.write(key: _sessionKey, value: 'null');
    await _clearLegacySession();
  }

  Future<void> _clearLegacySession() async {
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
