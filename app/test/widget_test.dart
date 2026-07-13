import 'dart:async';

import 'package:dynamic_color/samples.dart';
import 'package:dynamic_color/test_utils.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:recall_app/main.dart';
import 'package:recall_app/src/account/secure_account_store.dart';
import 'package:recall_app/src/data/local_database.dart';
import 'package:recall_app/src/notes/note_models.dart';
import 'package:recall_app/src/notes/notes_repository.dart';
import 'package:recall_app/src/providers.dart';
import 'package:recall_app/src/reminders/reminder_scheduler.dart';
import 'package:recall_app/src/sync/sync_service.dart';
import 'package:recall_app/src/sync/background_sync.dart';
import 'package:recall_app/src/updates/update_service.dart';

void main() {
  setUp(() => DynamicColorTestingUtils.setMockDynamicColors());

  testWidgets('uses the Android Material dynamic color scheme', (tester) async {
    DynamicColorTestingUtils.setMockDynamicColors(
      corePalette: SampleCorePalettes.green,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith((ref) => Stream.value(const [])),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(RecallHomePage));
    expect(
      Theme.of(context).colorScheme.primary,
      SampleColorSchemes.green(Brightness.light).primary,
    );
  });

  testWidgets('Recall home screen renders note cards', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith((ref) => Stream.value(sampleNotes)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();

    expect(find.text('Recall'), findsOneWidget);
    expect(find.text('Search notes'), findsOneWidget);
    expect(find.text('Monthly filter order'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('new note opens body-first with an optional title', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith((ref) => Stream.value(sampleNotes)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('New note'), findsOneWidget);
    expect(find.text('Title (optional)'), findsOneWidget);
    expect(find.text('Start writing...'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    final bodyField = tester.widget<TextField>(
      find.byKey(const Key('note-body-field')),
    );
    expect(bodyField.focusNode?.hasFocus, isTrue);

    addTearDown(tester.view.resetViewInsets);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    final scaffold = find.byType(Scaffold);
    final scaffoldHeight = tester.getSize(scaffold).height;
    final keyboardInset = MediaQuery.viewInsetsOf(
      tester.element(scaffold),
    ).bottom;
    final reminderButton = find.byTooltip('Add reminder');
    expect(
      tester.getRect(reminderButton).bottom,
      lessThanOrEqualTo(scaffoldHeight - keyboardInset),
    );

    await tester.tap(reminderButton);
    await tester.pumpAndSettle();

    expect(bodyField.focusNode?.hasFocus, isFalse);
    expect(find.text('In one hour'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('Next Monday'), findsOneWidget);
    expect(find.text('Repeat'), findsOneWidget);
  });

  testWidgets('titleless notes lead with their content', (tester) async {
    const titleless = NotePreview(
      id: 'titleless',
      title: '',
      body: 'The body is the note',
      mood: ColorMood.focus,
      reminderLabel: '',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith(
            (ref) => Stream.value(const [titleless]),
          ),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();

    expect(find.text('The body is the note'), findsOneWidget);
    expect(find.text('Untitled'), findsNothing);
    expect(find.byTooltip('Use list layout'), findsOneWidget);

    await tester.tap(find.byTooltip('Use list layout'));
    await tester.pump();
    expect(find.byTooltip('Use grid layout'), findsOneWidget);
  });

  testWidgets('swiping a note archives it with undo feedback', (tester) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = NotesRepository(database);
    final noteId = await repository.createTextNote(
      title: 'Swipe me',
      body: 'Archive this note from the home screen.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byType(Dismissible);
    final cardWidth = tester.getSize(card).width;
    await tester.drag(card, Offset(-cardWidth * 0.8, 0), touchSlopY: 0);
    await tester.pumpAndSettle();

    expect(find.text('Note archived.'), findsOneWidget);
    final archived = await (database.select(
      database.notes,
    )..where((note) => note.id.equals(noteId))).getSingle();
    expect(archived.isArchived, isTrue);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Swipe me'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('back saves a non-empty titleless note', (tester) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          notePreviewsProvider.overrideWith((ref) => Stream.value(const [])),
          reminderSchedulerProvider.overrideWithValue(
            _FailingCancellationReminderScheduler(),
          ),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note-body-field')),
      'Captured without a title',
    );
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    final notes = await database.select(database.notes).get();
    expect(notes, hasLength(1));
    expect(notes.single.title, isEmpty);
    expect(notes.single.body, 'Captured without a title');
    expect(
      find.text('Note saved, but the reminder could not be scheduled.'),
      findsNothing,
    );
  });

  testWidgets('trashing closes the editor when reminder cleanup fails', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = NotesRepository(database);
    final noteId = await repository.createTextNote(
      title: 'Trash me',
      body: 'Close after moving this note.',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          notePreviewsProvider.overrideWith(
            (ref) => Stream.value([
              NotePreview(
                id: noteId,
                title: 'Trash me',
                body: 'Close after moving this note.',
                mood: ColorMood.clear,
                reminderLabel: '',
              ),
            ]),
          ),
          reminderSchedulerProvider.overrideWithValue(
            _FailingCancellationReminderScheduler(),
          ),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Trash me'));
    await tester.pumpAndSettle();
    expect(find.text('Edit note'), findsOneWidget);

    await tester.tap(find.byTooltip('Note actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to trash'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Move to trash'));
    await tester.pumpAndSettle();

    expect(find.text('Edit note'), findsNothing);
    expect(
      find.text(
        'Note moved to trash, but its reminder could not be cancelled.',
      ),
      findsOneWidget,
    );
    final note = await (database.select(
      database.notes,
    )..where((entry) => entry.id.equals(noteId))).getSingle();
    expect(note.trashedAt, isNotNull);
  });

  testWidgets('notification tap opens the linked note', (tester) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = NotesRepository(database);
    final noteId = await repository.createTextNote(
      title: 'Open from reminder',
      body: 'The notification links here.',
    );
    final scheduler = _NoopReminderScheduler();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          notePreviewsProvider.overrideWith(
            (ref) => Stream.value(const [
              NotePreview(
                id: 'notification-note',
                title: 'Open from reminder',
                body: 'The notification links here.',
                mood: ColorMood.clear,
                reminderLabel: '',
              ),
            ]),
          ),
          reminderSchedulerProvider.overrideWithValue(scheduler),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pump();

    scheduler.openNote(noteId);
    await tester.pumpAndSettle();

    expect(find.byType(NoteEditorPage), findsOneWidget);
    final titleField = tester.widget<TextField>(
      find.byKey(const Key('note-title-field')),
    );
    expect(titleField.controller?.text, 'Open from reminder');
  });

  testWidgets('manual update check closes settings before showing status', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith((ref) => Stream.value(sampleNotes)),
          updateServiceProvider.overrideWithValue(_NoUpdateService()),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text('Check for updates'), findsNothing);
    expect(find.text('Recall is up to date.'), findsOneWidget);
  });

  testWidgets('startup automatically offers an available update', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          notePreviewsProvider.overrideWith((ref) => Stream.value(const [])),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          updateServiceProvider.overrideWithValue(_AvailableUpdateService()),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundSyncControllerProvider.overrideWithValue(
            BackgroundSyncController(
              settingsStore: BackgroundSyncSettingsStore(
                storage: _MemoryBackgroundSyncStorage(),
              ),
              scheduler: _NoopBackgroundWorkScheduler(),
            ),
          ),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(find.textContaining('Recall 0.1.8 is available'), findsOneWidget);
    expect(find.text('Install'), findsOneWidget);
  });

  testWidgets('settings opens encrypted backup account setup', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith((ref) => Stream.value(sampleNotes)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect encrypted backup'));
    await tester.pumpAndSettle();

    expect(find.text('Connect your backup'), findsOneWidget);
    expect(find.text('Backup URL'), findsOneWidget);
    expect(find.text('Use a recovery key'), findsOneWidget);
  });

  testWidgets('settings reports background sync hotfix status', (tester) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final session = StoredSession(
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
    final backgroundSync = BackgroundSyncController(
      settingsStore: BackgroundSyncSettingsStore(
        storage: _MemoryBackgroundSyncStorage(),
      ),
      scheduler: _NoopBackgroundWorkScheduler(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          notePreviewsProvider.overrideWith((ref) => Stream.value(sampleNotes)),
          storedSessionProvider.overrideWith((ref) async => session),
          syncServiceProvider.overrideWithValue(
            _NoopSyncService(database, pendingCount: 2),
          ),
          backgroundSyncControllerProvider.overrideWithValue(backgroundSync),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Background sync'), findsOneWidget);
    expect(
      find.text('Temporarily disabled; sync still runs when Recall opens'),
      findsOneWidget,
    );
    expect(find.text('Sync frequency'), findsNothing);
    expect(find.text('Last successful sync'), findsOneWidget);
    expect(find.text('Last attempt'), findsOneWidget);
    expect(find.text('2 waiting to sync'), findsOneWidget);
  });
}

class _NoUpdateService extends UpdateService {
  @override
  Future<UpdateCheckResult> checkForUpdate({
    String currentVersion = appVersion,
  }) async {
    return UpdateCheckResult(
      currentVersion: const SemanticVersion(1, 0, 0),
      latestVersion: const SemanticVersion(1, 0, 0),
      apkName: 'recall-android-1.0.0.apk',
      apkDownloadUrl: Uri.parse('https://example.com/recall.apk'),
      releaseUrl: Uri.parse('https://example.com/releases/1.0.0'),
      updateAvailable: false,
    );
  }
}

class _AvailableUpdateService extends UpdateService {
  @override
  Future<UpdateCheckResult> checkForUpdate({
    String currentVersion = appVersion,
  }) async {
    return UpdateCheckResult(
      currentVersion: const SemanticVersion(0, 1, 7),
      latestVersion: const SemanticVersion(0, 1, 8),
      apkName: 'recall-android-0.1.8.apk',
      apkDownloadUrl: Uri.parse(
        'https://github.com/spamalot22/recall/releases/download/0.1.8/recall-android-0.1.8.apk',
      ),
      releaseUrl: Uri.parse(
        'https://github.com/spamalot22/recall/releases/tag/0.1.8',
      ),
      downloadSizeBytes: 63634094,
      updateAvailable: true,
    );
  }
}

class _NoopReminderScheduler extends ReminderScheduler {
  final _openRequests = StreamController<String>.broadcast();

  @override
  Stream<String> get openNoteRequests => _openRequests.stream;

  void openNote(String noteId) => _openRequests.add(noteId);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> cancelNoteReminder(String noteId) async {}

  @override
  Future<void> reconcileNoteReminders(
    List<ScheduledNoteReminder> schedules, {
    bool requestPermissions = true,
  }) async {}

  @override
  Future<void> scheduleNoteReminder({
    required String noteId,
    required String title,
    required String body,
    required NoteReminder reminder,
    bool requestPermissions = true,
  }) async {}

  @override
  void dispose() {
    _openRequests.close();
    super.dispose();
  }
}

class _FailingCancellationReminderScheduler extends _NoopReminderScheduler {
  @override
  Future<void> cancelNoteReminder(String noteId) async {
    throw StateError('Notification service unavailable');
  }
}

class _NoopSyncService extends SyncService {
  _NoopSyncService(LocalDatabase database, {this.pendingCount = 0})
    : super(database, SecureAccountStore());

  final int pendingCount;

  @override
  Future<SyncResult> sync() async => const SyncResult(connected: false);

  @override
  Future<int> pendingChangeCount() async => pendingCount;
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

class _NoopBackgroundWorkScheduler implements BackgroundWorkScheduler {
  @override
  Future<void> cancel() async {}

  @override
  Future<void> cancelOneOff() async {}

  @override
  Future<void> enqueueOneOff() async {}

  @override
  Future<void> schedulePeriodic(Duration interval) async {}
}
