import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/security/record_cipher.dart';

void main() {
  test(
    'encrypts authenticated sync records without exposing note text',
    () async {
      final cipher = RecordCipher();
      final masterKey = SecretKeyData.random(length: 32);
      const payload = {
        'schema': 1,
        'note': {'title': 'Private plan', 'body': 'Meet at 10'},
      };

      final encrypted = await cipher.encryptJson(
        value: payload,
        masterKey: masterKey,
      );
      final decrypted = await cipher.decryptJson(
        encryptedValue: encrypted,
        masterKey: masterKey,
      );

      expect(encrypted, isNot(contains('Private plan')));
      expect(decrypted, payload);
    },
  );

  test('rejects a record encrypted with a different master key', () async {
    final cipher = RecordCipher();
    final encrypted = await cipher.encryptJson(
      value: const {
        'schema': 1,
        'note': {'title': 'Private'},
      },
      masterKey: SecretKeyData.random(length: 32),
    );

    expect(
      () => cipher.decryptJson(
        encryptedValue: encrypted,
        masterKey: SecretKeyData.random(length: 32),
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
