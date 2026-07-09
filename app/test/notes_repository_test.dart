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
}
