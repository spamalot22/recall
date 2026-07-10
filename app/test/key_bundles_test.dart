import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/security/key_bundles.dart';

void main() {
  late KeyBundleService service;

  setUp(() {
    service = KeyBundleService(
      pbkdf2Iterations: 1000,
      minimumPbkdf2Iterations: 1000,
    );
  });

  test('unlocks the master key with the account password', () async {
    final masterKey = service.generateMasterKey();
    final recoveryKey = service.generateRecoveryKey();
    final bundle = await service.createBundle(
      masterKey: masterKey,
      password: 'correct horse battery staple',
      recoveryKey: recoveryKey,
    );

    final unlocked = await service.unlockWithPassword(
      bundle: bundle,
      password: 'correct horse battery staple',
    );

    expect(unlocked.bytes, masterKey.bytes);
  });

  test('unlocks the master key with the recovery key', () async {
    final masterKey = service.generateMasterKey();
    final recoveryKey = service.generateRecoveryKey();
    final bundle = await service.createBundle(
      masterKey: masterKey,
      password: 'correct horse battery staple',
      recoveryKey: recoveryKey,
    );

    final unlocked = await service.unlockWithRecoveryKey(
      bundle: bundle,
      recoveryKey: recoveryKey,
    );

    expect(unlocked.bytes, masterKey.bytes);
  });

  test('normalizes whitespace when unlocking with a recovery key', () async {
    final masterKey = service.generateMasterKey();
    final recoveryKey = service.generateRecoveryKey();
    final bundle = await service.createBundle(
      masterKey: masterKey,
      password: 'correct horse battery staple',
      recoveryKey: recoveryKey,
    );

    final unlocked = await service.unlockWithRecoveryKey(
      bundle: bundle,
      recoveryKey: '  $recoveryKey\n',
    );

    expect(unlocked.bytes, masterKey.bytes);
  });

  test('rejects an incorrect password', () async {
    final masterKey = service.generateMasterKey();
    final bundle = await service.createBundle(
      masterKey: masterKey,
      password: 'correct horse battery staple',
      recoveryKey: service.generateRecoveryKey(),
    );

    expect(
      () => service.unlockWithPassword(bundle: bundle, password: 'incorrect'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('serializes to the server key bundle shape', () async {
    final masterKey = service.generateMasterKey();
    final bundle = await service.createBundle(
      masterKey: masterKey,
      password: 'correct horse battery staple',
      recoveryKey: service.generateRecoveryKey(),
    );

    final json = bundle.toServerJson();

    expect(json['passwordWrappedMasterKey'], isA<String>());
    expect(json['recoveryWrappedMasterKey'], isA<String>());
    expect(json['kdfParams'], isA<Map<String, Object?>>());
    expect(json['version'], keyBundleVersion);

    final parsed = EncryptedMasterKeyBundle.fromServerJson(json);
    final unlocked = await service.unlockWithPassword(
      bundle: parsed,
      password: 'correct horse battery staple',
    );
    expect(unlocked.bytes, masterKey.bytes);
  });

  test('creates a stable verifier without exposing the recovery key', () async {
    const recoveryKey = 'abcd-1234-EFGH-5678';

    final verifier = await service.recoveryVerifier(recoveryKey);
    final verifierWithWhitespace = await service.recoveryVerifier(
      '  abcd-1234-EFGH-5678\n',
    );

    expect(verifier, verifierWithWhitespace);
    expect(verifier, isNot(contains('abcd')));
    expect(verifier.length, greaterThanOrEqualTo(40));
  });

  test('rejects unsafe or unsupported key bundle parameters', () async {
    final masterKey = service.generateMasterKey();
    final bundle = await service.createBundle(
      masterKey: masterKey,
      password: 'correct horse battery staple',
      recoveryKey: service.generateRecoveryKey(),
    );
    final unsafe = EncryptedMasterKeyBundle(
      version: bundle.version,
      passwordWrappedMasterKey: bundle.passwordWrappedMasterKey,
      recoveryWrappedMasterKey: bundle.recoveryWrappedMasterKey,
      kdfParams: {...bundle.kdfParams, 'iterations': 1},
    );

    expect(
      () => service.unlockWithPassword(
        bundle: unsafe,
        password: 'correct horse battery staple',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
