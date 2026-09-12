import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

abstract class SyncExecutionLock {
  Future<T> synchronized<T>(Future<T> Function() operation);
}

class FileSyncExecutionLock implements SyncExecutionLock {
  const FileSyncExecutionLock({this.name = 'recall-sync', this.databasePath});

  final String name;
  final String? databasePath;

  @override
  Future<T> synchronized<T>(Future<T> Function() operation) async {
    final path =
        databasePath ??
        p.join(
          (await getApplicationDocumentsDirectory()).path,
          '$name-lock.sqlite',
        );
    final database = sqlite3.open(path);
    var acquired = false;
    try {
      // SQLite coordinates connections across isolates as well as processes.
      // Ordinary POSIX file locks are process-wide and do not exclude isolates.
      database.execute('PRAGMA busy_timeout = 0');
      final elapsed = Stopwatch()..start();
      while (!acquired) {
        try {
          database.execute('BEGIN EXCLUSIVE');
          acquired = true;
        } on SqliteException catch (error) {
          if ((error.resultCode != 5 && error.resultCode != 6) ||
              elapsed.elapsed >= const Duration(minutes: 2)) {
            rethrow;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
      return await operation();
    } finally {
      try {
        if (acquired) database.execute('ROLLBACK');
      } finally {
        database.close();
      }
    }
  }
}
