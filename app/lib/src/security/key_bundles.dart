import 'dart:convert';

import 'package:cryptography/cryptography.dart';

const keyBundleVersion = 1;
const masterKeyBytes = 32;
const saltBytes = 16;
const wrappingKeyBits = 256;
const defaultPbkdf2Iterations = 310000;
const maximumPbkdf2Iterations = 1000000;

class KeyBundleService {
  KeyBundleService({
    AesGcm? cipher,
    int pbkdf2Iterations = defaultPbkdf2Iterations,
    int minimumPbkdf2Iterations = defaultPbkdf2Iterations,
  }) : _cipher = cipher ?? AesGcm.with256bits(),
       _pbkdf2Iterations = pbkdf2Iterations,
       _minimumPbkdf2Iterations = minimumPbkdf2Iterations {
    if (pbkdf2Iterations < minimumPbkdf2Iterations ||
        pbkdf2Iterations > maximumPbkdf2Iterations) {
      throw ArgumentError.value(
        pbkdf2Iterations,
        'pbkdf2Iterations',
        'Must be within the configured safe bounds.',
      );
    }
  }

  final AesGcm _cipher;
  final int _pbkdf2Iterations;
  final int _minimumPbkdf2Iterations;

  SecretKeyData generateMasterKey() {
    return SecretKeyData.random(length: masterKeyBytes);
  }

  String generateRecoveryKey() {
    final bytes = SecretKeyData.random(length: masterKeyBytes).bytes;
    final encoded = base64UrlEncode(bytes).replaceAll('=', '');
    return _group(encoded, 4);
  }

  Future<String> recoveryVerifier(String recoveryKey) async {
    final normalized = _normalizeRecoveryKey(recoveryKey);
    final hash = await Sha256().hash(utf8.encode(normalized));
    return base64UrlEncode(hash.bytes).replaceAll('=', '');
  }

  Future<EncryptedMasterKeyBundle> createBundle({
    required SecretKey masterKey,
    required String password,
    required String recoveryKey,
  }) async {
    return EncryptedMasterKeyBundle(
      version: keyBundleVersion,
      passwordWrappedMasterKey: await _wrapMasterKey(
        masterKey,
        password,
        _pbkdf2Iterations,
      ),
      recoveryWrappedMasterKey: await _wrapMasterKey(
        masterKey,
        _normalizeRecoveryKey(recoveryKey),
        _pbkdf2Iterations,
      ),
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
  }) async {
    final iterations = _validateBundle(bundle);
    return _unwrapMasterKey(
      bundle.passwordWrappedMasterKey,
      password,
      iterations,
    );
  }

  Future<SecretKeyData> unlockWithRecoveryKey({
    required EncryptedMasterKeyBundle bundle,
    required String recoveryKey,
  }) async {
    final iterations = _validateBundle(bundle);
    return _unwrapMasterKey(
      bundle.recoveryWrappedMasterKey,
      _normalizeRecoveryKey(recoveryKey),
      iterations,
    );
  }

  Future<WrappedMasterKey> _wrapMasterKey(
    SecretKey masterKey,
    String secret,
    int iterations,
  ) async {
    final salt = SecretKeyData.random(length: saltBytes).bytes;
    final wrappingKey = await _deriveWrappingKey(secret, salt, iterations);
    final masterKeyData = await masterKey.extractBytes();
    final box = await _cipher.encrypt(masterKeyData, secretKey: wrappingKey);

    return WrappedMasterKey(
      algorithm: 'aes-256-gcm',
      kdf: 'pbkdf2-hmac-sha256',
      salt: base64UrlEncode(salt),
      encryptedKey: base64UrlEncode(box.concatenation()),
    );
  }

  Future<SecretKeyData> _unwrapMasterKey(
    WrappedMasterKey wrappedKey,
    String secret,
    int iterations,
  ) async {
    final salt = _decodeBase64(wrappedKey.salt, expectedLength: saltBytes);
    final boxBytes = _decodeBase64(
      wrappedKey.encryptedKey,
      expectedLength:
          _cipher.nonceLength + masterKeyBytes + _cipher.macAlgorithm.macLength,
    );
    final wrappingKey = await _deriveWrappingKey(secret, salt, iterations);
    final box = SecretBox.fromConcatenation(
      boxBytes,
      nonceLength: _cipher.nonceLength,
      macLength: _cipher.macAlgorithm.macLength,
    );
    final clearText = await _cipher.decrypt(box, secretKey: wrappingKey);
    if (clearText.length != masterKeyBytes) {
      throw const FormatException('Invalid wrapped master key length.');
    }

    return SecretKeyData(clearText);
  }

