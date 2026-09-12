import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/data/local_database.dart';

void main() {
  test('schema 5 migration preserves schema 2 notes', () async {
    final directory = Directory.systemTemp.createTempSync(
      'recall-migration-test-',
    );
    final file = File('${directory.path}/recall.sqlite');

    try {
      final schemaTwo = LocalDatabase.forTesting(NativeDatabase(file));
      final createdAt = DateTime.utc(2026, 7, 12, 10);
      await schemaTwo
          .into(schemaTwo.notes)
          .insert(
            NotesCompanion.insert(
              id: '0198a3b4-8e80-7000-8000-000000000001',
              title: const Value('Existing note'),
              body: const Value('Preserved during migration'),
              mood: const Value('focus'),
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          );
      await schemaTwo.customStatement(
        'ALTER TABLE notes DROP COLUMN mood_confidence',
      );
      await schemaTwo.customStatement(
        'ALTER TABLE notes DROP COLUMN mood_model_version',
      );
      await schemaTwo.customStatement(
        'ALTER TABLE notes DROP COLUMN sort_order',
      );
      await schemaTwo.customStatement('DROP TABLE sync_state');
      await schemaTwo.customStatement('DROP TABLE sync_deletions');
      await schemaTwo.customStatement('PRAGMA user_version = 2');
      await schemaTwo.close();

      final upgraded = LocalDatabase.forTesting(NativeDatabase(file));
      try {
        final note = await upgraded.select(upgraded.notes).getSingle();
        expect(note.title, 'Existing note');
        expect(note.body, 'Preserved during migration');
        expect(note.mood, 'focus');
        expect(note.moodConfidence, 0);
        expect(note.moodModelVersion, 0);
        expect(note.sortOrder, 0);
        final version = await upgraded
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), 5);
        expect(await upgraded.readPullRevision(), 0);
      } finally {
        await upgraded.close();
      }
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('permanent deletion cascades to checklist and reminder data', () async {
    final db = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 9, 5);
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(id: 'note', createdAt: now, updatedAt: now),
        );
    await db
        .into(db.checklistItems)
        .insert(
          ChecklistItemsCompanion.insert(
            id: 'item',
            noteId: 'note',
            content: 'Private content',
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.reminders)
        .insert(
          RemindersCompanion.insert(
            id: 'reminder',
            noteId: 'note',
            nextFireAt: now,
            timezone: 'UTC',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.reminderOccurrences)
        .insert(
          ReminderOccurrencesCompanion.insert(
            id: 'occurrence',
            reminderId: 'reminder',
            scheduledFor: now,
            status: 'done',
            createdAt: now,
          ),
        );
    await db.delete(db.notes).go();
    expect(await db.select(db.checklistItems).get(), isEmpty);
    expect(await db.select(db.reminders).get(), isEmpty);
    expect(await db.select(db.reminderOccurrences).get(), isEmpty);
  });
}
