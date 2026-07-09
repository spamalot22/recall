import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/local_database.dart';
import 'note_models.dart';

class NotesRepository {
  NotesRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LocalDatabase _db;
  final Uuid _uuid;

  Stream<List<NotePreview>> watchNotePreviews() {
    final query = _db.select(_db.notes)
      ..where((note) => note.trashedAt.isNull() & note.isArchived.equals(false))
      ..orderBy([
        (note) =>
            OrderingTerm(expression: note.isPinned, mode: OrderingMode.desc),
        (note) =>
            OrderingTerm(expression: note.updatedAt, mode: OrderingMode.desc),
      ]);

    return query.watch().asyncMap((notes) async {
      final previews = <NotePreview>[];

      for (final note in notes) {
        final checklistItems =
            await (_db.select(_db.checklistItems)
                  ..where((item) => item.noteId.equals(note.id))
                  ..orderBy([
                    (item) => OrderingTerm(expression: item.sortOrder),
                  ]))
                .get();
        final reminder = await _firstEnabledReminder(note.id);

        previews.add(
          NotePreview(
            id: note.id,
            title: note.title.isEmpty ? 'Untitled' : note.title,
            body: note.body,
            mood: ColorMood.fromName(note.mood),
            reminderLabel: _formatReminderLabel(reminder),
            checklistItems: checklistItems
                .map(
                  (item) =>
                      ChecklistItemPreview(item.content, done: item.isDone),
                )
                .toList(),
            pinned: note.isPinned,
            recurring: reminder?.repeats ?? false,
          ),
        );
      }

      return previews;
    });
  }

  Future<String> createTextNote({
    required String title,
    required String body,
    NoteReminder? reminder,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v7();
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();

    await _db.transaction(() async {
      await _db
          .into(_db.notes)
          .insert(
            NotesCompanion.insert(
              id: id,
              title: Value(trimmedTitle),
              body: Value(trimmedBody),
              noteType: const Value('text'),
              mood: Value(_defaultMoodFor(trimmedTitle, trimmedBody).name),
              createdAt: now,
              updatedAt: now,
            ),
          );

      if (reminder != null) {
        await _upsertReminder(noteId: id, reminder: reminder, now: now);
      }
    });

    return id;
  }

  Future<NoteEditorSnapshot?> loadNoteForEditing(String noteId) async {
    final notes =
        await (_db.select(_db.notes)
              ..where(
                (note) => note.id.equals(noteId) & note.trashedAt.isNull(),
              )
              ..limit(1))
            .get();

    if (notes.isEmpty) {
      return null;
    }

    final note = notes.single;

    return NoteEditorSnapshot(
      id: note.id,
      title: note.title,
      body: note.body,
      mood: ColorMood.fromName(note.mood),
      reminder: await _firstEnabledReminder(note.id),
    );
  }

  Future<void> updateTextNote({
    required String id,
    required String title,
    required String body,
    NoteReminder? reminder,
  }) async {
    final now = DateTime.now().toUtc();
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();

    await _db.transaction(() async {
      await (_db.update(_db.notes)..where((note) => note.id.equals(id))).write(
        NotesCompanion(
          title: Value(trimmedTitle),
          body: Value(trimmedBody),
          mood: Value(_defaultMoodFor(trimmedTitle, trimmedBody).name),
          updatedAt: Value(now),
        ),
      );

      await (_db.delete(
        _db.reminders,
      )..where((reminder) => reminder.noteId.equals(id))).go();

      if (reminder != null) {
        await _upsertReminder(noteId: id, reminder: reminder, now: now);
      }
    });
  }

  Future<void> moveNoteToTrash(String noteId) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.notes)..where((note) => note.id.equals(noteId)))
        .write(NotesCompanion(trashedAt: Value(now), updatedAt: Value(now)));
  }

  ColorMood _defaultMoodFor(String title, String body) {
    final text = '$title $body'.toLowerCase();

    if (text.contains('today') ||
        text.contains('urgent') ||
        text.contains('asap')) {
      return ColorMood.urgent;
    }

    if (text.contains('buy') ||
        text.contains('pick up') ||
        text.contains('pack')) {
      return ColorMood.errand;
    }

    return ColorMood.clear;
  }

  Future<NoteReminder?> _firstEnabledReminder(String noteId) async {
    final reminders =
        await (_db.select(_db.reminders)
              ..where(
                (reminder) =>
                    reminder.noteId.equals(noteId) &
                    reminder.isEnabled.equals(true),
              )
              ..orderBy([
                (reminder) => OrderingTerm(expression: reminder.nextFireAt),
              ])
              ..limit(1))
            .get();

    if (reminders.isEmpty) {
      return null;
    }

    final reminder = reminders.single;
    return NoteReminder(
      nextFireAt: reminder.nextFireAt.toLocal(),
      recurrence: ReminderRecurrence.fromName(reminder.recurrenceKind),
    );
  }

  Future<void> _upsertReminder({
    required String noteId,
    required NoteReminder reminder,
    required DateTime now,
  }) async {
    await _db
        .into(_db.reminders)
        .insert(
          RemindersCompanion.insert(
            id: _uuid.v7(),
            noteId: noteId,
            nextFireAt: reminder.nextFireAt.toUtc(),
            timezone: DateTime.now().timeZoneName,
            recurrenceKind: Value(reminder.recurrence.name),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  String _formatReminderLabel(NoteReminder? reminder) {
    if (reminder == null) {
      return 'No reminder';
    }

    final date = _formatDateTime(reminder.nextFireAt);
    if (!reminder.repeats) {
      return date;
    }

    return '${reminder.recurrence.label} • $date';
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute';
  }
}
