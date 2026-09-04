import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/data/local_database.dart';
import 'package:recall_app/src/notes/mood_analyzer.dart';
import 'package:recall_app/src/notes/note_models.dart';
import 'package:recall_app/src/notes/notes_repository.dart';

void main() {
  late LocalDatabase database;
  late NotesRepository repository;

  setUp(() {
    database = LocalDatabase.forTesting(NativeDatabase.memory());
    repository = NotesRepository(
      database,
      moodAnalyzer: RecallMoodAnalyzer(classifier: _NeutralEmotionClassifier()),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('creates a persisted text note with an automatic mood', () async {
    await repository.createTextNote(
      title: 'Buy filters',
      body: 'Pick up the right size',
    );

    final notes = await repository.watchNotePreviews().first;

    expect(notes, hasLength(1));
    expect(notes.single.title, 'Buy filters');
    expect(notes.single.body, 'Pick up the right size');
    expect(notes.single.mood, ColorMood.errand);
  });

  test('repairs previously clear automatic moods in previews', () async {
    await repository.createTextNote(
      title: 'Buy groceries',
      body: 'Pick up milk',
    );
    await database
        .update(database.notes)
        .write(
          const NotesCompanion(
            mood: Value('clear'),
            moodModelVersion: Value(currentMoodModelVersion - 1),
          ),
        );

    final preview = await repository.watchNotePreviews().first;

    final stored = await database.select(database.notes).getSingle();
    expect(preview.single.mood, ColorMood.errand);
    expect(stored.mood, ColorMood.errand.name);
    expect(stored.moodModelVersion, currentMoodModelVersion);
  });

  test(
    'recalculates old automatic colours without preserving false urgency',
    () async {
      await repository.createTextNote(
        title: '',
        body: 'I feel sad and disappointed today',
      );
      await database
          .update(database.notes)
          .write(
            const NotesCompanion(
              mood: Value('urgent'),
              moodModelVersion: Value(currentMoodModelVersion - 1),
            ),
          );

      final preview = await repository.watchNotePreviews().first;
      final stored = await database.select(database.notes).getSingle();

      expect(preview.single.mood, isNot(ColorMood.urgent));
      expect(stored.mood, preview.single.mood.name);
      expect(stored.moodModelVersion, currentMoodModelVersion);
    },
  );

  test('preserves a manually selected clear mood', () async {
    await repository.createTextNote(
      title: 'No automatic colour',
      body: 'Keep my explicit choice',
      mood: ColorMood.clear,
    );

    final preview = await repository.watchNotePreviews().first;
    final stored = await database.select(database.notes).getSingle();

    expect(preview.single.mood, ColorMood.clear);
    expect(stored.moodIsAutomatic, isFalse);
  });

  test('persists manual note order without edits moving cards', () async {
    final firstId = await repository.createTextNote(title: 'First', body: '');
    final secondId = await repository.createTextNote(title: 'Second', body: '');
    final thirdId = await repository.createTextNote(title: 'Third', body: '');

    expect(
      (await repository.watchNotePreviews().first).map((note) => note.id),
      [thirdId, secondId, firstId],
    );

    await repository.reorderNotes([secondId, firstId, thirdId]);
    await repository.updateTextNote(
      id: firstId,
      title: 'First edited',
      body: '',
      pinned: false,
    );

    expect(
      (await repository.watchNotePreviews().first).map((note) => note.id),
      [secondId, firstId, thirdId],
    );
  });

  test('moving a note between pin groups places it first', () async {
    final firstPinnedId = await repository.createTextNote(
      title: 'First pinned',
      body: '',
      pinned: true,
    );
    final secondPinnedId = await repository.createTextNote(
      title: 'Second pinned',
      body: '',
      pinned: true,
    );
    final unpinnedId = await repository.createTextNote(
      title: 'Move me',
      body: '',
    );

    await repository.updateTextNote(
      id: unpinnedId,
      title: 'Move me',
      body: '',
      pinned: true,
    );

    expect(
      (await repository.watchNotePreviews().first).map((note) => note.id),
      [unpinnedId, secondPinnedId, firstPinnedId],
    );
  });

  test(
    'keeps titles optional and automatic moods responsive to edits',
    () async {
      final noteId = await repository.createTextNote(
        title: '',
        body: 'Buy filters at the store',
      );

      var loaded = await repository.loadNoteForEditing(noteId);
      expect(loaded?.title, isEmpty);
      expect(loaded?.mood, ColorMood.errand);
      expect(loaded?.moodIsAutomatic, isTrue);
      var stored = await database.select(database.notes).getSingle();
      expect(stored.moodModelVersion, currentMoodModelVersion);
      expect(stored.moodConfidence, inInclusiveRange(0, 1));

      await repository.updateTextNote(
        id: noteId,
        title: '',
        body: 'Study the project plan',
        mood: null,
        pinned: false,
      );
      loaded = await repository.loadNoteForEditing(noteId);
      expect(loaded?.mood, ColorMood.focus);
      expect(loaded?.moodIsAutomatic, isTrue);

      await repository.updateTextNote(
        id: noteId,
        title: '',
        body: 'Buy something else',
        mood: ColorMood.urgent,
        pinned: false,
      );
      loaded = await repository.loadNoteForEditing(noteId);
      expect(loaded?.mood, ColorMood.urgent);
      expect(loaded?.moodIsAutomatic, isFalse);
      stored = await database.select(database.notes).getSingle();
      expect(stored.moodModelVersion, 0);
      expect(stored.moodConfidence, 1);
    },
  );

  test('moves notes to trash so they leave the home preview list', () async {
    await repository.createTextNote(
      title: 'Delete me',
      body: 'This should not stay visible',
    );

    final created = await repository.watchNotePreviews().first;
    expect(created, hasLength(1));

    await repository.moveNoteToTrash(created.single.id);

    final visible = await repository.watchNotePreviews().first;
    final stored = await database.select(database.notes).getSingle();

    expect(visible, isEmpty);
    expect(stored.trashedAt, isNotNull);
  });

  test(
    'creates notes with reminders and shows recurrence in previews',
    () async {
      await repository.createTextNote(
        title: 'Water plants',
        body: 'Use the small can',
        reminder: NoteReminder(
          nextFireAt: DateTime(2026, 7, 10, 9),
          recurrence: ReminderRecurrence.weekly,
        ),
      );

      final notes = await repository.watchNotePreviews().first;
      final reminders = await database.select(database.reminders).get();

      expect(notes, hasLength(1));
      expect(notes.single.recurring, isTrue);
      expect(notes.single.reminderLabel, contains('Weekly'));
      expect(reminders, hasLength(1));
      expect(reminders.single.recurrenceKind, ReminderRecurrence.weekly.name);
    },
  );

  test(
    'persists custom recurrence intervals in existing reminder metadata',
    () async {
      final noteId = await repository.createTextNote(
        title: 'Replace filter',
        body: 'Order the replacement cartridge',
        reminder: NoteReminder(
          nextFireAt: DateTime(2026, 8, 31, 22),
          recurrence: ReminderRecurrence.monthly,
          recurrenceInterval: 2,
        ),
      );

      final loaded = await repository.loadNoteForEditing(noteId);
      final stored = await database.select(database.reminders).getSingle();
      final preview = await repository.watchNotePreviews().first;

      expect(loaded?.reminder?.recurrence, ReminderRecurrence.monthly);
      expect(loaded?.reminder?.recurrenceInterval, 2);
      expect(stored.recurrenceJson, '{"version":1,"interval":2}');
      expect(preview.single.reminderLabel, contains('Every 2 months'));
    },
  );

  test('persists an active/rest cycle and its optional end date', () async {
    final endAt = DateTime(2026, 12, 31, 22);
    final noteId = await repository.createTextNote(
      title: 'Treatment',
      body: 'Take the daily dose',
      reminder: NoteReminder(
        nextFireAt: DateTime(2026, 9, 7, 22),
        recurrence: ReminderRecurrence.daily,
        cycle: ReminderCycle(
          activeDuration: const ReminderDuration(
            value: 1,
            unit: ReminderDurationUnit.weeks,
          ),
          restDuration: const ReminderDuration(
            value: 2,
            unit: ReminderDurationUnit.weeks,
          ),
          endAt: endAt,
        ),
      ),
    );

    final loaded = await repository.loadNoteForEditing(noteId);
    final stored = await database.select(database.reminders).getSingle();

    expect(loaded?.reminder?.recurrence, ReminderRecurrence.daily);
    expect(
      loaded?.reminder?.cycle?.activeDuration,
      const ReminderDuration(value: 1, unit: ReminderDurationUnit.weeks),
    );
    expect(
      loaded?.reminder?.cycle?.restDuration,
      const ReminderDuration(value: 2, unit: ReminderDurationUnit.weeks),
    );
    expect(loaded?.reminder?.cycle?.endAt, endAt);
    expect(stored.endsAt, isNotNull);
    expect(stored.endsAt!.isAtSameMomentAs(endAt), isTrue);
    expect(stored.recurrenceKind, ReminderRecurrence.none.name);
    expect(
      stored.recurrenceJson,
      '{"version":2,"frequency":"daily","interval":1,"cycle":{"active":{"value":1,"unit":"weeks"},"rest":{"value":2,"unit":"weeks"}}}',
    );
  });

  test('persists a cycle-count limit without an end date', () async {
    final noteId = await repository.createTextNote(
      title: 'Three rounds',
      body: 'Repeat this cycle three times',
      reminder: NoteReminder(
        nextFireAt: DateTime(2026, 9, 7, 9),
        recurrence: ReminderRecurrence.daily,
        cycle: const ReminderCycle(
          activeDuration: ReminderDuration(
            value: 5,
            unit: ReminderDurationUnit.days,
          ),
          restDuration: ReminderDuration(
            value: 2,
            unit: ReminderDurationUnit.days,
          ),
          maxCycles: 3,
        ),
      ),
    );

    final loaded = await repository.loadNoteForEditing(noteId);
    final stored = await database.select(database.reminders).getSingle();

    expect(loaded?.reminder?.cycle?.maxCycles, 3);
    expect(loaded?.reminder?.cycle?.endAt, isNull);
    expect(stored.endsAt, isNull);
    expect(stored.recurrenceJson, contains('"maxCycles":3'));
  });

  test('persists a cycle anchor separately from the first alert', () async {
    final anchorAt = DateTime.utc(2026, 8, 31, 22);
    final firstAlertAt = DateTime.utc(2026, 9, 4, 22);
    final noteId = await repository.createTextNote(
      title: 'Anchored treatment week',
      body: 'Start the reminders part way through this cycle',
      reminder: NoteReminder(
        nextFireAt: firstAlertAt,
        recurrence: ReminderRecurrence.daily,
        cycle: ReminderCycle(
          anchorAt: anchorAt,
          activeDuration: const ReminderDuration(
            value: 1,
            unit: ReminderDurationUnit.weeks,
          ),
          restDuration: const ReminderDuration(
            value: 4,
            unit: ReminderDurationUnit.weeks,
          ),
        ),
      ),
    );

    final loaded = await repository.loadNoteForEditing(noteId);
    final stored = await database.select(database.reminders).getSingle();

    expect(
      loaded?.reminder?.cycle?.anchorAt?.isAtSameMomentAs(anchorAt),
      isTrue,
    );
    expect(stored.recurrenceJson, contains('"version":3'));
    expect(
      stored.recurrenceJson,
      contains('"anchorAt":"2026-08-31T22:00:00.000Z"'),
    );
  });

  test('labels a completed finite cycle as ended', () async {
    await repository.createTextNote(
      title: 'Finished course',
      body: 'No more reminders expected',
      reminder: NoteReminder(
        nextFireAt: DateTime(2020, 1, 1, 9),
        recurrence: ReminderRecurrence.daily,
        cycle: const ReminderCycle(
          activeDuration: ReminderDuration(
            value: 1,
            unit: ReminderDurationUnit.days,
          ),
          restDuration: ReminderDuration(
            value: 1,
            unit: ReminderDurationUnit.days,
          ),
          maxCycles: 1,
        ),
      ),
    );

    final preview = (await repository.watchNotePreviews().first).single;

    expect(preview.recurring, isTrue);
    expect(preview.reminderAt, isNull);
    expect(preview.reminderLabel, endsWith('Ended'));
  });

  test('falls back safely when cycle metadata is malformed', () async {
    final noteId = await repository.createTextNote(
      title: 'Legacy reminder',
      body: '',
      reminder: NoteReminder(
        nextFireAt: DateTime(2026, 9, 7, 9),
        recurrence: ReminderRecurrence.daily,
      ),
    );
    await (database.update(
      database.reminders,
    )..where((reminder) => reminder.noteId.equals(noteId))).write(
      const RemindersCompanion(
        recurrenceJson: Value(
          '{"version":2,"frequency":"daily","interval":2,"cycle":{"active":{"value":0,"unit":"weeks"},"rest":{"value":1,"unit":"weeks"}}}',
        ),
      ),
    );

    final loaded = await repository.loadNoteForEditing(noteId);

    expect(loaded?.reminder?.recurrence, ReminderRecurrence.none);
    expect(loaded?.reminder?.recurrenceInterval, 1);
    expect(loaded?.reminder?.cycle, isNull);
  });

  test('loads and updates editable note content and reminder', () async {
    final noteId = await repository.createTextNote(
      title: 'Draft',
      body: 'Old body',
      reminder: NoteReminder(
        nextFireAt: DateTime(2026, 7, 10, 9),
        recurrence: ReminderRecurrence.none,
      ),
    );

    final loaded = await repository.loadNoteForEditing(noteId);
    expect(loaded?.title, 'Draft');
    expect(loaded?.reminder?.recurrence, ReminderRecurrence.none);

    await repository.updateTextNote(
      id: noteId,
      title: 'Updated',
      body: 'New body',
      mood: ColorMood.focus,
      pinned: true,
      reminder: NoteReminder(
        nextFireAt: DateTime(2026, 7, 11, 10, 30),
        recurrence: ReminderRecurrence.daily,
      ),
    );

    final updated = await repository.loadNoteForEditing(noteId);
    final reminders = await database.select(database.reminders).get();

    expect(updated?.title, 'Updated');
    expect(updated?.body, 'New body');
    expect(updated?.reminder?.recurrence, ReminderRecurrence.daily);
    expect(reminders, hasLength(1));
  });

  test('snoozes an occurrence without moving its recurring schedule', () async {
    final originalFireAt = DateTime(2026, 7, 11, 10, 30);
    final noteId = await repository.createTextNote(
      title: 'Weekly review',
      body: 'Check the open tasks',
      reminder: NoteReminder(
        nextFireAt: originalFireAt,
        recurrence: ReminderRecurrence.weekly,
      ),
    );
    final snoozeUntil = DateTime(2026, 7, 11, 11, 30);

    final schedule = await repository.snoozeNoteReminder(noteId, snoozeUntil);

    expect(schedule?.reminder.nextFireAt, originalFireAt);
    expect(schedule?.reminder.recurrence, ReminderRecurrence.weekly);
    expect(schedule?.reminder.snoozeUntil, snoozeUntil);

    await repository.completeReminderOccurrence(noteId);
    final completed = await repository.loadNoteForEditing(noteId);
    expect(completed?.reminder?.recurrence, ReminderRecurrence.weekly);
    expect(completed?.reminder?.snoozeUntil, isNull);
  });

  test('completing a one-time reminder removes it from the note', () async {
    final noteId = await repository.createTextNote(
      title: 'Call back',
      body: '',
      reminder: NoteReminder(
        nextFireAt: DateTime(2026, 7, 11, 10, 30),
        recurrence: ReminderRecurrence.none,
      ),
    );

    await repository.completeReminderOccurrence(noteId);

    expect((await repository.loadNoteForEditing(noteId))?.reminder, isNull);
  });

  test('persists checklist items and toggles completion', () async {
    final noteId = await repository.createTextNote(
      title: 'Saturday jobs',
      body: '',
      mood: ColorMood.routine,
      pinned: true,
      checklistItems: const [
        ChecklistItemDraft(text: 'Wash the car'),
        ChecklistItemDraft(text: 'Water plants', done: true),
      ],
    );

    final beforeToggle = await repository.watchNotePreviews().first;
    expect(beforeToggle.single.pinned, isTrue);
    expect(beforeToggle.single.mood, ColorMood.routine);
    expect(beforeToggle.single.checklistItems, hasLength(2));
    expect(beforeToggle.single.completedChecklistItems, 1);

    await repository.toggleChecklistItem(noteId, 0);

    final afterToggle = await repository.watchNotePreviews().first;
    expect(afterToggle.single.completedChecklistItems, 2);
  });

  test('archives notes and restores them from trash', () async {
    final noteId = await repository.createTextNote(
      title: 'Keep me',
      body: 'Useful later',
    );

    await repository.setArchived(noteId, true);
    expect(
      (await repository.watchNotePreviews().first).single.archived,
      isTrue,
    );

    await repository.moveNoteToTrash(noteId);
    expect(await repository.watchNotePreviews().first, isEmpty);
    expect(await repository.watchTrashedNotePreviews().first, hasLength(1));

    await repository.restoreNote(noteId);
    final restored = await repository.watchNotePreviews().first;
    expect(restored, hasLength(1));
    expect(restored.single.archived, isTrue);
  });
}

class _NeutralEmotionClassifier implements ContextualEmotionClassifier {
  @override
  Future<List<List<double>>> classify(List<String> texts) async {
    return [
      for (final _ in texts)
        [for (var index = 0; index < 28; index++) index == 27 ? 6.0 : -6.0],
    ];
  }
}
