import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../security/key_bundles.dart';
import 'secure_account_store.dart';

class AccountException implements Exception {
  const AccountException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthenticationResult {
  const AuthenticationResult({required this.session, this.recoveryKey});

  final StoredSession session;
  final String? recoveryKey;
}

class AuthService {
  AuthService(
    this._accountStore, {
    KeyBundleService? keyBundles,
    HttpClient? httpClient,
  }) : _keyBundles = keyBundles ?? KeyBundleService(),
       _httpClient =
           httpClient ??
           (HttpClient()..connectionTimeout = const Duration(seconds: 15));

  static const _maxResponseBytes = 1024 * 1024;

  final SecureAccountStore _accountStore;
  final KeyBundleService _keyBundles;
  final HttpClient _httpClient;

  Future<AuthenticationResult> register({
    required String serverUrl,
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final normalizedServerUrl = _normalizeServerUrl(serverUrl);
    final masterKey = _keyBundles.generateMasterKey();
    final recoveryKey = _keyBundles.generateRecoveryKey();
    final recoveryVerifier = await _keyBundles.recoveryVerifier(recoveryKey);
    final bundle = await _keyBundles.createBundle(
      masterKey: masterKey,
      password: password,
      recoveryKey: recoveryKey,
    );

    final response =
        await _requestJson(
          serverUrl: normalizedServerUrl,
          method: 'POST',
          path: '/auth/register',
          body: {
            'email': email.trim(),
            'password': password,
            'deviceName': deviceName.trim(),
            'recoveryVerifier': recoveryVerifier,
            ...bundle.toServerJson(),
          },
        ) ??
        (throw const AccountException(
          'The server returned an invalid response.',
        ));
    final session = _sessionFromResponse(
      serverUrl: normalizedServerUrl,
      response: response,
      masterKey: masterKey,
    );
    await _storeSession(session);
    return AuthenticationResult(session: session, recoveryKey: recoveryKey);
  }

  Future<AuthenticationResult> login({
    required String serverUrl,
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final normalizedServerUrl = _normalizeServerUrl(serverUrl);
    final response =
        await _requestJson(
          serverUrl: normalizedServerUrl,
          method: 'POST',
          path: '/auth/login',
          body: {
            'email': email.trim(),
            'password': password,
            'deviceName': deviceName.trim(),
          },
        ) ??
        (throw const AccountException(
          'The server returned an invalid response.',
        ));

    final accessToken = _requiredString(response, 'accessToken');
    final keyBundleResponse = await _requestJson(
      serverUrl: normalizedServerUrl,
      method: 'GET',
      path: '/key-bundle',
      accessToken: accessToken,
      allowNotFound: true,
    );

    SecretKeyData masterKey;
    String? recoveryKey;
    if (keyBundleResponse == null) {
      masterKey = _keyBundles.generateMasterKey();
      recoveryKey = _keyBundles.generateRecoveryKey();
      final bundle = await _keyBundles.createBundle(
        masterKey: masterKey,
        password: password,
        recoveryKey: recoveryKey,
      );
      final recoveryVerifier = await _keyBundles.recoveryVerifier(recoveryKey);
      await _requestJson(
        serverUrl: normalizedServerUrl,
        method: 'PUT',
        path: '/key-bundle',
        accessToken: accessToken,
        body: {...bundle.toServerJson(), 'recoveryVerifier': recoveryVerifier},
      );
    } else {
      final rawBundle = keyBundleResponse['keyBundle'];
      if (rawBundle is! Map) {
        throw const AccountException(
          'The server returned an invalid key bundle.',
        );
      }
      try {
        final bundle = EncryptedMasterKeyBundle.fromServerJson(
          Map<String, Object?>.from(rawBundle),
        );
        masterKey = await _keyBundles.unlockWithPassword(
          bundle: bundle,
          password: password,
        );
      } on SecretBoxAuthenticationError {
        throw const AccountException(
          'Could not unlock encrypted notes with that password.',
        );
      } on FormatException {
        throw const AccountException(
          'The server returned an invalid key bundle.',
        );
      }
    }

    final session = _sessionFromResponse(
      serverUrl: normalizedServerUrl,
      response: response,
      masterKey: masterKey,
    );
    await _storeSession(session);
    return AuthenticationResult(session: session, recoveryKey: recoveryKey);
  }

  Future<AuthenticationResult> recover({
    required String serverUrl,
    required String email,
    required String recoveryKey,
    required String newPassword,
    required String deviceName,
  }) async {
    final normalizedServerUrl = _normalizeServerUrl(serverUrl);
    final recoveryVerifier = await _keyBundles.recoveryVerifier(recoveryKey);
    final bundleResponse = await _requestJson(
      serverUrl: normalizedServerUrl,
      method: 'POST',
      path: '/auth/recovery-bundle',
      body: {'email': email.trim(), 'recoveryVerifier': recoveryVerifier},
    );
    final rawBundle = bundleResponse?['keyBundle'];
    if (rawBundle is! Map) {
      throw const AccountException(
        'The server returned an invalid key bundle.',
      );
    }
    final recoveryUserId = _requiredString(bundleResponse!, 'userId');
    try {
      await _accountStore.assertProfileCompatible(recoveryUserId);
    } on ProfileAccountMismatchException {
      throw const AccountException(
        'This local profile belongs to another account. Export or clear it before switching accounts.',
      );
    }

    final masterKey = await _unlockWithRecoveryKey(
      Map<String, Object?>.from(rawBundle),
      recoveryKey,
    );
    final nextBundle = await _keyBundles.createBundle(
      masterKey: masterKey,
      password: newPassword,
      recoveryKey: recoveryKey,
    );
    final response = await _requestJson(
      serverUrl: normalizedServerUrl,
      method: 'POST',
      path: '/auth/recover',
      body: {
        'email': email.trim(),
        'recoveryVerifier': recoveryVerifier,
        'newPassword': newPassword,
        'deviceName': deviceName.trim(),
        ...nextBundle.toServerJson(),
      },
    );
    if (response == null) {
      throw const AccountException('The server returned an invalid response.');
    }
    final session = _sessionFromResponse(
      serverUrl: normalizedServerUrl,
      response: response,
      masterKey: masterKey,
    );
    await _storeSession(session);
    return AuthenticationResult(session: session);
  }

  Future<void> logout() async {
    final session = await _accountStore.readSession();
    if (session != null) {
      try {
        final request = await _httpClient.postUrl(
          Uri.parse(session.account.serverUrl).resolve('/auth/logout'),
        );
        request.followRedirects = false;
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'refreshToken': session.refreshToken}));
        final response = await request.close();
        await _readResponse(response);
      } on Object {
        // Local disconnect still succeeds when the self-hosted server is offline.
      }
    }
    await _accountStore.clearSession();
  }

