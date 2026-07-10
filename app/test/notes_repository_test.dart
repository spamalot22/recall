import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/data/local_database.dart';
import 'package:recall_app/src/notes/note_models.dart';
import 'package:recall_app/src/notes/notes_repository.dart';

void main() {
  late LocalDatabase database;
  late NotesRepository repository;

  setUp(() {
    database = LocalDatabase.forTesting(NativeDatabase.memory());
    repository = NotesRepository(database);
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
