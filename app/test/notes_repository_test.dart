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
}
