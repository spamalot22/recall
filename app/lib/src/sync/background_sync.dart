import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../account/secure_account_store.dart';
import '../data/local_database.dart';
import '../notes/notes_repository.dart';
import '../reminders/reminder_scheduler.dart';
import 'sync_service.dart';

const backgroundSyncIntervals = [
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(hours: 1),
  Duration(hours: 3),
  Duration(hours: 6),
  Duration(hours: 12),
  Duration(hours: 24),
];

class BackgroundSyncSettings {
  const BackgroundSyncSettings({
    required this.enabled,
    required this.interval,
    this.lastSuccessfulAt,
    this.lastAttemptAt,
    this.lastFailure,
  });

  static const defaults = BackgroundSyncSettings(
    enabled: true,
    interval: Duration(hours: 1),
  );

  final bool enabled;
  final Duration interval;
  final DateTime? lastSuccessfulAt;
  final DateTime? lastAttemptAt;
  final String? lastFailure;

  BackgroundSyncSettings copyWith({
    bool? enabled,
    Duration? interval,
    DateTime? lastSuccessfulAt,
    DateTime? lastAttemptAt,
    String? lastFailure,
  }) {
    return BackgroundSyncSettings(
      enabled: enabled ?? this.enabled,
      interval: interval ?? this.interval,
      lastSuccessfulAt: lastSuccessfulAt ?? this.lastSuccessfulAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastFailure: lastFailure ?? this.lastFailure,
    );
  }
}

