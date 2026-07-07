import 'dart:convert';

import 'package:cryptography/cryptography.dart';

const keyBundleVersion = 1;
const masterKeyBytes = 32;
const saltBytes = 16;
const wrappingKeyBits = 256;
const defaultPbkdf2Iterations = 310000;

class KeyBundleService {
  KeyBundleService({
    AesGcm? cipher,
    Pbkdf2? kdf,
    int pbkdf2Iterations = defaultPbkdf2Iterations,
  })  : _cipher = cipher ?? AesGcm.with256bits(),
        _kdf = kdf ??
            Pbkdf2.hmacSha256(
              iterations: pbkdf2Iterations,
              bits: wrappingKeyBits,
            ),
        _pbkdf2Iterations = pbkdf2Iterations;

  final AesGcm _cipher;
  final Pbkdf2 _kdf;
  final int _pbkdf2Iterations;

  SecretKeyData generateMasterKey() {
    return SecretKeyData.random(length: masterKeyBytes);
  }

  String generateRecoveryKey() {
    final bytes = SecretKeyData.random(length: masterKeyBytes).bytes;
    final encoded = base64UrlEncode(bytes).replaceAll('=', '');
    return _group(encoded, 4);
  }

  Future<EncryptedMasterKeyBundle> createBundle({
    required SecretKey masterKey,
    required String password,
    required String recoveryKey,
  }) async {
    return EncryptedMasterKeyBundle(
      version: keyBundleVersion,
      passwordWrappedMasterKey: await _wrapMasterKey(masterKey, password),
      recoveryWrappedMasterKey: await _wrapMasterKey(masterKey, recoveryKey),
      kdfParams: {
        'algorithm': 'pbkdf2-hmac-sha256',
        'iterations': _pbkdf2Iterations,
        'bits': wrappingKeyBits,
      },
    );
  }

  Future<SecretKeyData> unlockWithPassword({
    required EncryptedMasterKeyBundle bundle,
    required String password,
  }) {
    return _unwrapMasterKey(bundle.passwordWrappedMasterKey, password);
  }

  Future<SecretKeyData> unlockWithRecoveryKey({
    required EncryptedMasterKeyBundle bundle,
    required String recoveryKey,
  }) {
    return _unwrapMasterKey(bundle.recoveryWrappedMasterKey, recoveryKey);
  }

  Future<WrappedMasterKey> _wrapMasterKey(SecretKey masterKey, String secret) async {
    final salt = SecretKeyData.random(length: saltBytes).bytes;
    final wrappingKey = await _deriveWrappingKey(secret, salt);
    final masterKeyData = await masterKey.extractBytes();
    final box = await _cipher.encrypt(masterKeyData, secretKey: wrappingKey);

    return WrappedMasterKey(
      algorithm: 'aes-256-gcm',
      kdf: 'pbkdf2-hmac-sha256',
      salt: base64UrlEncode(salt),
      encryptedKey: base64UrlEncode(box.concatenation()),
    );
  }

  Future<SecretKeyData> _unwrapMasterKey(WrappedMasterKey wrappedKey, String secret) async {
    final salt = base64Url.decode(wrappedKey.salt);
    final boxBytes = base64Url.decode(wrappedKey.encryptedKey);
    final wrappingKey = await _deriveWrappingKey(secret, salt);
    final box = SecretBox.fromConcatenation(
      boxBytes,
      nonceLength: _cipher.nonceLength,
      macLength: _cipher.macAlgorithm.macLength,
    );
    final clearText = await _cipher.decrypt(box, secretKey: wrappingKey);

    return SecretKeyData(clearText);
  }

  Future<SecretKey> _deriveWrappingKey(String secret, List<int> salt) {
    return _kdf.deriveKeyFromPassword(
      password: secret,
      nonce: salt,
    );
  }
}

class EncryptedMasterKeyBundle {
  const EncryptedMasterKeyBundle({
    required this.version,
    required this.passwordWrappedMasterKey,
    required this.recoveryWrappedMasterKey,
    required this.kdfParams,
  });

  final int version;
  final WrappedMasterKey passwordWrappedMasterKey;
  final WrappedMasterKey recoveryWrappedMasterKey;
  final Map<String, Object?> kdfParams;

  Map<String, Object?> toServerJson() {
    return {
      'version': version,
      'passwordWrappedMasterKey': jsonEncode(passwordWrappedMasterKey.toJson()),
      'recoveryWrappedMasterKey': jsonEncode(recoveryWrappedMasterKey.toJson()),
      'kdfParams': kdfParams,
    };
  }
}

class WrappedMasterKey {
  const WrappedMasterKey({
    required this.algorithm,
    required this.kdf,
    required this.salt,
    required this.encryptedKey,
  });

  final String algorithm;
  final String kdf;
  final String salt;
  final String encryptedKey;

  Map<String, Object?> toJson() {
    return {
      'algorithm': algorithm,
      'kdf': kdf,
      'salt': salt,
      'encryptedKey': encryptedKey,
    };
  }
}

String _group(String value, int width) {
  final parts = <String>[];

  for (var index = 0; index < value.length; index += width) {
    final end = index + width;
    parts.add(value.substring(index, end > value.length ? value.length : end));
  }

  return parts.join('-');
}
