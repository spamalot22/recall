import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../account/secure_account_store.dart';
import '../data/local_database.dart';
import '../security/record_cipher.dart';
import 'sync_execution_lock.dart';

class SyncException implements Exception {
  const SyncException(this.message, {this.retryable = false});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

class SyncResult {
  const SyncResult({
    required this.connected,
    this.pushed = 0,
    this.pulled = 0,
    this.conflicts = 0,
  });

  final bool connected;
  final int pushed;
  final int pulled;
  final int conflicts;
}

class SyncService {
  SyncService(
    this._database,
    this._accountStore, {
    RecordCipher? cipher,
    HttpClient? httpClient,
    SyncExecutionLock? executionLock,
  }) : _cipher = cipher ?? RecordCipher(),
       _executionLock = executionLock ?? const FileSyncExecutionLock(),
       _httpClient =
           httpClient ??
           (HttpClient()..connectionTimeout = const Duration(seconds: 15));

  static const _maxResponseBytes = 1024 * 1024;
  static const _maxEncryptedPayloadLength = 700000;
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final LocalDatabase _database;
  final SecureAccountStore _accountStore;
  final RecordCipher _cipher;
  final SyncExecutionLock _executionLock;
  final HttpClient _httpClient;
  final Uuid _uuid = const Uuid();
  Future<SyncResult>? _activeSync;

  Future<SyncResult> sync() async {
    final active = _activeSync;
    if (active != null) {
      return active;
    }

    final operation = _executionLock.synchronized(_performSync);
    _activeSync = operation;
    try {
      return await operation;
    } finally {
      if (identical(_activeSync, operation)) {
        _activeSync = null;
      }
    }
  }

  Future<int> pendingChangeCount() {
    return _executionLock.synchronized(() async {
      if (await _accountStore.readSession() == null) {
        return 0;
      }
      final records = await _database.select(_database.syncRecords).get();
      final recordsById = {for (final record in records) record.id: record};
      final pendingIds = {
        for (final record in records)
          if (record.hasLocalChanges) record.id,
      };
      final notes = await _database.select(_database.notes).get();
      for (final note in notes) {
        final record = recordsById[note.id];
        if (record == null || note.updatedAt.isAfter(record.updatedAt)) {
          pendingIds.add(note.id);
        }
      }
      return pendingIds.length;
    });
  }