abstract class BackgroundSyncStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class SecureBackgroundSyncStorage implements BackgroundSyncStorage {
  SecureBackgroundSyncStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class BackgroundSyncSettingsStore {
  BackgroundSyncSettingsStore({BackgroundSyncStorage? storage})
    : _storage = storage ?? SecureBackgroundSyncStorage();

  static const _enabledKey = 'settings.background_sync.enabled';
  static const _intervalMinutesKey =
      'settings.background_sync.interval_minutes';
  static const _lastSuccessfulAtKey =
      'settings.background_sync.last_successful_at';
  static const _lastAttemptAtKey = 'settings.background_sync.last_attempt_at';
  static const _lastFailureKey = 'settings.background_sync.last_failure';

  final BackgroundSyncStorage _storage;

  Future<BackgroundSyncSettings> read() async {
    final values = await Future.wait([
      _storage.read(_enabledKey),
      _storage.read(_intervalMinutesKey),
      _storage.read(_lastSuccessfulAtKey),
      _storage.read(_lastAttemptAtKey),
      _storage.read(_lastFailureKey),
    ]);
    final requestedInterval = Duration(
      minutes: int.tryParse(values[1] ?? '') ?? 60,
    );
    final interval = backgroundSyncIntervals.contains(requestedInterval)
        ? requestedInterval
        : BackgroundSyncSettings.defaults.interval;
    return BackgroundSyncSettings(
      enabled: values[0] != 'false',
      interval: interval,
      lastSuccessfulAt: DateTime.tryParse(values[2] ?? '')?.toLocal(),
      lastAttemptAt: DateTime.tryParse(values[3] ?? '')?.toLocal(),
      lastFailure: _nonEmpty(values[4]),
    );
  }

  Future<void> writeSettings(BackgroundSyncSettings settings) async {
    if (!backgroundSyncIntervals.contains(settings.interval)) {
      throw ArgumentError.value(
        settings.interval,
        'interval',
        'Background sync interval is not supported.',
      );
    }
    await Future.wait([
      _storage.write(_enabledKey, settings.enabled.toString()),
      _storage.write(
        _intervalMinutesKey,
        settings.interval.inMinutes.toString(),
      ),
    ]);
  }

  Future<void> recordAttempt(DateTime at) {
    return _storage.write(_lastAttemptAtKey, at.toUtc().toIso8601String());
  }

  Future<void> recordSuccess(DateTime at) async {
    final value = at.toUtc().toIso8601String();
    await Future.wait([
      _storage.write(_lastAttemptAtKey, value),
      _storage.write(_lastSuccessfulAtKey, value),
      _storage.write(_lastFailureKey, ''),
    ]);
  }

  Future<void> recordFailure(DateTime at, String reason) async {
    final value = at.toUtc().toIso8601String();
    await Future.wait([
      _storage.write(_lastAttemptAtKey, value),
      _storage.write(_lastFailureKey, reason),
    ]);
  }

  static String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

abstract class BackgroundWorkScheduler {
  Future<void> schedulePeriodic(Duration interval);

  Future<void> enqueueOneOff();

  Future<void> cancelOneOff();

  Future<void> cancel();
}

class DisabledBackgroundWorkScheduler implements BackgroundWorkScheduler {
  const DisabledBackgroundWorkScheduler();

  @override
  Future<void> schedulePeriodic(Duration interval) async {}

  @override
  Future<void> enqueueOneOff() async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> cancelOneOff() async {}
}

class BackgroundSyncController {
  BackgroundSyncController({
    BackgroundSyncSettingsStore? settingsStore,
    BackgroundWorkScheduler? scheduler,
    SecureAccountStore? accountStore,
  }) : _settingsStore = settingsStore ?? BackgroundSyncSettingsStore(),
       _scheduler = scheduler ?? const DisabledBackgroundWorkScheduler(),
       _accountStore = accountStore ?? SecureAccountStore();

  final BackgroundSyncSettingsStore _settingsStore;
  final BackgroundWorkScheduler _scheduler;
  final SecureAccountStore _accountStore;

  Future<BackgroundSyncSettings> loadSettings() => _settingsStore.read();

  Future<BackgroundSyncSettings> updateSettings({
    required bool enabled,
    required Duration interval,
  }) async {
    final current = await _settingsStore.read();
    final updated = current.copyWith(enabled: enabled, interval: interval);
    await _settingsStore.writeSettings(updated);
    try {
      await refreshSchedule(settings: updated);
    } on Object catch (error, stackTrace) {
      await _settingsStore.writeSettings(current);
      try {
        await refreshSchedule(settings: current);
      } on Object {
        // Preserve the original scheduling error for the caller.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    return updated;
  }

  Future<void> refreshSchedule({BackgroundSyncSettings? settings}) async {
    final current = settings ?? await _settingsStore.read();
    final hasAccount = await _accountStore.readSession() != null;
    if (!current.enabled || !hasAccount) {
      await _scheduler.cancel();
      return;
    }
    await _scheduler.schedulePeriodic(current.interval);
  }

  Future<void> enqueueOneOff() async {
    final settings = await _settingsStore.read();
    if (!settings.enabled || await _accountStore.readSession() == null) {
      return;
    }
    await _scheduler.enqueueOneOff();
  }

  Future<void> cancel() => _scheduler.cancel();

  Future<void> cancelPending() => _scheduler.cancelOneOff();
}

@visibleForTesting
Future<bool> runBackgroundSyncTask({
  BackgroundSyncSettingsStore? settingsStore,
  SecureAccountStore? accountStore,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = settingsStore ?? BackgroundSyncSettingsStore();
  final accounts = accountStore ?? SecureAccountStore();
  late final BackgroundSyncSettings settings;
  try {
    settings = await store.read();
    if (!settings.enabled || await accounts.readSession() == null) {
      return true;
    }
  } on Object {
    return false;
  }

  try {
    await store.recordAttempt(DateTime.now());
  } on Object {
    // Sync status is diagnostic and must not block the actual backup.
  }
  final database = LocalDatabase(databaseKey: accounts.readOrCreateDatabaseKey);
  final reminderScheduler = ReminderScheduler();
  try {
    final result = await SyncService(database, accounts).sync();
    if (!result.connected) {
      return true;
    }
    try {
      await store.recordSuccess(DateTime.now());
    } on Object {
      // The encrypted data is already synchronized.
    }
    try {
      final reminders = await NotesRepository(
        database,
      ).loadScheduledReminders();
      await reminderScheduler.reconcileNoteReminders(
        reminders,
        requestPermissions: false,
      );
    } on Object {
      // Reminder reconciliation is independent of encrypted backup success.
    }
    return true;
  } on SyncException catch (error) {
    await _recordBackgroundFailure(store, error.message);
    return !error.retryable;
  } on SocketException catch (_) {
    await _recordBackgroundFailure(store, 'Network unavailable.');
    return false;
  } on HttpException catch (_) {
    await _recordBackgroundFailure(store, 'Could not reach Recall backup.');
    return false;
  } on TimeoutException catch (_) {
    await _recordBackgroundFailure(store, 'Recall backup timed out.');
    return false;
  } on Object {
    await _recordBackgroundFailure(store, 'Background sync could not finish.');
    return true;
  } finally {
    reminderScheduler.dispose();
    await database.close();
  }
}

Future<void> _recordBackgroundFailure(
  BackgroundSyncSettingsStore store,
  String reason,
) async {
  try {
    await store.recordFailure(DateTime.now(), reason);
  } on Object {
    // A diagnostic write must not alter the scheduler's retry behavior.
  }
}
