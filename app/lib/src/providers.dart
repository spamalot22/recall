import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account/auth_service.dart';
import 'account/secure_account_store.dart';
import 'data/local_database.dart';
import 'notes/note_models.dart';
import 'notes/notes_repository.dart';
import 'reminders/reminder_scheduler.dart';
import 'sync/sync_service.dart';
import 'updates/apk_installer.dart';
import 'updates/update_service.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final accountStore = ref.watch(secureAccountStoreProvider);
  final database = LocalDatabase(
    databaseKey: accountStore.readOrCreateDatabaseKey,
  );
  ref.onDispose(database.close);
  return database;
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(ref.watch(localDatabaseProvider));
});

final notePreviewsProvider = StreamProvider<List<NotePreview>>((ref) {
  return ref.watch(notesRepositoryProvider).watchNotePreviews();
});

final trashedNotePreviewsProvider = StreamProvider<List<NotePreview>>((ref) {
  return ref.watch(notesRepositoryProvider).watchTrashedNotePreviews();
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final backgroundStartupEnabledProvider = Provider<bool>((ref) => true);

final secureAccountStoreProvider = Provider<SecureAccountStore>((ref) {
  return SecureAccountStore();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(secureAccountStoreProvider));
});

final storedSessionProvider = FutureProvider<StoredSession?>((ref) {
  return ref.watch(secureAccountStoreProvider).readSession();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref.watch(localDatabaseProvider),
    ref.watch(secureAccountStoreProvider),
  );
});

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

final apkInstallerProvider = Provider<ApkInstaller>((ref) {
  return const ApkInstaller();
});

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return ReminderScheduler();
});