  Future<SecretKey> _deriveWrappingKey(
    String secret,
    List<int> salt,
    int iterations,
  ) {
    return Pbkdf2.hmacSha256(
      iterations: iterations,
      bits: wrappingKeyBits,
    ).deriveKeyFromPassword(password: secret, nonce: salt);
  }

  int _validateBundle(EncryptedMasterKeyBundle bundle) {
    if (bundle.version != keyBundleVersion ||
        bundle.passwordWrappedMasterKey.algorithm != 'aes-256-gcm' ||
        bundle.recoveryWrappedMasterKey.algorithm != 'aes-256-gcm' ||
        bundle.passwordWrappedMasterKey.kdf != 'pbkdf2-hmac-sha256' ||
        bundle.recoveryWrappedMasterKey.kdf != 'pbkdf2-hmac-sha256' ||
        bundle.kdfParams['algorithm'] != 'pbkdf2-hmac-sha256' ||
        bundle.kdfParams['bits'] != wrappingKeyBits) {
      throw const FormatException('Unsupported encrypted key bundle.');
    }
    final iterations = bundle.kdfParams['iterations'];
    if (iterations is! int ||
        iterations < _minimumPbkdf2Iterations ||
        iterations > maximumPbkdf2Iterations) {
      throw const FormatException('Unsafe key derivation parameters.');
    }
    _decodeBase64(
      bundle.passwordWrappedMasterKey.salt,
      expectedLength: saltBytes,
    );
    _decodeBase64(
      bundle.recoveryWrappedMasterKey.salt,
      expectedLength: saltBytes,
    );
    return iterations;
  }
}

List<int> _decodeBase64(String value, {required int expectedLength}) {
  try {
    final decoded = base64Url.decode(value);
    if (decoded.length != expectedLength) {
      throw const FormatException('Invalid encrypted key bundle length.');
    }
    return decoded;
  } on FormatException {
    throw const FormatException('Invalid encrypted key bundle encoding.');
  }
}

String _normalizeRecoveryKey(String recoveryKey) {
  return recoveryKey.trim().replaceAll(RegExp(r'\s+'), '');
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

  factory EncryptedMasterKeyBundle.fromServerJson(Map<String, Object?> json) {
    final passwordWrapped = json['passwordWrappedMasterKey'];
    final recoveryWrapped = json['recoveryWrappedMasterKey'];
    final kdfParams = json['kdfParams'];
    final version = json['version'];

    if (passwordWrapped is! String ||
        recoveryWrapped is! String ||
        kdfParams is! Map ||
        version is! int) {
      throw const FormatException('Invalid encrypted key bundle.');
    }

    return EncryptedMasterKeyBundle(
      version: version,
      passwordWrappedMasterKey: WrappedMasterKey.fromJson(
        _jsonObject(passwordWrapped),
      ),
      recoveryWrappedMasterKey: WrappedMasterKey.fromJson(
        _jsonObject(recoveryWrapped),
      ),
      kdfParams: Map<String, Object?>.from(kdfParams),
    );
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

  factory WrappedMasterKey.fromJson(Map<String, Object?> json) {
    final algorithm = json['algorithm'];
    final kdf = json['kdf'];
    final salt = json['salt'];
    final encryptedKey = json['encryptedKey'];
    if (algorithm is! String ||
        kdf is! String ||
        salt is! String ||
        encryptedKey is! String) {
      throw const FormatException('Invalid wrapped master key.');
    }

    return WrappedMasterKey(
      algorithm: algorithm,
      kdf: kdf,
      salt: salt,
      encryptedKey: encryptedKey,
    );
  }
}

Map<String, Object?> _jsonObject(String source) {
  final value = jsonDecode(source);
  if (value is! Map) {
    throw const FormatException('Invalid wrapped master key payload.');
  }
  return Map<String, Object?>.from(value);
}

String _group(String value, int width) {
  final parts = <String>[];

  for (var index = 0; index < value.length; index += width) {
    final end = index + width;
    parts.add(value.substring(index, end > value.length ? value.length : end));
  }

  return parts.join('-');
}
