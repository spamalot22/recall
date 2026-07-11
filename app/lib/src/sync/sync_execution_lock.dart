import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class SyncExecutionLock {
  Future<T> synchronized<T>(Future<T> Function() operation);
}

class FileSyncExecutionLock implements SyncExecutionLock {
  const FileSyncExecutionLock();

  @override
  Future<T> synchronized<T>(Future<T> Function() operation) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'recall-sync.lock'));
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
      return await operation();
    } finally {
      try {
        await handle.unlock();
      } on FileSystemException {
        // Process teardown can release the OS lock before this finally runs.
      }
      await handle.close();
    }
  }
}
