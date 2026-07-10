import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:recall_app/main.dart';
import 'package:recall_app/src/account/secure_account_store.dart';
import 'package:recall_app/src/data/local_database.dart';
import 'package:recall_app/src/notes/note_models.dart';
import 'package:recall_app/src/providers.dart';
import 'package:recall_app/src/reminders/reminder_scheduler.dart';
import 'package:recall_app/src/sync/sync_service.dart';
import 'package:recall_app/src/updates/update_service.dart';

void main() {
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

    await tester.tap(find.byTooltip('Add reminder'));
    await tester.pumpAndSettle();

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

  testWidgets('back saves a non-empty titleless note', (tester) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          notePreviewsProvider.overrideWith((ref) => Stream.value(const [])),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
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

class _NoopReminderScheduler extends ReminderScheduler {
  @override
  Future<void> cancelNoteReminder(String noteId) async {}

  @override
  Future<void> reconcileNoteReminders(
    List<ScheduledNoteReminder> schedules,
  ) async {}

  @override
  Future<void> scheduleNoteReminder({
    required String noteId,
    required String title,
    required String body,
    required NoteReminder reminder,
  }) async {}
}

class _NoopSyncService extends SyncService {
  _NoopSyncService(LocalDatabase database)
    : super(database, SecureAccountStore());

  @override
  Future<SyncResult> sync() async => const SyncResult(connected: false);
}
