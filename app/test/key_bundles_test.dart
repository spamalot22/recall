import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/security/key_bundles.dart';

void main() {
  late KeyBundleService service;

  setUp(() {
    service = KeyBundleService(pbkdf2Iterations: 1000);
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

  test('rejects an incorrect password', () async {
    final masterKey = service.generateMasterKey();
    final bundle = await service.createBundle(
      masterKey: masterKey,
      password: 'correct horse battery staple',
      recoveryKey: service.generateRecoveryKey(),
    );

    expect(
      () => service.unlockWithPassword(
        bundle: bundle,
        password: 'incorrect',
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('serializes to the server key bundle shape', () async {
    final bundle = await service.createBundle(
      masterKey: service.generateMasterKey(),
      password: 'correct horse battery staple',
      recoveryKey: service.generateRecoveryKey(),
    );

    final json = bundle.toServerJson();

    expect(json['passwordWrappedMasterKey'], isA<String>());
    expect(json['recoveryWrappedMasterKey'], isA<String>());
    expect(json['kdfParams'], isA<Map<String, Object?>>());
    expect(json['version'], keyBundleVersion);
  });
}
