import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/data/local_database.dart';

void main() {
  test('schema 3 migration preserves schema 2 notes', () async {
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
        final version = await upgraded
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), 3);
      } finally {
        await upgraded.close();
      }
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
}
