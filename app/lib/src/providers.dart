import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/local_database.dart';
import 'notes/note_models.dart';
import 'notes/notes_repository.dart';
import 'updates/apk_installer.dart';
import 'updates/update_service.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = LocalDatabase();
  ref.onDispose(database.close);
  return database;
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(ref.watch(localDatabaseProvider));
});

final notePreviewsProvider = StreamProvider<List<NotePreview>>((ref) {
  return ref.watch(notesRepositoryProvider).watchNotePreviews();
});

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

final apkInstallerProvider = Provider<ApkInstaller>((ref) {
  return const ApkInstaller();
});
