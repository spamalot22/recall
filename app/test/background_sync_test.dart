import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/account/secure_account_store.dart';
import 'package:recall_app/src/data/local_database.dart';
import 'package:recall_app/src/notes/notes_repository.dart';
import 'package:recall_app/src/sync/background_sync.dart';
import 'package:recall_app/src/sync/sync_execution_lock.dart';
import 'package:recall_app/src/sync/sync_service.dart';

void main() {
  test('background sync defaults to enabled every hour', () async {
    final store = BackgroundSyncSettingsStore(
      storage: _MemoryBackgroundSyncStorage(),
    );

    final settings = await store.read();

    expect(settings.enabled, isTrue);
    expect(settings.interval, const Duration(hours: 1));
  });

  test('invalid persisted intervals fall back to one hour', () async {
    final storage = _MemoryBackgroundSyncStorage();
    await storage.write('settings.background_sync.interval_minutes', '7');
    final store = BackgroundSyncSettingsStore(storage: storage);

    final settings = await store.read();

    expect(settings.interval, const Duration(hours: 1));
  });

  test('settings persist the enabled state and selected interval', () async {
    final store = BackgroundSyncSettingsStore(
      storage: _MemoryBackgroundSyncStorage(),
    );
    await store.writeSettings(
      const BackgroundSyncSettings(
        enabled: false,
        interval: Duration(hours: 6),
      ),
    );

    final settings = await store.read();

    expect(settings.enabled, isFalse);
    expect(settings.interval, const Duration(hours: 6));
  });

  test('successful sync diagnostics clear the previous failure', () async {
    final store = BackgroundSyncSettingsStore(
      storage: _MemoryBackgroundSyncStorage(),
    );
    final failedAt = DateTime.utc(2026, 7, 10, 12);
    final succeededAt = DateTime.utc(2026, 7, 10, 13);

    await store.recordFailure(failedAt, 'Network unavailable.');
    var settings = await store.read();
    expect(settings.lastAttemptAt, failedAt.toLocal());
    expect(settings.lastFailure, 'Network unavailable.');

    await store.recordSuccess(succeededAt);
    settings = await store.read();
    expect(settings.lastAttemptAt, succeededAt.toLocal());
    expect(settings.lastSuccessfulAt, succeededAt.toLocal());
    expect(settings.lastFailure, isNull);
  });

  test('pending count includes notes not yet in the sync journal', () async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await NotesRepository(
      database,
    ).createTextNote(title: '', body: 'Waiting to sync');
    final service = SyncService(
      database,
      _FakeAccountStore(connected: true),
      executionLock: const _ImmediateSyncExecutionLock(),
    );

    expect(await service.pendingChangeCount(), 1);
  });

  test('controller updates periodic work and cancels when disabled', () async {
    final scheduler = _RecordingBackgroundWorkScheduler();
    final store = BackgroundSyncSettingsStore(
      storage: _MemoryBackgroundSyncStorage(),
    );
    final controller = BackgroundSyncController(
      settingsStore: store,
      scheduler: scheduler,
      accountStore: _FakeAccountStore(connected: true),
    );

    await controller.refreshSchedule();
    expect(scheduler.periodicIntervals, [const Duration(hours: 1)]);

    await controller.updateSettings(
      enabled: true,
      interval: const Duration(hours: 3),
    );
    expect(scheduler.periodicIntervals.last, const Duration(hours: 3));

    await controller.updateSettings(
      enabled: false,
      interval: const Duration(hours: 3),
    );
    expect(scheduler.cancelCount, 1);
  });

  test(
    'controller only enqueues fallback work for connected accounts',
    () async {
      final connectedScheduler = _RecordingBackgroundWorkScheduler();
      final connected = BackgroundSyncController(
        settingsStore: BackgroundSyncSettingsStore(
          storage: _MemoryBackgroundSyncStorage(),
        ),
        scheduler: connectedScheduler,
        accountStore: _FakeAccountStore(connected: true),
      );
      await connected.enqueueOneOff();
      expect(connectedScheduler.oneOffCount, 1);

      final disconnectedScheduler = _RecordingBackgroundWorkScheduler();
      final disconnected = BackgroundSyncController(
        settingsStore: BackgroundSyncSettingsStore(
          storage: _MemoryBackgroundSyncStorage(),
        ),
        scheduler: disconnectedScheduler,
        accountStore: _FakeAccountStore(connected: false),
      );
      await disconnected.enqueueOneOff();
      expect(disconnectedScheduler.oneOffCount, 0);
    },
  );

  test('controller rolls settings back when OS scheduling fails', () async {
    final storage = _MemoryBackgroundSyncStorage();
    final store = BackgroundSyncSettingsStore(storage: storage);
    final scheduler = _RecordingBackgroundWorkScheduler()
      ..failPeriodicScheduling = true;
    final controller = BackgroundSyncController(
      settingsStore: store,
      scheduler: scheduler,
      accountStore: _FakeAccountStore(connected: true),
    );

    await expectLater(
      controller.updateSettings(
        enabled: true,
        interval: const Duration(hours: 6),
      ),
      throwsStateError,
    );

    expect((await store.read()).interval, const Duration(hours: 1));
  });

  test(
    'controller restores the previous OS schedule after a failure',
    () async {
      final scheduler = _RecordingBackgroundWorkScheduler()
        ..failNextPeriodicScheduling = true;
      final controller = BackgroundSyncController(
        settingsStore: BackgroundSyncSettingsStore(
          storage: _MemoryBackgroundSyncStorage(),
        ),
        scheduler: scheduler,
        accountStore: _FakeAccountStore(connected: true),
      );

      await expectLater(
        controller.updateSettings(
          enabled: true,
          interval: const Duration(hours: 6),
        ),
        throwsStateError,
      );

      expect(scheduler.periodicIntervals, [const Duration(hours: 1)]);
    },
  );

  test('worker exits successfully when background sync is disabled', () async {
    final store = BackgroundSyncSettingsStore(
      storage: _MemoryBackgroundSyncStorage(),
    );
    await store.writeSettings(
      const BackgroundSyncSettings(
        enabled: false,
        interval: Duration(hours: 1),
      ),
    );

    final succeeded = await runBackgroundSyncTask(
      settingsStore: store,
      accountStore: _FakeAccountStore(connected: true),
    );

    expect(succeeded, isTrue);
  });

  test('worker requests a retry when secure settings cannot be read', () async {
    final succeeded = await runBackgroundSyncTask(
      settingsStore: BackgroundSyncSettingsStore(
        storage: _FailingBackgroundSyncStorage(),
      ),
      accountStore: _FakeAccountStore(connected: true),
    );

    expect(succeeded, isFalse);
  });
}

