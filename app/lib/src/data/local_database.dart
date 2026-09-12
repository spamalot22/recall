import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'local_database.g.dart';

final _databaseKeyPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get noteType => text().withDefault(const Constant('text'))();
  TextColumn get mood => text().withDefault(const Constant('clear'))();
  BoolColumn get moodIsAutomatic =>
      boolean().withDefault(const Constant(true))();
  RealColumn get moodConfidence => real().withDefault(const Constant(0))();
  IntColumn get moodModelVersion => integer().withDefault(const Constant(0))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get trashedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ChecklistItems extends Table {
  TextColumn get id => text()();
  TextColumn get noteId =>
      text().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get content => text().named('text')();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get noteId =>
      text().references(Notes, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get nextFireAt => dateTime()();
  TextColumn get timezone => text()();
  TextColumn get recurrenceKind => text().withDefault(const Constant('none'))();
  TextColumn get recurrenceJson => text().nullable()();
  DateTimeColumn get snoozeUntil => dateTime().nullable()();
  DateTimeColumn get endsAt => dateTime().nullable()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ReminderOccurrences extends Table {
  TextColumn get id => text()();
  TextColumn get reminderId =>
      text().references(Reminders, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get scheduledFor => dateTime()();
  TextColumn get status => text()();
  DateTimeColumn get actedAt => dateTime().nullable()();
  DateTimeColumn get snoozedUntil => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncRecords extends Table {
  TextColumn get id => text()();
  TextColumn get recordType => text()();
  TextColumn get encryptedPayload => text()();
  IntColumn get payloadVersion => integer().withDefault(const Constant(1))();
  IntColumn get clientRevision => integer()();
  IntColumn get serverRevision => integer().nullable()();
  BoolColumn get hasLocalChanges =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get hasConflict => boolean().withDefault(const Constant(false))();
  TextColumn get conflictOfRecordId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Notes, ChecklistItems, Reminders, ReminderOccurrences, SyncRecords],
)
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase({required Future<String> Function() databaseKey})
    : super(_openConnection(databaseKey));

  LocalDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  Future<void> _createSyncState() async {
    await customStatement('''
    CREATE TABLE IF NOT EXISTS sync_state (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      pull_revision INTEGER NOT NULL DEFAULT 0
    )
    ''');
    await customStatement(
      'CREATE TABLE IF NOT EXISTS sync_deletions (note_id TEXT PRIMARY KEY)',
    );
  }

  Future<void> recordPendingDeletion(String noteId) => customStatement(
    'INSERT OR IGNORE INTO sync_deletions (note_id) VALUES (?)',
    [noteId],
  );

  Future<List<String>> pendingDeletionIds() async => [
    for (final row in await customSelect(
      'SELECT note_id FROM sync_deletions',
    ).get())
      row.read<String>('note_id'),
  ];

  Future<void> clearPendingDeletion(String noteId) =>
      customStatement('DELETE FROM sync_deletions WHERE note_id = ?', [noteId]);

  Future<int> readPullRevision() async {
    final row = await customSelect(
      'SELECT pull_revision FROM sync_state WHERE id = 1',
    ).getSingleOrNull();
    return row?.read<int>('pull_revision') ?? 0;
  }

  Future<void> writePullRevision(int revision) => customStatement(
    'INSERT INTO sync_state (id, pull_revision) VALUES (1, ?) '
    'ON CONFLICT(id) DO UPDATE SET pull_revision = excluded.pull_revision',
    [revision],
  );

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createSyncState();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(notes, notes.moodIsAutomatic);
      }
      if (from < 3) {
        await migrator.addColumn(notes, notes.moodConfidence);
        await migrator.addColumn(notes, notes.moodModelVersion);
      }
      if (from < 4) {
        await migrator.addColumn(notes, notes.sortOrder);
      }
      if (from < 5) {
        // Start at zero: old push acknowledgements were incorrectly used as
        // pull progress, so an interrupted sync may have skipped records.
        await _createSyncState();
        await customStatement(
          'DELETE FROM checklist_items WHERE note_id NOT IN (SELECT id FROM notes)',
        );
        await customStatement(
          'DELETE FROM reminders WHERE note_id NOT IN (SELECT id FROM notes)',
        );
        await customStatement(
          'DELETE FROM reminder_occurrences WHERE reminder_id NOT IN (SELECT id FROM reminders)',
        );
      }
    },
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );
}

LazyDatabase _openConnection(Future<String> Function() databaseKey) {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'recall.sqlite'));
    final key = await databaseKey();
    if (!_databaseKeyPattern.hasMatch(key)) {
      throw StateError('The encrypted database key is invalid.');
    }
    return NativeDatabase.createInBackground(
      file,
      setup: (database) {
        if (database.select('PRAGMA cipher').isEmpty) {
          throw StateError('Encrypted SQLite is not available.');
        }

        var isPlaintext = false;
        try {
          database.select('SELECT count(*) FROM sqlite_master');
          isPlaintext = true;
        } on Object {
          // An encrypted database cannot be read before its key is supplied.
        }

        if (isPlaintext) {
          // This also migrates databases created by earlier Recall builds.
          database.execute("PRAGMA rekey = '$key'");
        } else {
          database.execute("PRAGMA key = '$key'");
        }
        database.select('SELECT count(*) FROM sqlite_master');
      },
    );
  });
}