  Future<void> _storeSession(StoredSession session) async {
    try {
      await _accountStore.writeSession(session);
    } on ProfileAccountMismatchException {
      throw const AccountException(
        'This local profile belongs to another account. Export or clear it before switching accounts.',
      );
    }
  }

  Future<SecretKeyData> _unlockWithRecoveryKey(
    Map<String, Object?> rawBundle,
    String recoveryKey,
  ) async {
    try {
      final bundle = EncryptedMasterKeyBundle.fromServerJson(rawBundle);
      return await _keyBundles.unlockWithRecoveryKey(
        bundle: bundle,
        recoveryKey: recoveryKey,
      );
    } on SecretBoxAuthenticationError {
      throw const AccountException('That recovery key is not valid.');
    } on FormatException {
      throw const AccountException(
        'The server returned an invalid key bundle.',
      );
    }
  }

  Future<Map<String, Object?>?> _requestJson({
    required String serverUrl,
    required String method,
    required String path,
    Map<String, Object?>? body,
    String? accessToken,
    bool allowNotFound = false,
  }) async {
    final base = Uri.parse(serverUrl);
    final uri = base.resolve(path);
    final request = await _httpClient.openUrl(method, uri);
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (accessToken != null) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
    }
    if (body != null) {
      request.write(jsonEncode(body));
    }

    final response = await request.close();
    final content = await _readResponse(response);
    Map<String, Object?>? decoded;
    if (content.isNotEmpty) {
      try {
        final value = jsonDecode(content);
        if (value is Map) {
          decoded = Map<String, Object?>.from(value);
        }
      } on FormatException {
        throw const AccountException(
          'The server returned an invalid response.',
        );
      }
    }
    if (allowNotFound && response.statusCode == HttpStatus.notFound) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded?['error'];
      throw AccountException(
        error is String
            ? _messageForError(error)
            : 'Could not reach Recall backup.',
      );
    }
    if (decoded == null) {
      throw const AccountException('The server returned an invalid response.');
    }
    return decoded;
  }

  StoredSession _sessionFromResponse({
    required String serverUrl,
    required Map<String, Object?> response,
    required SecretKeyData masterKey,
  }) {
    final user = response['user'];
    final device = response['device'];
    if (user is! Map || device is! Map) {
      throw const AccountException(
        'The server returned an incomplete session.',
      );
    }
    return StoredSession(
      account: StoredAccount(
        serverUrl: serverUrl,
        userId: _requiredString(Map<String, Object?>.from(user), 'id'),
        email: _requiredString(Map<String, Object?>.from(user), 'email'),
        deviceId: _requiredString(Map<String, Object?>.from(device), 'id'),
      ),
      accessToken: _requiredString(response, 'accessToken'),
      refreshToken: _requiredString(response, 'refreshToken'),
      masterKey: masterKey,
    );
  }

  String _normalizeServerUrl(String rawUrl) {
    final value = rawUrl.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty) {
      throw const AccountException(
        'Enter a complete backup URL, including https://.',
      );
    }
    if (uri.scheme != 'https' &&
        uri.host != '10.0.2.2' &&
        uri.host != 'localhost') {
      throw const AccountException('Recall backup must use HTTPS.');
    }
    return uri.replace(path: '', query: null, fragment: null).toString();
  }

  Future<String> _readResponse(HttpClientResponse response) async {
    if (response.contentLength > _maxResponseBytes) {
      throw const AccountException('The server response was too large.');
    }
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in response) {
      length += chunk.length;
      if (length > _maxResponseBytes) {
        throw const AccountException('The server response was too large.');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }

  String _requiredString(Map<String, Object?> value, String key) {
    final field = value[key];
    if (field is! String || field.isEmpty) {
      throw const AccountException('The server returned an invalid session.');
    }
    return field;
  }

  String _messageForError(String error) {
    return switch (error) {
      'invalid_credentials' => 'Email or password is incorrect.',
      'registration_disabled' => 'Registration is disabled on this backup.',
      'email_already_registered' =>
        'An account with this email already exists.',
      'unauthorized' => 'This session is no longer authorized.',
      'invalid_recovery_key' => 'That recovery key is not valid.',
      _ => 'Recall backup rejected the request ($error).',
    };
  }
}
