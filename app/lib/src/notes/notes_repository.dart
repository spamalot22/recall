import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/local_database.dart';
import 'mood_analyzer.dart';
import 'note_models.dart';

class NotesRepository {
  NotesRepository(this._db, {Uuid? uuid, MoodAnalyzer? moodAnalyzer})
    : _uuid = uuid ?? const Uuid(),
      _moodAnalyzer = moodAnalyzer ?? RecallMoodAnalyzer();

  final LocalDatabase _db;
  final Uuid _uuid;
  final MoodAnalyzer _moodAnalyzer;

  Stream<List<NotePreview>> watchNotePreviews() {
    final query = _db.select(_db.notes)
      ..where((note) => note.trashedAt.isNull())
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
            title: note.title,
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
            archived: note.isArchived,
            recurring: reminder?.repeats ?? false,
            reminderAt: reminder?.nextFireAt,
          ),
        );
      }

      return previews;
    });
  }

  Future<String> createTextNote({
    required String title,
    required String body,
    ColorMood? mood,
    bool pinned = false,
    List<ChecklistItemDraft> checklistItems = const [],
    NoteReminder? reminder,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v7();
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    final analysis = mood == null
        ? await _moodAnalyzer.analyze(
            title: trimmedTitle,
            body: trimmedBody,
            checklistItems: checklistItems.map((item) => item.text),
            reminder: reminder,
          )
        : null;

    await _db.transaction(() async {
      await _db
          .into(_db.notes)
          .insert(
            NotesCompanion.insert(
              id: id,
              title: Value(trimmedTitle),
              body: Value(trimmedBody),
              noteType: const Value('text'),
              mood: Value((mood ?? analysis!.mood).name),
              moodIsAutomatic: Value(mood == null),
              moodConfidence: Value(analysis?.confidence ?? 1),
              moodModelVersion: Value(analysis?.modelVersion ?? 0),
              isPinned: Value(pinned),
              createdAt: now,
              updatedAt: now,
            ),
          );

      if (reminder != null) {
        await _upsertReminder(noteId: id, reminder: reminder, now: now);
      }

      await _replaceChecklistItems(noteId: id, items: checklistItems, now: now);
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
      moodIsAutomatic: note.moodIsAutomatic,
      pinned: note.isPinned,
      checklistItems: (await _checklistItemsFor(note.id))
          .map(
            (item) => ChecklistItemDraft(text: item.content, done: item.isDone),
          )
          .toList(),
      reminder: await _firstEnabledReminder(note.id),
    );
  }

  Future<void> updateTextNote({
    required String id,
    required String title,
    required String body,
    ColorMood? mood,
    required bool pinned,
    List<ChecklistItemDraft> checklistItems = const [],
    NoteReminder? reminder,
  }) async {
    final now = DateTime.now().toUtc();
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    final analysis = mood == null
        ? await _moodAnalyzer.analyze(
            title: trimmedTitle,
            body: trimmedBody,
            checklistItems: checklistItems.map((item) => item.text),
            reminder: reminder,
          )
        : null;

    await _db.transaction(() async {
      await (_db.update(_db.notes)..where((note) => note.id.equals(id))).write(
        NotesCompanion(
          title: Value(trimmedTitle),
          body: Value(trimmedBody),
          mood: Value((mood ?? analysis!.mood).name),
          moodIsAutomatic: Value(mood == null),
          moodConfidence: Value(analysis?.confidence ?? 1),
          moodModelVersion: Value(analysis?.modelVersion ?? 0),
          isPinned: Value(pinned),
          updatedAt: Value(now),
        ),
      );

      await (_db.delete(
        _db.reminders,
      )..where((reminder) => reminder.noteId.equals(id))).go();

      if (reminder != null) {
        await _upsertReminder(noteId: id, reminder: reminder, now: now);
      }

      await _replaceChecklistItems(noteId: id, items: checklistItems, now: now);
    });
  }

  Future<void> moveNoteToTrash(String noteId) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.notes)..where((note) => note.id.equals(noteId)))
        .write(NotesCompanion(trashedAt: Value(now), updatedAt: Value(now)));
  }

  Future<void> setPinned(String noteId, bool pinned) async {
    await _updateNote(noteId, NotesCompanion(isPinned: Value(pinned)));
  }

  Future<void> setArchived(String noteId, bool archived) async {
    await _updateNote(noteId, NotesCompanion(isArchived: Value(archived)));
  }

  Future<void> restoreNote(String noteId) async {
    final now = DateTime.now().toUtc();
    await (_db.update(
      _db.notes,
    )..where((note) => note.id.equals(noteId))).write(
      NotesCompanion(trashedAt: const Value(null), updatedAt: Value(now)),
    );
  }

  Future<void> permanentlyDeleteNote(String noteId) {
    return (_db.delete(
      _db.notes,
    )..where((note) => note.id.equals(noteId))).go();
  }

  Future<void> toggleChecklistItem(String noteId, int index) async {
    final items = await _checklistItemsFor(noteId);
    if (index < 0 || index >= items.length) {
      return;
    }

    final item = items[index];
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await (_db.update(
        _db.checklistItems,
      )..where((entry) => entry.id.equals(item.id))).write(
        ChecklistItemsCompanion(
          isDone: Value(!item.isDone),
          updatedAt: Value(now),
        ),
      );
      await (_db.update(_db.notes)..where((note) => note.id.equals(noteId)))
          .write(NotesCompanion(updatedAt: Value(now)));
    });
  }

  Future<List<ScheduledNoteReminder>> loadScheduledReminders() async {
    final notes = await (_db.select(
      _db.notes,
    )..where((note) => note.trashedAt.isNull())).get();
    final schedules = <ScheduledNoteReminder>[];
    for (final note in notes) {
      final reminder = await _firstEnabledReminder(note.id);
      if (reminder != null) {
        final checklistItems = await _checklistItemsFor(note.id);
        schedules.add(
          ScheduledNoteReminder(
            noteId: note.id,
            title: note.title,
            body: _reminderBody(note.body, checklistItems),
            reminder: reminder,
          ),
        );
      }
    }
    return schedules;
  }

  Future<ScheduledNoteReminder?> snoozeNoteReminder(
    String noteId,
    DateTime until,
  ) async {
    final now = DateTime.now().toUtc();
    final updated =
        await (_db.update(_db.reminders)..where(
              (reminder) =>
                  reminder.noteId.equals(noteId) &
                  reminder.isEnabled.equals(true),
            ))
            .write(
              RemindersCompanion(
                snoozeUntil: Value(until.toUtc()),
                updatedAt: Value(now),
              ),
            );
    if (updated == 0) {
      return null;
    }

    await (_db.update(_db.notes)..where((note) => note.id.equals(noteId)))
        .write(NotesCompanion(updatedAt: Value(now)));
    return _scheduledReminderForNote(noteId);
  }

  Future<void> completeReminderOccurrence(String noteId) async {
    final reminder = await _firstEnabledReminder(noteId);
    if (reminder == null) {
      return;
    }

    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      if (reminder.repeats) {
        await (_db.update(_db.reminders)..where(
              (entry) =>
                  entry.noteId.equals(noteId) & entry.isEnabled.equals(true),
            ))
            .write(
              RemindersCompanion(
                snoozeUntil: const Value(null),
                updatedAt: Value(now),
              ),
            );
      } else {
        await (_db.delete(
          _db.reminders,
        )..where((entry) => entry.noteId.equals(noteId))).go();
      }
      await (_db.update(_db.notes)..where((note) => note.id.equals(noteId)))
          .write(NotesCompanion(updatedAt: Value(now)));
    });
  }

  Stream<List<NotePreview>> watchTrashedNotePreviews() {
    final query = _db.select(_db.notes)
      ..where((note) => note.trashedAt.isNotNull())
      ..orderBy([
        (note) =>
            OrderingTerm(expression: note.trashedAt, mode: OrderingMode.desc),
      ]);

    return query.watch().asyncMap(_buildPreviews);
  }

  Future<void> _updateNote(String noteId, NotesCompanion values) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.notes)..where((note) => note.id.equals(noteId)))
        .write(values.copyWith(updatedAt: Value(now)));
  }

  Future<List<NotePreview>> _buildPreviews(List<Note> notes) async {
    final previews = <NotePreview>[];

    for (final note in notes) {
      final checklistItems = await _checklistItemsFor(note.id);
      final reminder = await _firstEnabledReminder(note.id);
      previews.add(
        NotePreview(
          id: note.id,
          title: note.title,
          body: note.body,
          mood: ColorMood.fromName(note.mood),
          reminderLabel: _formatReminderLabel(reminder),
          checklistItems: checklistItems
              .map(
                (item) => ChecklistItemPreview(item.content, done: item.isDone),
              )
              .toList(),
          pinned: note.isPinned,
          archived: note.isArchived,
          recurring: reminder?.repeats ?? false,
          reminderAt: reminder?.nextFireAt,
        ),
      );
    }

    return previews;
  }

  Future<List<ChecklistItem>> _checklistItemsFor(String noteId) {
    return (_db.select(_db.checklistItems)
          ..where((item) => item.noteId.equals(noteId))
          ..orderBy([(item) => OrderingTerm(expression: item.sortOrder)]))
        .get();
  }

  Future<void> _replaceChecklistItems({
    required String noteId,
    required List<ChecklistItemDraft> items,
    required DateTime now,
  }) async {
    await (_db.delete(
      _db.checklistItems,
    )..where((item) => item.noteId.equals(noteId))).go();

    final populatedItems = items
        .map(
          (item) => ChecklistItemDraft(text: item.text.trim(), done: item.done),
        )
        .where((item) => item.text.isNotEmpty)
        .toList();
    for (var index = 0; index < populatedItems.length; index++) {
      final item = populatedItems[index];
      await _db
          .into(_db.checklistItems)
          .insert(
            ChecklistItemsCompanion.insert(
              id: _uuid.v7(),
              noteId: noteId,
              content: item.text,
              isDone: Value(item.done),
              sortOrder: index,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
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
      snoozeUntil: reminder.snoozeUntil?.toLocal(),
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
            snoozeUntil: Value(reminder.snoozeUntil?.toUtc()),
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

  Future<ScheduledNoteReminder?> _scheduledReminderForNote(
    String noteId,
  ) async {
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

    final reminder = await _firstEnabledReminder(noteId);
    if (reminder == null) {
      return null;
    }
    final note = notes.single;
    return ScheduledNoteReminder(
      noteId: note.id,
      title: note.title,
      body: _reminderBody(note.body, await _checklistItemsFor(note.id)),
      reminder: reminder,
    );
  }

  String _reminderBody(String body, List<ChecklistItem> checklistItems) {
    final trimmedBody = body.trim();
    if (trimmedBody.isNotEmpty) {
      return trimmedBody;
    }
    for (final item in checklistItems) {
      if (!item.isDone && item.content.trim().isNotEmpty) {
        return item.content.trim();
      }
    }
    return checklistItems.firstOrNull?.content.trim() ?? '';
  }
}
