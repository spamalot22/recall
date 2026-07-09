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

        previews.add(
          NotePreview(
            id: note.id,
            title: note.title.isEmpty ? 'Untitled' : note.title,
            body: note.body,
            mood: ColorMood.fromName(note.mood),
            reminderLabel: 'No reminder',
            checklistItems: checklistItems
                .map(
                  (item) =>
                      ChecklistItemPreview(item.content, done: item.isDone),
                )
                .toList(),
            pinned: note.isPinned,
          ),
        );
      }

      return previews;
    });
  }

  Future<void> createTextNote({
    required String title,
    required String body,
  }) async {
    final now = DateTime.now().toUtc();
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();

    await _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            id: _uuid.v7(),
            title: Value(trimmedTitle),
            body: Value(trimmedBody),
            noteType: const Value('text'),
            mood: Value(_defaultMoodFor(trimmedTitle, trimmedBody).name),
            createdAt: now,
            updatedAt: now,
          ),
        );
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
}