class _MemoryBackgroundSyncStorage implements BackgroundSyncStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _RecordingBackgroundWorkScheduler implements BackgroundWorkScheduler {
  final List<Duration> periodicIntervals = [];
  int oneOffCount = 0;
  int cancelCount = 0;
  bool failPeriodicScheduling = false;
  bool failNextPeriodicScheduling = false;

  @override
  Future<void> schedulePeriodic(Duration interval) async {
    if (failPeriodicScheduling || failNextPeriodicScheduling) {
      failNextPeriodicScheduling = false;
      throw StateError('Scheduling failed');
    }
    periodicIntervals.add(interval);
  }

  @override
  Future<void> enqueueOneOff() async {
    oneOffCount++;
  }

  @override
  Future<void> cancelOneOff() async {}

  @override
  Future<void> cancel() async {
    cancelCount++;
  }
}

class _FailingBackgroundSyncStorage implements BackgroundSyncStorage {
  @override
  Future<String?> read(String key) => throw StateError('Storage unavailable');

  @override
  Future<void> write(String key, String value) =>
      throw StateError('Storage unavailable');
}

class _FakeAccountStore extends SecureAccountStore {
  _FakeAccountStore({required this.connected});

  final bool connected;

  @override
  Future<StoredSession?> readSession() async {
    if (!connected) {
      return null;
    }
    return StoredSession(
      account: const StoredAccount(
        serverUrl: 'https://example.com',
        userId: 'user-id',
        email: 'user@example.com',
        deviceId: 'device-id',
      ),
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      masterKey: SecretKeyData(List<int>.filled(32, 1)),
    );
  }
}

class _ImmediateSyncExecutionLock implements SyncExecutionLock {
  const _ImmediateSyncExecutionLock();

  @override
  Future<T> synchronized<T>(Future<T> Function() operation) => operation();
}
