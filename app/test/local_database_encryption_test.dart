import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('the bundled SQLite library encrypts database files', () {
    final directory = Directory.systemTemp.createTempSync('recall-db-test-');
    final path = '${directory.path}/encrypted.sqlite';
    const key = 'test-key-that-never-leaves-this-test';

    try {
      final plaintext = sqlite3.open(path);
      expect(plaintext.select('PRAGMA cipher'), isNotEmpty);
      plaintext.execute('CREATE TABLE secret (value TEXT NOT NULL)');
      plaintext.execute("INSERT INTO secret VALUES ('private note')");
      plaintext.close();

      final migrating = sqlite3.open(path);
      expect(migrating.select('SELECT value FROM secret'), isNotEmpty);
      migrating.execute("PRAGMA rekey = '$key'");
      migrating.close();

      final locked = sqlite3.open(path);
      expect(
        () => locked.select('SELECT value FROM secret'),
        throwsA(isA<SqliteException>()),
      );
      locked.execute("PRAGMA key = '$key'");
      expect(
        locked.select('SELECT value FROM secret').single['value'],
        'private note',
      );
      locked.close();
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
}