  Future<SyncResult> _performSync() async {
    final storedSession = await _accountStore.readSession();
    if (storedSession == null) {
      return const SyncResult(connected: false);
    }
    StoredSession session = storedSession;

    await _queueChangedNotes(session);
    // Capture this before push acknowledgements advance individual revisions,
    // otherwise older records from another device could be skipped.
    var cursor = await _latestServerRevision();
    var pushed = 0;
    var conflicts = 0;
    while (true) {
      final pending =
          await (_database.select(_database.syncRecords)
                ..where((record) => record.hasLocalChanges.equals(true))
                ..orderBy([
                  (record) => OrderingTerm(expression: record.updatedAt),
                ])
                ..limit(250))
              .get();
      if (pending.isEmpty) {
        break;
      }
      final response = await _requestJson(
        session: session,
        method: 'POST',
        path: '/sync/push',
        body: {
          'records': pending
              .map(
                (record) => {
                  'id': record.id,
                  'type': record.recordType,
                  'encryptedPayload': record.encryptedPayload,
                  'payloadVersion': record.payloadVersion,
                  'clientRevision': record.clientRevision,
                  if (record.serverRevision != null)
                    'baseServerRevision': record.serverRevision,
                  if (record.deletedAt != null)
                    'deletedAt': record.deletedAt!.toUtc().toIso8601String(),
                },
              )
              .toList(),
        },
      );
      session = await _accountStore.readSession() ?? session;
      final accepted = response['accepted'];
      if (accepted is! List) {
        throw const SyncException(
          'Recall backup returned an invalid sync response.',
        );
      }
      var processed = 0;
      for (final rawAccepted in accepted) {
        if (rawAccepted is! Map) {
          continue;
        }
        final acceptedRecord = Map<String, Object?>.from(rawAccepted);
        final id = acceptedRecord['clientRecordId'];
        final serverRevision = acceptedRecord['serverRevision'];
        final conflict = acceptedRecord['conflict'];
        if (id is! String || serverRevision is! int || conflict is! bool) {
          continue;
        }
        processed++;
        await (_database.update(
          _database.syncRecords,
        )..where((record) => record.id.equals(id))).write(
          SyncRecordsCompanion(
            serverRevision: Value(serverRevision),
            hasLocalChanges: const Value(false),
            hasConflict: const Value(false),
            conflictOfRecordId: const Value(null),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
        if (conflict) {
          conflicts++;
        } else {
          pushed++;
        }
      }
      if (processed != pending.length) {
        throw const SyncException(
          'Recall backup did not acknowledge every encrypted change.',
        );
      }
    }

    var pulled = 0;
    while (true) {
      final response = await _requestJson(
        session: session,
        method: 'POST',
        path: '/sync/pull',
        body: {'afterServerRevision': cursor, 'limit': 250},
      );
      session = await _accountStore.readSession() ?? session;
      final records = response['records'];
      final responseCursor = response['cursor'];
      if (records is! List || responseCursor is! Map) {
        throw const SyncException(
          'Recall backup returned an invalid sync response.',
        );
      }
      for (final rawRecord in records) {
        if (rawRecord is! Map) {
          continue;
        }
        final applied = await _applyRemoteRecord(
          session,
          Map<String, Object?>.from(rawRecord),
        );
        if (applied) {
          pulled++;
        }
      }
      final nextCursor = responseCursor['lastServerRevision'];
      final hasMore = responseCursor['hasMore'];
      if (nextCursor is! int || hasMore is! bool) {
        throw const SyncException(
          'Recall backup returned an invalid sync cursor.',
        );
      }
      cursor = nextCursor;
      if (!hasMore) {
        break;
      }
    }

    return SyncResult(
      connected: true,
      pushed: pushed,
      pulled: pulled,
      conflicts: conflicts,
    );
  }

  Future<void> queueDeletion(String noteId) async {
    final session = await _accountStore.readSession();
    if (session == null) {
      return;
    }
    final existing =
        await (_database.select(_database.syncRecords)
              ..where((record) => record.id.equals(noteId))
              ..limit(1))
            .getSingleOrNull();
    final now = DateTime.now().toUtc();
    final encryptedPayload = await _cipher.encryptJson(
      value: {'schema': 1, 'id': noteId, 'deleted': true},
      masterKey: session.masterKey,
    );
    await _database
        .into(_database.syncRecords)
        .insertOnConflictUpdate(
          SyncRecordsCompanion.insert(
            id: noteId,
            recordType: 'tombstone',
            encryptedPayload: encryptedPayload,
            clientRevision: (existing?.clientRevision ?? 0) + 1,
            serverRevision: Value(existing?.serverRevision),
            hasLocalChanges: const Value(true),
            hasConflict: const Value(false),
            deletedAt: Value(now),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> _queueChangedNotes(StoredSession session) async {
    final notes = await (_database.select(
      _database.notes,
    )..orderBy([(note) => OrderingTerm(expression: note.updatedAt)])).get();
    for (final note in notes) {
      final existing =
          await (_database.select(_database.syncRecords)
                ..where((record) => record.id.equals(note.id))
                ..limit(1))
              .getSingleOrNull();
      if (existing != null && !note.updatedAt.isAfter(existing.updatedAt)) {
        continue;
      }

      final checklistItems =
          await (_database.select(_database.checklistItems)
                ..where((item) => item.noteId.equals(note.id))
                ..orderBy([(item) => OrderingTerm(expression: item.sortOrder)]))
              .get();
      final reminders =
          await (_database.select(_database.reminders)
                ..where((reminder) => reminder.noteId.equals(note.id))
                ..orderBy([
                  (reminder) => OrderingTerm(expression: reminder.createdAt),
                ])
                ..limit(1))
              .get();
      final now = DateTime.now().toUtc();
      final encryptedPayload = await _cipher.encryptJson(
        value: {
          'schema': 1,
          'note': {
            'id': note.id,
            'title': note.title,
            'body': note.body,
            'noteType': note.noteType,
            'mood': note.mood,
            'moodIsAutomatic': note.moodIsAutomatic,
            'isPinned': note.isPinned,
            'isArchived': note.isArchived,
            'trashedAt': note.trashedAt?.toUtc().toIso8601String(),
            'createdAt': note.createdAt.toUtc().toIso8601String(),
            'updatedAt': note.updatedAt.toUtc().toIso8601String(),
          },
          'checklistItems': checklistItems
              .map(
                (item) => {
                  'id': item.id,
                  'content': item.content,
                  'isDone': item.isDone,
                  'sortOrder': item.sortOrder,
                  'createdAt': item.createdAt.toUtc().toIso8601String(),
                  'updatedAt': item.updatedAt.toUtc().toIso8601String(),
                },
              )
              .toList(),
          if (reminders.isNotEmpty) 'reminder': _reminderJson(reminders.single),
        },
        masterKey: session.masterKey,
      );
      await _database
          .into(_database.syncRecords)
          .insertOnConflictUpdate(
            SyncRecordsCompanion.insert(
              id: note.id,
              recordType: 'note',
              encryptedPayload: encryptedPayload,
              clientRevision: (existing?.clientRevision ?? 0) + 1,
              serverRevision: Value(existing?.serverRevision),
              hasLocalChanges: const Value(true),
              hasConflict: const Value(false),
              createdAt: existing?.createdAt ?? now,
              updatedAt: now,
            ),
          );
    }
  }

  Map<String, Object?> _reminderJson(Reminder reminder) {
    return {
      'id': reminder.id,
      'nextFireAt': reminder.nextFireAt.toUtc().toIso8601String(),
      'timezone': reminder.timezone,
      'recurrenceKind': reminder.recurrenceKind,
      'recurrenceJson': reminder.recurrenceJson,
      'snoozeUntil': reminder.snoozeUntil?.toUtc().toIso8601String(),
      'endsAt': reminder.endsAt?.toUtc().toIso8601String(),
      'isEnabled': reminder.isEnabled,
      'createdAt': reminder.createdAt.toUtc().toIso8601String(),
      'updatedAt': reminder.updatedAt.toUtc().toIso8601String(),
    };
  }

  Future<bool> _applyRemoteRecord(
    StoredSession session,
    Map<String, Object?> record,
  ) async {
    final id = record['id'];
    final encryptedPayload = record['encryptedPayload'];
    final serverRevision = record['serverRevision'];
    final type = record['type'];
    final payloadVersion = record['payloadVersion'];
    final conflictOfRecordId = record['conflictOfRecordId'];
    if (id is! String ||
        !_uuidPattern.hasMatch(id) ||
        encryptedPayload is! String ||
        encryptedPayload.length > _maxEncryptedPayloadLength ||
        serverRevision is! int ||
        serverRevision < 1 ||
        payloadVersion != 1 ||
        type is! String ||
        (type != 'note' && type != 'tombstone') ||
        (conflictOfRecordId != null && conflictOfRecordId is! String)) {
      throw const SyncException(
        'Recall backup returned an invalid encrypted record.',
      );
    }
    final payload = await _cipher.decryptJson(
      encryptedValue: encryptedPayload,
      masterKey: session.masterKey,
    );
    if (payload['schema'] != 1) {
      throw const SyncException('Encrypted note record is invalid.');
    }

    final isConflictCopy = conflictOfRecordId is String;
    if (isConflictCopy) {
      if (type != 'tombstone' && payload['deleted'] != true) {
        await _writeRemoteNote(payload, idOverride: id, conflictCopy: true);
      }
      await _storeRemoteRecord(
        id: id,
        type: type,
        encryptedPayload: encryptedPayload,
        serverRevision: serverRevision,
        conflictOfRecordId: conflictOfRecordId,
        deletedAt: _dateOrNull(record['deletedAt']),
      );
      return true;
    }

    final localRecord =
        await (_database.select(_database.syncRecords)
              ..where((entry) => entry.id.equals(id))
              ..limit(1))
            .getSingleOrNull();
    if (localRecord != null && localRecord.hasLocalChanges) {
      if (type != 'tombstone' && payload['deleted'] != true) {
        await _writeRemoteNote(
          payload,
          idOverride: _uuid.v7(),
          conflictCopy: true,
        );
      }
      return false;
    }

    if (type == 'tombstone' || payload['deleted'] == true) {
      await (_database.delete(
        _database.notes,
      )..where((note) => note.id.equals(id))).go();
    } else {
      await _writeRemoteNote(payload);
    }
    await _storeRemoteRecord(
      id: id,
      type: type,
      encryptedPayload: encryptedPayload,
      serverRevision: serverRevision,
      deletedAt: _dateOrNull(record['deletedAt']),
      existing: localRecord,
    );
    return true;
  }

  Future<void> _storeRemoteRecord({
    required String id,
    required String type,
    required String encryptedPayload,
    required int serverRevision,
    String? conflictOfRecordId,
    DateTime? deletedAt,
    SyncRecord? existing,
  }) async {
    final now = DateTime.now().toUtc();
    await _database
        .into(_database.syncRecords)
        .insertOnConflictUpdate(
          SyncRecordsCompanion.insert(
            id: id,
            recordType: type,
            encryptedPayload: encryptedPayload,
            clientRevision: existing?.clientRevision ?? 0,
            serverRevision: Value(serverRevision),
            hasLocalChanges: const Value(false),
            hasConflict: const Value(false),
            conflictOfRecordId: Value(conflictOfRecordId),
            deletedAt: Value(deletedAt),
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
  }

  Future<void> _writeRemoteNote(
    Map<String, Object?> payload, {
    String? idOverride,
    bool conflictCopy = false,
  }) async {
    final rawNote = payload['note'];
    if (rawNote is! Map) {
      throw const SyncException('Encrypted note record is invalid.');
    }
    final note = Map<String, Object?>.from(rawNote);
    final id = idOverride ?? _requiredUuid(note, 'id');
    final noteType = _requiredString(note, 'noteType', maxLength: 20);
    final mood = _requiredString(note, 'mood', maxLength: 20);
    if (!const {'text', 'checklist'}.contains(noteType) ||
        !const {
          'clear',
          'focus',
          'urgent',
          'routine',
          'errand',
          'joyful',
          'reflective',
        }.contains(mood)) {
      throw const SyncException('Encrypted note record is invalid.');
    }
    final title = conflictCopy
        ? 'Conflict: ${_requiredString(note, 'title', maxLength: 2000)}'
        : _requiredString(note, 'title', maxLength: 2000);
    final body = _requiredString(note, 'body', maxLength: 500000);
    await _database.transaction(() async {
      final existing =
          await (_database.select(_database.notes)
                ..where((entry) => entry.id.equals(id))
                ..limit(1))
              .getSingleOrNull();
      final values = NotesCompanion(
        title: Value(title),
        body: Value(body),
        noteType: Value(noteType),
        mood: Value(mood),
        moodIsAutomatic: Value(
          _optionalBool(note, 'moodIsAutomatic', fallback: false),
        ),
        isPinned: Value(_requiredBool(note, 'isPinned')),
        isArchived: Value(
          conflictCopy ? false : _requiredBool(note, 'isArchived'),
        ),
        trashedAt: Value(conflictCopy ? null : _dateOrNull(note['trashedAt'])),
        updatedAt: Value(_requiredDate(note, 'updatedAt')),
      );
      if (existing == null) {
        await _database
            .into(_database.notes)
            .insert(
              NotesCompanion.insert(
                id: id,
                title: Value(title),
                body: Value(body),
                noteType: Value(noteType),
                mood: Value(mood),
                moodIsAutomatic: Value(
                  _optionalBool(note, 'moodIsAutomatic', fallback: false),
                ),
                isPinned: Value(_requiredBool(note, 'isPinned')),
                isArchived: Value(
                  conflictCopy ? false : _requiredBool(note, 'isArchived'),
                ),
                trashedAt: Value(
                  conflictCopy ? null : _dateOrNull(note['trashedAt']),
                ),
                createdAt: _requiredDate(note, 'createdAt'),
                updatedAt: _requiredDate(note, 'updatedAt'),
              ),
            );
      } else {
        await (_database.update(
          _database.notes,
        )..where((entry) => entry.id.equals(id))).write(values);
      }

      await (_database.delete(
        _database.checklistItems,
      )..where((item) => item.noteId.equals(id))).go();
      final rawItems = payload['checklistItems'];
      if (rawItems is! List || rawItems.length > 1000) {
        throw const SyncException('Encrypted note record is invalid.');
      }
      if (rawItems.isNotEmpty) {
        for (final rawItem in rawItems) {
          if (rawItem is! Map) {
            throw const SyncException('Encrypted note record is invalid.');
          }
          final item = Map<String, Object?>.from(rawItem);
          await _database
              .into(_database.checklistItems)
              .insert(
                ChecklistItemsCompanion.insert(
                  id: conflictCopy ? _uuid.v7() : _requiredUuid(item, 'id'),
                  noteId: id,
                  content: _requiredString(item, 'content', maxLength: 20000),
                  isDone: Value(_requiredBool(item, 'isDone')),
                  sortOrder: _requiredInt(item, 'sortOrder'),
                  createdAt: _requiredDate(item, 'createdAt'),
                  updatedAt: _requiredDate(item, 'updatedAt'),
                ),
              );
        }
      }

      await (_database.delete(
        _database.reminders,
      )..where((reminder) => reminder.noteId.equals(id))).go();
      final rawReminder = payload['reminder'];
      if (rawReminder is Map && !conflictCopy) {
        final reminder = Map<String, Object?>.from(rawReminder);
        final recurrenceKind = _requiredString(
          reminder,
          'recurrenceKind',
          maxLength: 20,
        );
        if (!const {
          'none',
          'daily',
          'weekly',
          'monthly',
          'yearly',
        }.contains(recurrenceKind)) {
          throw const SyncException('Encrypted note record is invalid.');
        }
        final recurrenceJson = reminder['recurrenceJson'];
        if (recurrenceJson != null &&
            (recurrenceJson is! String || recurrenceJson.length > 20000)) {
          throw const SyncException('Encrypted note record is invalid.');
        }
        await _database
            .into(_database.reminders)
            .insert(
              RemindersCompanion.insert(
                id: _requiredUuid(reminder, 'id'),
                noteId: id,
                nextFireAt: _requiredDate(reminder, 'nextFireAt'),
                timezone: _requiredString(reminder, 'timezone', maxLength: 120),
                recurrenceKind: Value(recurrenceKind),
                recurrenceJson: Value(recurrenceJson as String?),
                snoozeUntil: Value(_dateOrNull(reminder['snoozeUntil'])),
                endsAt: Value(_dateOrNull(reminder['endsAt'])),
                isEnabled: Value(_requiredBool(reminder, 'isEnabled')),
                createdAt: _requiredDate(reminder, 'createdAt'),
                updatedAt: _requiredDate(reminder, 'updatedAt'),
              ),
            );
      }
    });
  }

  Future<int> _latestServerRevision() async {
    final records = await _database.select(_database.syncRecords).get();
    return records.fold<int>(
      0,
      (latest, record) =>
          record.serverRevision != null && record.serverRevision! > latest
          ? record.serverRevision!
          : latest,
    );
  }

  Future<Map<String, Object?>> _requestJson({
    required StoredSession session,
    required String method,
    required String path,
    required Map<String, Object?> body,
    bool retried = false,
  }) async {
    final uri = Uri.parse(session.account.serverUrl).resolve(path);
    final request = await _httpClient.openUrl(method, uri);
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${session.accessToken}',
    );
    request.write(jsonEncode(body));
    final response = await request.close();
    final content = await _readResponse(response);
    final decoded = content.isEmpty ? null : jsonDecode(content);
    if (response.statusCode == HttpStatus.unauthorized && !retried) {
      final refreshed = await _refreshSession(session);
      return _requestJson(
        session: refreshed,
        method: method,
        path: path,
        body: body,
        retried: true,
      );
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map) {
      throw SyncException(
        'Could not sync with Recall backup.',
        retryable:
            response.statusCode == HttpStatus.tooManyRequests ||
            response.statusCode >= 500,
      );
    }
    return Map<String, Object?>.from(decoded);
  }

  Future<StoredSession> _refreshSession(StoredSession session) async {
    final uri = Uri.parse(session.account.serverUrl).resolve('/auth/refresh');
    final request = await _httpClient.postUrl(uri);
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'refreshToken': session.refreshToken}));
    final response = await request.close();
    final content = await _readResponse(response);
    if (response.statusCode != HttpStatus.ok) {
      if (response.statusCode == HttpStatus.tooManyRequests ||
          response.statusCode >= 500) {
        throw const SyncException(
          'Could not refresh the Recall backup session.',
          retryable: true,
        );
      }
      throw const SyncException(
        'Your Recall backup session has expired. Sign in again.',
      );
    }
    final decoded = jsonDecode(content);
    if (decoded is! Map ||
        decoded['accessToken'] is! String ||
        decoded['refreshToken'] is! String) {
      throw const SyncException('Recall backup returned an invalid session.');
    }
    final refreshed = StoredSession(
      account: session.account,
      accessToken: decoded['accessToken'] as String,
      refreshToken: decoded['refreshToken'] as String,
      masterKey: session.masterKey,
    );
    await _accountStore.writeSession(refreshed);
    return refreshed;
  }

  Future<String> _readResponse(HttpClientResponse response) async {
    if (response.contentLength > _maxResponseBytes) {
      throw const SyncException('Recall backup response was too large.');
    }
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in response) {
      length += chunk.length;
      if (length > _maxResponseBytes) {
        throw const SyncException('Recall backup response was too large.');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }

  String _requiredString(
    Map<String, Object?> value,
    String key, {
    int maxLength = 20000,
  }) {
    final item = value[key];
    if (item is! String || item.length > maxLength) {
      throw const SyncException('Encrypted note record is invalid.');
    }
    return item;
  }

  String _requiredUuid(Map<String, Object?> value, String key) {
    final item = _requiredString(value, key, maxLength: 36);
    if (!_uuidPattern.hasMatch(item)) {
      throw const SyncException('Encrypted note record is invalid.');
    }
    return item;
  }

  bool _requiredBool(Map<String, Object?> value, String key) {
    final item = value[key];
    if (item is! bool) {
      throw const SyncException('Encrypted note record is invalid.');
    }
    return item;
  }

  bool _optionalBool(
    Map<String, Object?> value,
    String key, {
    required bool fallback,
  }) {
    final item = value[key];
    if (item == null) {
      return fallback;
    }
    if (item is! bool) {
      throw const SyncException('Encrypted note record is invalid.');
    }
    return item;
  }

  int _requiredInt(Map<String, Object?> value, String key) {
    final item = value[key];
    if (item is! int) {
      throw const SyncException('Encrypted note record is invalid.');
    }
    return item;
  }

  DateTime _requiredDate(Map<String, Object?> value, String key) {
    final parsed = _dateOrNull(value[key]);
    if (parsed == null || parsed.year < 1900 || parsed.year > 2200) {
      throw const SyncException('Encrypted note record is invalid.');
    }
    return parsed;
  }

  DateTime? _dateOrNull(Object? value) {
    if (value is! String) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }
}
