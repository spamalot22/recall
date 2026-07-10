import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class RecordCipher {
  RecordCipher({AesGcm? cipher}) : _cipher = cipher ?? AesGcm.with256bits();

  static final _associatedData = utf8.encode('recall.sync-record.v1');

  final AesGcm _cipher;

  Future<String> encryptJson({
    required Map<String, Object?> value,
    required SecretKey masterKey,
  }) async {
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(value)),
      secretKey: masterKey,
      aad: _associatedData,
    );
    return base64UrlEncode(box.concatenation());
  }

  Future<Map<String, Object?>> decryptJson({
    required String encryptedValue,
    required SecretKey masterKey,
  }) async {
    final bytes = base64Url.decode(encryptedValue);
    final box = SecretBox.fromConcatenation(
      bytes,
      nonceLength: _cipher.nonceLength,
      macLength: _cipher.macAlgorithm.macLength,
    );
    final clearText = await _cipher.decrypt(
      box,
      secretKey: masterKey,
      aad: _associatedData,
    );
    final value = jsonDecode(utf8.decode(clearText));
    if (value is! Map) {
      throw const FormatException(
        'Encrypted record does not contain an object.',
      );
    }
    return Map<String, Object?>.from(value);
  }
}
