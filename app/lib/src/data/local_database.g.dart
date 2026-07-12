// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _noteTypeMeta = const VerificationMeta(
    'noteType',
  );
  @override
  late final GeneratedColumn<String> noteType = GeneratedColumn<String>(
    'note_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  @override
  late final GeneratedColumn<String> mood = GeneratedColumn<String>(
    'mood',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('clear'),
  );
  static const VerificationMeta _moodIsAutomaticMeta = const VerificationMeta(
    'moodIsAutomatic',
  );
  @override
  late final GeneratedColumn<bool> moodIsAutomatic = GeneratedColumn<bool>(
    'mood_is_automatic',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("mood_is_automatic" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _moodConfidenceMeta = const VerificationMeta(
    'moodConfidence',
  );
  @override
  late final GeneratedColumn<double> moodConfidence = GeneratedColumn<double>(
    'mood_confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _moodModelVersionMeta = const VerificationMeta(
    'moodModelVersion',
  );
  @override
  late final GeneratedColumn<int> moodModelVersion = GeneratedColumn<int>(
    'mood_model_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _trashedAtMeta = const VerificationMeta(
    'trashedAt',
  );
  @override
  late final GeneratedColumn<DateTime> trashedAt = GeneratedColumn<DateTime>(
    'trashed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    body,
    noteType,
    mood,
    moodIsAutomatic,
    moodConfidence,
    moodModelVersion,
    isPinned,
    isArchived,
    trashedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('note_type')) {
      context.handle(
        _noteTypeMeta,
        noteType.isAcceptableOrUnknown(data['note_type']!, _noteTypeMeta),
      );
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    }
    if (data.containsKey('mood_is_automatic')) {
      context.handle(
        _moodIsAutomaticMeta,
        moodIsAutomatic.isAcceptableOrUnknown(
          data['mood_is_automatic']!,
          _moodIsAutomaticMeta,
        ),
      );
    }
    if (data.containsKey('mood_confidence')) {
      context.handle(
        _moodConfidenceMeta,
        moodConfidence.isAcceptableOrUnknown(
          data['mood_confidence']!,
          _moodConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('mood_model_version')) {
      context.handle(
        _moodModelVersionMeta,
        moodModelVersion.isAcceptableOrUnknown(
          data['mood_model_version']!,
          _moodModelVersionMeta,
        ),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('trashed_at')) {
      context.handle(
        _trashedAtMeta,
        trashedAt.isAcceptableOrUnknown(data['trashed_at']!, _trashedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      noteType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_type'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mood'],
      )!,
      moodIsAutomatic: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}mood_is_automatic'],
      )!,
      moodConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mood_confidence'],
      )!,
      moodModelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mood_model_version'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      trashedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}trashed_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final String id;
  final String title;
  final String body;
  final String noteType;
  final String mood;
  final bool moodIsAutomatic;
  final double moodConfidence;
  final int moodModelVersion;
  final bool isPinned;
  final bool isArchived;
  final DateTime? trashedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.noteType,
    required this.mood,
    required this.moodIsAutomatic,
    required this.moodConfidence,
    required this.moodModelVersion,
    required this.isPinned,
    required this.isArchived,
    this.trashedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['note_type'] = Variable<String>(noteType);
    map['mood'] = Variable<String>(mood);
    map['mood_is_automatic'] = Variable<bool>(moodIsAutomatic);
    map['mood_confidence'] = Variable<double>(moodConfidence);
    map['mood_model_version'] = Variable<int>(moodModelVersion);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_archived'] = Variable<bool>(isArchived);
    if (!nullToAbsent || trashedAt != null) {
      map['trashed_at'] = Variable<DateTime>(trashedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      title: Value(title),
      body: Value(body),
      noteType: Value(noteType),
      mood: Value(mood),
      moodIsAutomatic: Value(moodIsAutomatic),
      moodConfidence: Value(moodConfidence),
      moodModelVersion: Value(moodModelVersion),
      isPinned: Value(isPinned),
      isArchived: Value(isArchived),
      trashedAt: trashedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(trashedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      noteType: serializer.fromJson<String>(json['noteType']),
      mood: serializer.fromJson<String>(json['mood']),
      moodIsAutomatic: serializer.fromJson<bool>(json['moodIsAutomatic']),
      moodConfidence: serializer.fromJson<double>(json['moodConfidence']),
      moodModelVersion: serializer.fromJson<int>(json['moodModelVersion']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      trashedAt: serializer.fromJson<DateTime?>(json['trashedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'noteType': serializer.toJson<String>(noteType),
      'mood': serializer.toJson<String>(mood),
      'moodIsAutomatic': serializer.toJson<bool>(moodIsAutomatic),
      'moodConfidence': serializer.toJson<double>(moodConfidence),
      'moodModelVersion': serializer.toJson<int>(moodModelVersion),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isArchived': serializer.toJson<bool>(isArchived),
      'trashedAt': serializer.toJson<DateTime?>(trashedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Note copyWith({
    String? id,
    String? title,
    String? body,
    String? noteType,
    String? mood,
    bool? moodIsAutomatic,
    double? moodConfidence,
    int? moodModelVersion,
    bool? isPinned,
    bool? isArchived,
    Value<DateTime?> trashedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Note(
    id: id ?? this.id,
    title: title ?? this.title,
    body: body ?? this.body,
    noteType: noteType ?? this.noteType,
    mood: mood ?? this.mood,
    moodIsAutomatic: moodIsAutomatic ?? this.moodIsAutomatic,
    moodConfidence: moodConfidence ?? this.moodConfidence,
    moodModelVersion: moodModelVersion ?? this.moodModelVersion,
    isPinned: isPinned ?? this.isPinned,
    isArchived: isArchived ?? this.isArchived,
    trashedAt: trashedAt.present ? trashedAt.value : this.trashedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      noteType: data.noteType.present ? data.noteType.value : this.noteType,
      mood: data.mood.present ? data.mood.value : this.mood,
      moodIsAutomatic: data.moodIsAutomatic.present
          ? data.moodIsAutomatic.value
          : this.moodIsAutomatic,
      moodConfidence: data.moodConfidence.present
          ? data.moodConfidence.value
          : this.moodConfidence,
      moodModelVersion: data.moodModelVersion.present
          ? data.moodModelVersion.value
          : this.moodModelVersion,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      trashedAt: data.trashedAt.present ? data.trashedAt.value : this.trashedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('noteType: $noteType, ')
          ..write('mood: $mood, ')
          ..write('moodIsAutomatic: $moodIsAutomatic, ')
          ..write('moodConfidence: $moodConfidence, ')
          ..write('moodModelVersion: $moodModelVersion, ')
          ..write('isPinned: $isPinned, ')
          ..write('isArchived: $isArchived, ')
          ..write('trashedAt: $trashedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    body,
    noteType,
    mood,
    moodIsAutomatic,
    moodConfidence,
    moodModelVersion,
    isPinned,
    isArchived,
    trashedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.title == this.title &&
          other.body == this.body &&
          other.noteType == this.noteType &&
          other.mood == this.mood &&
          other.moodIsAutomatic == this.moodIsAutomatic &&
          other.moodConfidence == this.moodConfidence &&
          other.moodModelVersion == this.moodModelVersion &&
          other.isPinned == this.isPinned &&
          other.isArchived == this.isArchived &&
          other.trashedAt == this.trashedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> body;
  final Value<String> noteType;
  final Value<String> mood;
  final Value<bool> moodIsAutomatic;
  final Value<double> moodConfidence;
  final Value<int> moodModelVersion;
  final Value<bool> isPinned;
  final Value<bool> isArchived;
  final Value<DateTime?> trashedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.noteType = const Value.absent(),
    this.mood = const Value.absent(),
    this.moodIsAutomatic = const Value.absent(),
    this.moodConfidence = const Value.absent(),
    this.moodModelVersion = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.trashedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.noteType = const Value.absent(),
    this.mood = const Value.absent(),
    this.moodIsAutomatic = const Value.absent(),
    this.moodConfidence = const Value.absent(),
    this.moodModelVersion = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.trashedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Note> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? noteType,
    Expression<String>? mood,
    Expression<bool>? moodIsAutomatic,
    Expression<double>? moodConfidence,
    Expression<int>? moodModelVersion,
    Expression<bool>? isPinned,
    Expression<bool>? isArchived,
    Expression<DateTime>? trashedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (noteType != null) 'note_type': noteType,
      if (mood != null) 'mood': mood,
      if (moodIsAutomatic != null) 'mood_is_automatic': moodIsAutomatic,
      if (moodConfidence != null) 'mood_confidence': moodConfidence,
      if (moodModelVersion != null) 'mood_model_version': moodModelVersion,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isArchived != null) 'is_archived': isArchived,
      if (trashedAt != null) 'trashed_at': trashedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? body,
    Value<String>? noteType,
    Value<String>? mood,
    Value<bool>? moodIsAutomatic,
    Value<double>? moodConfidence,
    Value<int>? moodModelVersion,
    Value<bool>? isPinned,
    Value<bool>? isArchived,
    Value<DateTime?>? trashedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      noteType: noteType ?? this.noteType,
      mood: mood ?? this.mood,
      moodIsAutomatic: moodIsAutomatic ?? this.moodIsAutomatic,
      moodConfidence: moodConfidence ?? this.moodConfidence,
      moodModelVersion: moodModelVersion ?? this.moodModelVersion,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      trashedAt: trashedAt ?? this.trashedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (noteType.present) {
      map['note_type'] = Variable<String>(noteType.value);
    }
    if (mood.present) {
      map['mood'] = Variable<String>(mood.value);
    }
    if (moodIsAutomatic.present) {
      map['mood_is_automatic'] = Variable<bool>(moodIsAutomatic.value);
    }
    if (moodConfidence.present) {
      map['mood_confidence'] = Variable<double>(moodConfidence.value);
    }
    if (moodModelVersion.present) {
      map['mood_model_version'] = Variable<int>(moodModelVersion.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (trashedAt.present) {
      map['trashed_at'] = Variable<DateTime>(trashedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('noteType: $noteType, ')
          ..write('mood: $mood, ')
          ..write('moodIsAutomatic: $moodIsAutomatic, ')
          ..write('moodConfidence: $moodConfidence, ')
          ..write('moodModelVersion: $moodModelVersion, ')
          ..write('isPinned: $isPinned, ')
          ..write('isArchived: $isArchived, ')
          ..write('trashedAt: $trashedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChecklistItemsTable extends ChecklistItems
    with TableInfo<$ChecklistItemsTable, ChecklistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChecklistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDoneMeta = const VerificationMeta('isDone');
  @override
  late final GeneratedColumn<bool> isDone = GeneratedColumn<bool>(
    'is_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    content,
    isDone,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'checklist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChecklistItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['text']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('is_done')) {
      context.handle(
        _isDoneMeta,
        isDone.isAcceptableOrUnknown(data['is_done']!, _isDoneMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChecklistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChecklistItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      isDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_done'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ChecklistItemsTable createAlias(String alias) {
    return $ChecklistItemsTable(attachedDatabase, alias);
  }
}

class ChecklistItem extends DataClass implements Insertable<ChecklistItem> {
  final String id;
  final String noteId;
  final String content;
  final bool isDone;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ChecklistItem({
    required this.id,
    required this.noteId,
    required this.content,
    required this.isDone,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['note_id'] = Variable<String>(noteId);
    map['text'] = Variable<String>(content);
    map['is_done'] = Variable<bool>(isDone);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ChecklistItemsCompanion toCompanion(bool nullToAbsent) {
    return ChecklistItemsCompanion(
      id: Value(id),
      noteId: Value(noteId),
      content: Value(content),
      isDone: Value(isDone),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChecklistItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChecklistItem(
      id: serializer.fromJson<String>(json['id']),
      noteId: serializer.fromJson<String>(json['noteId']),
      content: serializer.fromJson<String>(json['content']),
      isDone: serializer.fromJson<bool>(json['isDone']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteId': serializer.toJson<String>(noteId),
      'content': serializer.toJson<String>(content),
      'isDone': serializer.toJson<bool>(isDone),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ChecklistItem copyWith({
    String? id,
    String? noteId,
    String? content,
    bool? isDone,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ChecklistItem(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    content: content ?? this.content,
    isDone: isDone ?? this.isDone,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ChecklistItem copyWithCompanion(ChecklistItemsCompanion data) {
    return ChecklistItem(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      content: data.content.present ? data.content.value : this.content,
      isDone: data.isDone.present ? data.isDone.value : this.isDone,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChecklistItem(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('content: $content, ')
          ..write('isDone: $isDone, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, noteId, content, isDone, sortOrder, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChecklistItem &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.content == this.content &&
          other.isDone == this.isDone &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ChecklistItemsCompanion extends UpdateCompanion<ChecklistItem> {
  final Value<String> id;
  final Value<String> noteId;
  final Value<String> content;
  final Value<bool> isDone;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ChecklistItemsCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.content = const Value.absent(),
    this.isDone = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChecklistItemsCompanion.insert({
    required String id,
    required String noteId,
    required String content,
    this.isDone = const Value.absent(),
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       noteId = Value(noteId),
       content = Value(content),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ChecklistItem> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<String>? content,
    Expression<bool>? isDone,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (content != null) 'text': content,
      if (isDone != null) 'is_done': isDone,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChecklistItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? noteId,
    Value<String>? content,
    Value<bool>? isDone,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ChecklistItemsCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      content: content ?? this.content,
      isDone: isDone ?? this.isDone,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (content.present) {
      map['text'] = Variable<String>(content.value);
    }
    if (isDone.present) {
      map['is_done'] = Variable<bool>(isDone.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChecklistItemsCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('content: $content, ')
          ..write('isDone: $isDone, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, Reminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nextFireAtMeta = const VerificationMeta(
    'nextFireAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextFireAt = GeneratedColumn<DateTime>(
    'next_fire_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timezoneMeta = const VerificationMeta(
    'timezone',
  );
  @override
  late final GeneratedColumn<String> timezone = GeneratedColumn<String>(
    'timezone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recurrenceKindMeta = const VerificationMeta(
    'recurrenceKind',
  );
  @override
  late final GeneratedColumn<String> recurrenceKind = GeneratedColumn<String>(
    'recurrence_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _recurrenceJsonMeta = const VerificationMeta(
    'recurrenceJson',
  );
  @override
  late final GeneratedColumn<String> recurrenceJson = GeneratedColumn<String>(
    'recurrence_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snoozeUntilMeta = const VerificationMeta(
    'snoozeUntil',
  );
  @override
  late final GeneratedColumn<DateTime> snoozeUntil = GeneratedColumn<DateTime>(
    'snooze_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endsAtMeta = const VerificationMeta('endsAt');
  @override
  late final GeneratedColumn<DateTime> endsAt = GeneratedColumn<DateTime>(
    'ends_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    nextFireAt,
    timezone,
    recurrenceKind,
    recurrenceJson,
    snoozeUntil,
    endsAt,
    isEnabled,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('next_fire_at')) {
      context.handle(
        _nextFireAtMeta,
        nextFireAt.isAcceptableOrUnknown(
          data['next_fire_at']!,
          _nextFireAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextFireAtMeta);
    }
    if (data.containsKey('timezone')) {
      context.handle(
        _timezoneMeta,
        timezone.isAcceptableOrUnknown(data['timezone']!, _timezoneMeta),
      );
    } else if (isInserting) {
      context.missing(_timezoneMeta);
    }
    if (data.containsKey('recurrence_kind')) {
      context.handle(
        _recurrenceKindMeta,
        recurrenceKind.isAcceptableOrUnknown(
          data['recurrence_kind']!,
          _recurrenceKindMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_json')) {
      context.handle(
        _recurrenceJsonMeta,
        recurrenceJson.isAcceptableOrUnknown(
          data['recurrence_json']!,
          _recurrenceJsonMeta,
        ),
      );
    }
    if (data.containsKey('snooze_until')) {
      context.handle(
        _snoozeUntilMeta,
        snoozeUntil.isAcceptableOrUnknown(
          data['snooze_until']!,
          _snoozeUntilMeta,
        ),
      );
    }
    if (data.containsKey('ends_at')) {
      context.handle(
        _endsAtMeta,
        endsAt.isAcceptableOrUnknown(data['ends_at']!, _endsAtMeta),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      nextFireAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_fire_at'],
      )!,
      timezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone'],
      )!,
      recurrenceKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_kind'],
      )!,
      recurrenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_json'],
      ),
      snoozeUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}snooze_until'],
      ),
      endsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ends_at'],
      ),
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class Reminder extends DataClass implements Insertable<Reminder> {
  final String id;
  final String noteId;
  final DateTime nextFireAt;
  final String timezone;
  final String recurrenceKind;
  final String? recurrenceJson;
  final DateTime? snoozeUntil;
  final DateTime? endsAt;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Reminder({
    required this.id,
    required this.noteId,
    required this.nextFireAt,
    required this.timezone,
    required this.recurrenceKind,
    this.recurrenceJson,
    this.snoozeUntil,
    this.endsAt,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['note_id'] = Variable<String>(noteId);
    map['next_fire_at'] = Variable<DateTime>(nextFireAt);
    map['timezone'] = Variable<String>(timezone);
    map['recurrence_kind'] = Variable<String>(recurrenceKind);
    if (!nullToAbsent || recurrenceJson != null) {
      map['recurrence_json'] = Variable<String>(recurrenceJson);
    }
    if (!nullToAbsent || snoozeUntil != null) {
      map['snooze_until'] = Variable<DateTime>(snoozeUntil);
    }
    if (!nullToAbsent || endsAt != null) {
      map['ends_at'] = Variable<DateTime>(endsAt);
    }
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      noteId: Value(noteId),
      nextFireAt: Value(nextFireAt),
      timezone: Value(timezone),
      recurrenceKind: Value(recurrenceKind),
      recurrenceJson: recurrenceJson == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceJson),
      snoozeUntil: snoozeUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozeUntil),
      endsAt: endsAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endsAt),
      isEnabled: Value(isEnabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Reminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reminder(
      id: serializer.fromJson<String>(json['id']),
      noteId: serializer.fromJson<String>(json['noteId']),
      nextFireAt: serializer.fromJson<DateTime>(json['nextFireAt']),
      timezone: serializer.fromJson<String>(json['timezone']),
      recurrenceKind: serializer.fromJson<String>(json['recurrenceKind']),
      recurrenceJson: serializer.fromJson<String?>(json['recurrenceJson']),
      snoozeUntil: serializer.fromJson<DateTime?>(json['snoozeUntil']),
      endsAt: serializer.fromJson<DateTime?>(json['endsAt']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteId': serializer.toJson<String>(noteId),
      'nextFireAt': serializer.toJson<DateTime>(nextFireAt),
      'timezone': serializer.toJson<String>(timezone),
      'recurrenceKind': serializer.toJson<String>(recurrenceKind),
      'recurrenceJson': serializer.toJson<String?>(recurrenceJson),
      'snoozeUntil': serializer.toJson<DateTime?>(snoozeUntil),
      'endsAt': serializer.toJson<DateTime?>(endsAt),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Reminder copyWith({
    String? id,
    String? noteId,
    DateTime? nextFireAt,
    String? timezone,
    String? recurrenceKind,
    Value<String?> recurrenceJson = const Value.absent(),
    Value<DateTime?> snoozeUntil = const Value.absent(),
    Value<DateTime?> endsAt = const Value.absent(),
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Reminder(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    nextFireAt: nextFireAt ?? this.nextFireAt,
    timezone: timezone ?? this.timezone,
    recurrenceKind: recurrenceKind ?? this.recurrenceKind,
    recurrenceJson: recurrenceJson.present
        ? recurrenceJson.value
        : this.recurrenceJson,
    snoozeUntil: snoozeUntil.present ? snoozeUntil.value : this.snoozeUntil,
    endsAt: endsAt.present ? endsAt.value : this.endsAt,
    isEnabled: isEnabled ?? this.isEnabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Reminder copyWithCompanion(RemindersCompanion data) {
    return Reminder(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      nextFireAt: data.nextFireAt.present
          ? data.nextFireAt.value
          : this.nextFireAt,
      timezone: data.timezone.present ? data.timezone.value : this.timezone,
      recurrenceKind: data.recurrenceKind.present
          ? data.recurrenceKind.value
          : this.recurrenceKind,
      recurrenceJson: data.recurrenceJson.present
          ? data.recurrenceJson.value
          : this.recurrenceJson,
      snoozeUntil: data.snoozeUntil.present
          ? data.snoozeUntil.value
          : this.snoozeUntil,
      endsAt: data.endsAt.present ? data.endsAt.value : this.endsAt,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reminder(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('nextFireAt: $nextFireAt, ')
          ..write('timezone: $timezone, ')
          ..write('recurrenceKind: $recurrenceKind, ')
          ..write('recurrenceJson: $recurrenceJson, ')
          ..write('snoozeUntil: $snoozeUntil, ')
          ..write('endsAt: $endsAt, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    noteId,
    nextFireAt,
    timezone,
    recurrenceKind,
    recurrenceJson,
    snoozeUntil,
    endsAt,
    isEnabled,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reminder &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.nextFireAt == this.nextFireAt &&
          other.timezone == this.timezone &&
          other.recurrenceKind == this.recurrenceKind &&
          other.recurrenceJson == this.recurrenceJson &&
          other.snoozeUntil == this.snoozeUntil &&
          other.endsAt == this.endsAt &&
          other.isEnabled == this.isEnabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RemindersCompanion extends UpdateCompanion<Reminder> {
  final Value<String> id;
  final Value<String> noteId;
  final Value<DateTime> nextFireAt;
  final Value<String> timezone;
  final Value<String> recurrenceKind;
  final Value<String?> recurrenceJson;
  final Value<DateTime?> snoozeUntil;
  final Value<DateTime?> endsAt;
  final Value<bool> isEnabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.nextFireAt = const Value.absent(),
    this.timezone = const Value.absent(),
    this.recurrenceKind = const Value.absent(),
    this.recurrenceJson = const Value.absent(),
    this.snoozeUntil = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemindersCompanion.insert({
    required String id,
    required String noteId,
    required DateTime nextFireAt,
    required String timezone,
    this.recurrenceKind = const Value.absent(),
    this.recurrenceJson = const Value.absent(),
    this.snoozeUntil = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.isEnabled = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       noteId = Value(noteId),
       nextFireAt = Value(nextFireAt),
       timezone = Value(timezone),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Reminder> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<DateTime>? nextFireAt,
    Expression<String>? timezone,
    Expression<String>? recurrenceKind,
    Expression<String>? recurrenceJson,
    Expression<DateTime>? snoozeUntil,
    Expression<DateTime>? endsAt,
    Expression<bool>? isEnabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (nextFireAt != null) 'next_fire_at': nextFireAt,
      if (timezone != null) 'timezone': timezone,
      if (recurrenceKind != null) 'recurrence_kind': recurrenceKind,
      if (recurrenceJson != null) 'recurrence_json': recurrenceJson,
      if (snoozeUntil != null) 'snooze_until': snoozeUntil,
      if (endsAt != null) 'ends_at': endsAt,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemindersCompanion copyWith({
    Value<String>? id,
    Value<String>? noteId,
    Value<DateTime>? nextFireAt,
    Value<String>? timezone,
    Value<String>? recurrenceKind,
    Value<String?>? recurrenceJson,
    Value<DateTime?>? snoozeUntil,
    Value<DateTime?>? endsAt,
    Value<bool>? isEnabled,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      nextFireAt: nextFireAt ?? this.nextFireAt,
      timezone: timezone ?? this.timezone,
      recurrenceKind: recurrenceKind ?? this.recurrenceKind,
      recurrenceJson: recurrenceJson ?? this.recurrenceJson,
      snoozeUntil: snoozeUntil ?? this.snoozeUntil,
      endsAt: endsAt ?? this.endsAt,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (nextFireAt.present) {
      map['next_fire_at'] = Variable<DateTime>(nextFireAt.value);
    }
    if (timezone.present) {
      map['timezone'] = Variable<String>(timezone.value);
    }
    if (recurrenceKind.present) {
      map['recurrence_kind'] = Variable<String>(recurrenceKind.value);
    }
    if (recurrenceJson.present) {
      map['recurrence_json'] = Variable<String>(recurrenceJson.value);
    }
    if (snoozeUntil.present) {
      map['snooze_until'] = Variable<DateTime>(snoozeUntil.value);
    }
    if (endsAt.present) {
      map['ends_at'] = Variable<DateTime>(endsAt.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('nextFireAt: $nextFireAt, ')
          ..write('timezone: $timezone, ')
          ..write('recurrenceKind: $recurrenceKind, ')
          ..write('recurrenceJson: $recurrenceJson, ')
          ..write('snoozeUntil: $snoozeUntil, ')
          ..write('endsAt: $endsAt, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReminderOccurrencesTable extends ReminderOccurrences
    with TableInfo<$ReminderOccurrencesTable, ReminderOccurrence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReminderOccurrencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reminderIdMeta = const VerificationMeta(
    'reminderId',
  );
  @override
  late final GeneratedColumn<String> reminderId = GeneratedColumn<String>(
    'reminder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES reminders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _scheduledForMeta = const VerificationMeta(
    'scheduledFor',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledFor = GeneratedColumn<DateTime>(
    'scheduled_for',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actedAtMeta = const VerificationMeta(
    'actedAt',
  );
  @override
  late final GeneratedColumn<DateTime> actedAt = GeneratedColumn<DateTime>(
    'acted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snoozedUntilMeta = const VerificationMeta(
    'snoozedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> snoozedUntil = GeneratedColumn<DateTime>(
    'snoozed_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    reminderId,
    scheduledFor,
    status,
    actedAt,
    snoozedUntil,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminder_occurrences';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderOccurrence> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('reminder_id')) {
      context.handle(
        _reminderIdMeta,
        reminderId.isAcceptableOrUnknown(data['reminder_id']!, _reminderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_reminderIdMeta);
    }
    if (data.containsKey('scheduled_for')) {
      context.handle(
        _scheduledForMeta,
        scheduledFor.isAcceptableOrUnknown(
          data['scheduled_for']!,
          _scheduledForMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledForMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('acted_at')) {
      context.handle(
        _actedAtMeta,
        actedAt.isAcceptableOrUnknown(data['acted_at']!, _actedAtMeta),
      );
    }
    if (data.containsKey('snoozed_until')) {
      context.handle(
        _snoozedUntilMeta,
        snoozedUntil.isAcceptableOrUnknown(
          data['snoozed_until']!,
          _snoozedUntilMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReminderOccurrence map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderOccurrence(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      reminderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_id'],
      )!,
      scheduledFor: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_for'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      actedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}acted_at'],
      ),
      snoozedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}snoozed_until'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ReminderOccurrencesTable createAlias(String alias) {
    return $ReminderOccurrencesTable(attachedDatabase, alias);
  }
}

class ReminderOccurrence extends DataClass
    implements Insertable<ReminderOccurrence> {
  final String id;
  final String reminderId;
  final DateTime scheduledFor;
  final String status;
  final DateTime? actedAt;
  final DateTime? snoozedUntil;
  final DateTime createdAt;
  const ReminderOccurrence({
    required this.id,
    required this.reminderId,
    required this.scheduledFor,
    required this.status,
    this.actedAt,
    this.snoozedUntil,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['reminder_id'] = Variable<String>(reminderId);
    map['scheduled_for'] = Variable<DateTime>(scheduledFor);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || actedAt != null) {
      map['acted_at'] = Variable<DateTime>(actedAt);
    }
    if (!nullToAbsent || snoozedUntil != null) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ReminderOccurrencesCompanion toCompanion(bool nullToAbsent) {
    return ReminderOccurrencesCompanion(
      id: Value(id),
      reminderId: Value(reminderId),
      scheduledFor: Value(scheduledFor),
      status: Value(status),
      actedAt: actedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(actedAt),
      snoozedUntil: snoozedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntil),
      createdAt: Value(createdAt),
    );
  }

  factory ReminderOccurrence.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderOccurrence(
      id: serializer.fromJson<String>(json['id']),
      reminderId: serializer.fromJson<String>(json['reminderId']),
      scheduledFor: serializer.fromJson<DateTime>(json['scheduledFor']),
      status: serializer.fromJson<String>(json['status']),
      actedAt: serializer.fromJson<DateTime?>(json['actedAt']),
      snoozedUntil: serializer.fromJson<DateTime?>(json['snoozedUntil']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'reminderId': serializer.toJson<String>(reminderId),
      'scheduledFor': serializer.toJson<DateTime>(scheduledFor),
      'status': serializer.toJson<String>(status),
      'actedAt': serializer.toJson<DateTime?>(actedAt),
      'snoozedUntil': serializer.toJson<DateTime?>(snoozedUntil),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ReminderOccurrence copyWith({
    String? id,
    String? reminderId,
    DateTime? scheduledFor,
    String? status,
    Value<DateTime?> actedAt = const Value.absent(),
    Value<DateTime?> snoozedUntil = const Value.absent(),
    DateTime? createdAt,
  }) => ReminderOccurrence(
    id: id ?? this.id,
    reminderId: reminderId ?? this.reminderId,
    scheduledFor: scheduledFor ?? this.scheduledFor,
    status: status ?? this.status,
    actedAt: actedAt.present ? actedAt.value : this.actedAt,
    snoozedUntil: snoozedUntil.present ? snoozedUntil.value : this.snoozedUntil,
    createdAt: createdAt ?? this.createdAt,
  );
  ReminderOccurrence copyWithCompanion(ReminderOccurrencesCompanion data) {
    return ReminderOccurrence(
      id: data.id.present ? data.id.value : this.id,
      reminderId: data.reminderId.present
          ? data.reminderId.value
          : this.reminderId,
      scheduledFor: data.scheduledFor.present
          ? data.scheduledFor.value
          : this.scheduledFor,
      status: data.status.present ? data.status.value : this.status,
      actedAt: data.actedAt.present ? data.actedAt.value : this.actedAt,
      snoozedUntil: data.snoozedUntil.present
          ? data.snoozedUntil.value
          : this.snoozedUntil,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderOccurrence(')
          ..write('id: $id, ')
          ..write('reminderId: $reminderId, ')
          ..write('scheduledFor: $scheduledFor, ')
          ..write('status: $status, ')
          ..write('actedAt: $actedAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    reminderId,
    scheduledFor,
    status,
    actedAt,
    snoozedUntil,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderOccurrence &&
          other.id == this.id &&
          other.reminderId == this.reminderId &&
          other.scheduledFor == this.scheduledFor &&
          other.status == this.status &&
          other.actedAt == this.actedAt &&
          other.snoozedUntil == this.snoozedUntil &&
          other.createdAt == this.createdAt);
}

class ReminderOccurrencesCompanion extends UpdateCompanion<ReminderOccurrence> {
  final Value<String> id;
  final Value<String> reminderId;
  final Value<DateTime> scheduledFor;
  final Value<String> status;
  final Value<DateTime?> actedAt;
  final Value<DateTime?> snoozedUntil;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ReminderOccurrencesCompanion({
    this.id = const Value.absent(),
    this.reminderId = const Value.absent(),
    this.scheduledFor = const Value.absent(),
    this.status = const Value.absent(),
    this.actedAt = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReminderOccurrencesCompanion.insert({
    required String id,
    required String reminderId,
    required DateTime scheduledFor,
    required String status,
    this.actedAt = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       reminderId = Value(reminderId),
       scheduledFor = Value(scheduledFor),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<ReminderOccurrence> custom({
    Expression<String>? id,
    Expression<String>? reminderId,
    Expression<DateTime>? scheduledFor,
    Expression<String>? status,
    Expression<DateTime>? actedAt,
    Expression<DateTime>? snoozedUntil,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (reminderId != null) 'reminder_id': reminderId,
      if (scheduledFor != null) 'scheduled_for': scheduledFor,
      if (status != null) 'status': status,
      if (actedAt != null) 'acted_at': actedAt,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReminderOccurrencesCompanion copyWith({
    Value<String>? id,
    Value<String>? reminderId,
    Value<DateTime>? scheduledFor,
    Value<String>? status,
    Value<DateTime?>? actedAt,
    Value<DateTime?>? snoozedUntil,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ReminderOccurrencesCompanion(
      id: id ?? this.id,
      reminderId: reminderId ?? this.reminderId,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      status: status ?? this.status,
      actedAt: actedAt ?? this.actedAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (reminderId.present) {
      map['reminder_id'] = Variable<String>(reminderId.value);
    }
    if (scheduledFor.present) {
      map['scheduled_for'] = Variable<DateTime>(scheduledFor.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (actedAt.present) {
      map['acted_at'] = Variable<DateTime>(actedAt.value);
    }
    if (snoozedUntil.present) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReminderOccurrencesCompanion(')
          ..write('id: $id, ')
          ..write('reminderId: $reminderId, ')
          ..write('scheduledFor: $scheduledFor, ')
          ..write('status: $status, ')
          ..write('actedAt: $actedAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncRecordsTable extends SyncRecords
    with TableInfo<$SyncRecordsTable, SyncRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordTypeMeta = const VerificationMeta(
    'recordType',
  );
  @override
  late final GeneratedColumn<String> recordType = GeneratedColumn<String>(
    'record_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedPayloadMeta = const VerificationMeta(
    'encryptedPayload',
  );
  @override
  late final GeneratedColumn<String> encryptedPayload = GeneratedColumn<String>(
    'encrypted_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadVersionMeta = const VerificationMeta(
    'payloadVersion',
  );
  @override
  late final GeneratedColumn<int> payloadVersion = GeneratedColumn<int>(
    'payload_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _clientRevisionMeta = const VerificationMeta(
    'clientRevision',
  );
  @override
  late final GeneratedColumn<int> clientRevision = GeneratedColumn<int>(
    'client_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverRevisionMeta = const VerificationMeta(
    'serverRevision',
  );
  @override
  late final GeneratedColumn<int> serverRevision = GeneratedColumn<int>(
    'server_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasLocalChangesMeta = const VerificationMeta(
    'hasLocalChanges',
  );
  @override
  late final GeneratedColumn<bool> hasLocalChanges = GeneratedColumn<bool>(
    'has_local_changes',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_local_changes" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _hasConflictMeta = const VerificationMeta(
    'hasConflict',
  );
  @override
  late final GeneratedColumn<bool> hasConflict = GeneratedColumn<bool>(
    'has_conflict',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_conflict" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _conflictOfRecordIdMeta =
      const VerificationMeta('conflictOfRecordId');
  @override
  late final GeneratedColumn<String> conflictOfRecordId =
      GeneratedColumn<String>(
        'conflict_of_record_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordType,
    encryptedPayload,
    payloadVersion,
    clientRevision,
    serverRevision,
    hasLocalChanges,
    hasConflict,
    conflictOfRecordId,
    deletedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('record_type')) {
      context.handle(
        _recordTypeMeta,
        recordType.isAcceptableOrUnknown(data['record_type']!, _recordTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_recordTypeMeta);
    }
    if (data.containsKey('encrypted_payload')) {
      context.handle(
        _encryptedPayloadMeta,
        encryptedPayload.isAcceptableOrUnknown(
          data['encrypted_payload']!,
          _encryptedPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedPayloadMeta);
    }
    if (data.containsKey('payload_version')) {
      context.handle(
        _payloadVersionMeta,
        payloadVersion.isAcceptableOrUnknown(
          data['payload_version']!,
          _payloadVersionMeta,
        ),
      );
    }
    if (data.containsKey('client_revision')) {
      context.handle(
        _clientRevisionMeta,
        clientRevision.isAcceptableOrUnknown(
          data['client_revision']!,
          _clientRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientRevisionMeta);
    }
    if (data.containsKey('server_revision')) {
      context.handle(
        _serverRevisionMeta,
        serverRevision.isAcceptableOrUnknown(
          data['server_revision']!,
          _serverRevisionMeta,
        ),
      );
    }
    if (data.containsKey('has_local_changes')) {
      context.handle(
        _hasLocalChangesMeta,
        hasLocalChanges.isAcceptableOrUnknown(
          data['has_local_changes']!,
          _hasLocalChangesMeta,
        ),
      );
    }
    if (data.containsKey('has_conflict')) {
      context.handle(
        _hasConflictMeta,
        hasConflict.isAcceptableOrUnknown(
          data['has_conflict']!,
          _hasConflictMeta,
        ),
      );
    }
    if (data.containsKey('conflict_of_record_id')) {
      context.handle(
        _conflictOfRecordIdMeta,
        conflictOfRecordId.isAcceptableOrUnknown(
          data['conflict_of_record_id']!,
          _conflictOfRecordIdMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      recordType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_type'],
      )!,
      encryptedPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_payload'],
      )!,
      payloadVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payload_version'],
      )!,
      clientRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_revision'],
      )!,
      serverRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_revision'],
      ),
      hasLocalChanges: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_local_changes'],
      )!,
      hasConflict: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_conflict'],
      )!,
      conflictOfRecordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_of_record_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncRecordsTable createAlias(String alias) {
    return $SyncRecordsTable(attachedDatabase, alias);
  }
}

class SyncRecord extends DataClass implements Insertable<SyncRecord> {
  final String id;
  final String recordType;
  final String encryptedPayload;
  final int payloadVersion;
  final int clientRevision;
  final int? serverRevision;
  final bool hasLocalChanges;
  final bool hasConflict;
  final String? conflictOfRecordId;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SyncRecord({
    required this.id,
    required this.recordType,
    required this.encryptedPayload,
    required this.payloadVersion,
    required this.clientRevision,
    this.serverRevision,
    required this.hasLocalChanges,
    required this.hasConflict,
    this.conflictOfRecordId,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['record_type'] = Variable<String>(recordType);
    map['encrypted_payload'] = Variable<String>(encryptedPayload);
    map['payload_version'] = Variable<int>(payloadVersion);
    map['client_revision'] = Variable<int>(clientRevision);
    if (!nullToAbsent || serverRevision != null) {
      map['server_revision'] = Variable<int>(serverRevision);
    }
    map['has_local_changes'] = Variable<bool>(hasLocalChanges);
    map['has_conflict'] = Variable<bool>(hasConflict);
    if (!nullToAbsent || conflictOfRecordId != null) {
      map['conflict_of_record_id'] = Variable<String>(conflictOfRecordId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncRecordsCompanion toCompanion(bool nullToAbsent) {
    return SyncRecordsCompanion(
      id: Value(id),
      recordType: Value(recordType),
      encryptedPayload: Value(encryptedPayload),
      payloadVersion: Value(payloadVersion),
      clientRevision: Value(clientRevision),
      serverRevision: serverRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(serverRevision),
      hasLocalChanges: Value(hasLocalChanges),
      hasConflict: Value(hasConflict),
      conflictOfRecordId: conflictOfRecordId == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictOfRecordId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncRecord(
      id: serializer.fromJson<String>(json['id']),
      recordType: serializer.fromJson<String>(json['recordType']),
      encryptedPayload: serializer.fromJson<String>(json['encryptedPayload']),
      payloadVersion: serializer.fromJson<int>(json['payloadVersion']),
      clientRevision: serializer.fromJson<int>(json['clientRevision']),
      serverRevision: serializer.fromJson<int?>(json['serverRevision']),
      hasLocalChanges: serializer.fromJson<bool>(json['hasLocalChanges']),
      hasConflict: serializer.fromJson<bool>(json['hasConflict']),
      conflictOfRecordId: serializer.fromJson<String?>(
        json['conflictOfRecordId'],
      ),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'recordType': serializer.toJson<String>(recordType),
      'encryptedPayload': serializer.toJson<String>(encryptedPayload),
      'payloadVersion': serializer.toJson<int>(payloadVersion),
      'clientRevision': serializer.toJson<int>(clientRevision),
      'serverRevision': serializer.toJson<int?>(serverRevision),
      'hasLocalChanges': serializer.toJson<bool>(hasLocalChanges),
      'hasConflict': serializer.toJson<bool>(hasConflict),
      'conflictOfRecordId': serializer.toJson<String?>(conflictOfRecordId),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncRecord copyWith({
    String? id,
    String? recordType,
    String? encryptedPayload,
    int? payloadVersion,
    int? clientRevision,
    Value<int?> serverRevision = const Value.absent(),
    bool? hasLocalChanges,
    bool? hasConflict,
    Value<String?> conflictOfRecordId = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SyncRecord(
    id: id ?? this.id,
    recordType: recordType ?? this.recordType,
    encryptedPayload: encryptedPayload ?? this.encryptedPayload,
    payloadVersion: payloadVersion ?? this.payloadVersion,
    clientRevision: clientRevision ?? this.clientRevision,
    serverRevision: serverRevision.present
        ? serverRevision.value
        : this.serverRevision,
    hasLocalChanges: hasLocalChanges ?? this.hasLocalChanges,
    hasConflict: hasConflict ?? this.hasConflict,
    conflictOfRecordId: conflictOfRecordId.present
        ? conflictOfRecordId.value
        : this.conflictOfRecordId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SyncRecord copyWithCompanion(SyncRecordsCompanion data) {
    return SyncRecord(
      id: data.id.present ? data.id.value : this.id,
      recordType: data.recordType.present
          ? data.recordType.value
          : this.recordType,
      encryptedPayload: data.encryptedPayload.present
          ? data.encryptedPayload.value
          : this.encryptedPayload,
      payloadVersion: data.payloadVersion.present
          ? data.payloadVersion.value
          : this.payloadVersion,
      clientRevision: data.clientRevision.present
          ? data.clientRevision.value
          : this.clientRevision,
      serverRevision: data.serverRevision.present
          ? data.serverRevision.value
          : this.serverRevision,
      hasLocalChanges: data.hasLocalChanges.present
          ? data.hasLocalChanges.value
          : this.hasLocalChanges,
      hasConflict: data.hasConflict.present
          ? data.hasConflict.value
          : this.hasConflict,
      conflictOfRecordId: data.conflictOfRecordId.present
          ? data.conflictOfRecordId.value
          : this.conflictOfRecordId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncRecord(')
          ..write('id: $id, ')
          ..write('recordType: $recordType, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('payloadVersion: $payloadVersion, ')
          ..write('clientRevision: $clientRevision, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('hasLocalChanges: $hasLocalChanges, ')
          ..write('hasConflict: $hasConflict, ')
          ..write('conflictOfRecordId: $conflictOfRecordId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    recordType,
    encryptedPayload,
    payloadVersion,
    clientRevision,
    serverRevision,
    hasLocalChanges,
    hasConflict,
    conflictOfRecordId,
    deletedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncRecord &&
          other.id == this.id &&
          other.recordType == this.recordType &&
          other.encryptedPayload == this.encryptedPayload &&
          other.payloadVersion == this.payloadVersion &&
          other.clientRevision == this.clientRevision &&
          other.serverRevision == this.serverRevision &&
          other.hasLocalChanges == this.hasLocalChanges &&
          other.hasConflict == this.hasConflict &&
          other.conflictOfRecordId == this.conflictOfRecordId &&
          other.deletedAt == this.deletedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SyncRecordsCompanion extends UpdateCompanion<SyncRecord> {
  final Value<String> id;
  final Value<String> recordType;
  final Value<String> encryptedPayload;
  final Value<int> payloadVersion;
  final Value<int> clientRevision;
  final Value<int?> serverRevision;
  final Value<bool> hasLocalChanges;
  final Value<bool> hasConflict;
  final Value<String?> conflictOfRecordId;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncRecordsCompanion({
    this.id = const Value.absent(),
    this.recordType = const Value.absent(),
    this.encryptedPayload = const Value.absent(),
    this.payloadVersion = const Value.absent(),
    this.clientRevision = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.hasLocalChanges = const Value.absent(),
    this.hasConflict = const Value.absent(),
    this.conflictOfRecordId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncRecordsCompanion.insert({
    required String id,
    required String recordType,
    required String encryptedPayload,
    this.payloadVersion = const Value.absent(),
    required int clientRevision,
    this.serverRevision = const Value.absent(),
    this.hasLocalChanges = const Value.absent(),
    this.hasConflict = const Value.absent(),
    this.conflictOfRecordId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       recordType = Value(recordType),
       encryptedPayload = Value(encryptedPayload),
       clientRevision = Value(clientRevision),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SyncRecord> custom({
    Expression<String>? id,
    Expression<String>? recordType,
    Expression<String>? encryptedPayload,
    Expression<int>? payloadVersion,
    Expression<int>? clientRevision,
    Expression<int>? serverRevision,
    Expression<bool>? hasLocalChanges,
    Expression<bool>? hasConflict,
    Expression<String>? conflictOfRecordId,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordType != null) 'record_type': recordType,
      if (encryptedPayload != null) 'encrypted_payload': encryptedPayload,
      if (payloadVersion != null) 'payload_version': payloadVersion,
      if (clientRevision != null) 'client_revision': clientRevision,
      if (serverRevision != null) 'server_revision': serverRevision,
      if (hasLocalChanges != null) 'has_local_changes': hasLocalChanges,
      if (hasConflict != null) 'has_conflict': hasConflict,
      if (conflictOfRecordId != null)
        'conflict_of_record_id': conflictOfRecordId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? recordType,
    Value<String>? encryptedPayload,
    Value<int>? payloadVersion,
    Value<int>? clientRevision,
    Value<int?>? serverRevision,
    Value<bool>? hasLocalChanges,
    Value<bool>? hasConflict,
    Value<String?>? conflictOfRecordId,
    Value<DateTime?>? deletedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncRecordsCompanion(
      id: id ?? this.id,
      recordType: recordType ?? this.recordType,
      encryptedPayload: encryptedPayload ?? this.encryptedPayload,
      payloadVersion: payloadVersion ?? this.payloadVersion,
      clientRevision: clientRevision ?? this.clientRevision,
      serverRevision: serverRevision ?? this.serverRevision,
      hasLocalChanges: hasLocalChanges ?? this.hasLocalChanges,
      hasConflict: hasConflict ?? this.hasConflict,
      conflictOfRecordId: conflictOfRecordId ?? this.conflictOfRecordId,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (recordType.present) {
      map['record_type'] = Variable<String>(recordType.value);
    }
    if (encryptedPayload.present) {
      map['encrypted_payload'] = Variable<String>(encryptedPayload.value);
    }
    if (payloadVersion.present) {
      map['payload_version'] = Variable<int>(payloadVersion.value);
    }
    if (clientRevision.present) {
      map['client_revision'] = Variable<int>(clientRevision.value);
    }
    if (serverRevision.present) {
      map['server_revision'] = Variable<int>(serverRevision.value);
    }
    if (hasLocalChanges.present) {
      map['has_local_changes'] = Variable<bool>(hasLocalChanges.value);
    }
    if (hasConflict.present) {
      map['has_conflict'] = Variable<bool>(hasConflict.value);
    }
    if (conflictOfRecordId.present) {
      map['conflict_of_record_id'] = Variable<String>(conflictOfRecordId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRecordsCompanion(')
          ..write('id: $id, ')
          ..write('recordType: $recordType, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('payloadVersion: $payloadVersion, ')
          ..write('clientRevision: $clientRevision, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('hasLocalChanges: $hasLocalChanges, ')
          ..write('hasConflict: $hasConflict, ')
          ..write('conflictOfRecordId: $conflictOfRecordId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $ChecklistItemsTable checklistItems = $ChecklistItemsTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $ReminderOccurrencesTable reminderOccurrences =
      $ReminderOccurrencesTable(this);
  late final $SyncRecordsTable syncRecords = $SyncRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    notes,
    checklistItems,
    reminders,
    reminderOccurrences,
    syncRecords,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('checklist_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reminders', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'reminders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reminder_occurrences', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      required String id,
      Value<String> title,
      Value<String> body,
      Value<String> noteType,
      Value<String> mood,
      Value<bool> moodIsAutomatic,
      Value<double> moodConfidence,
      Value<int> moodModelVersion,
      Value<bool> isPinned,
      Value<bool> isArchived,
      Value<DateTime?> trashedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> body,
      Value<String> noteType,
      Value<String> mood,
      Value<bool> moodIsAutomatic,
      Value<double> moodConfidence,
      Value<int> moodModelVersion,
      Value<bool> isPinned,
      Value<bool> isArchived,
      Value<DateTime?> trashedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$NotesTableReferences
    extends BaseReferences<_$LocalDatabase, $NotesTable, Note> {
  $$NotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ChecklistItemsTable, List<ChecklistItem>>
  _checklistItemsRefsTable(_$LocalDatabase db) => MultiTypedResultKey.fromTable(
    db.checklistItems,
    aliasName: 'notes__id__checklist_items__note_id',
  );

  $$ChecklistItemsTableProcessedTableManager get checklistItemsRefs {
    final manager = $$ChecklistItemsTableTableManager(
      $_db,
      $_db.checklistItems,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_checklistItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RemindersTable, List<Reminder>>
  _remindersRefsTable(_$LocalDatabase db) => MultiTypedResultKey.fromTable(
    db.reminders,
    aliasName: 'notes__id__reminders__note_id',
  );

  $$RemindersTableProcessedTableManager get remindersRefs {
    final manager = $$RemindersTableTableManager(
      $_db,
      $_db.reminders,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_remindersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NotesTableFilterComposer
    extends Composer<_$LocalDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteType => $composableBuilder(
    column: $table.noteType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get moodIsAutomatic => $composableBuilder(
    column: $table.moodIsAutomatic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get moodConfidence => $composableBuilder(
    column: $table.moodConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get moodModelVersion => $composableBuilder(
    column: $table.moodModelVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get trashedAt => $composableBuilder(
    column: $table.trashedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> checklistItemsRefs(
    Expression<bool> Function($$ChecklistItemsTableFilterComposer f) f,
  ) {
    final $$ChecklistItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.checklistItems,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChecklistItemsTableFilterComposer(
            $db: $db,
            $table: $db.checklistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> remindersRefs(
    Expression<bool> Function($$RemindersTableFilterComposer f) f,
  ) {
    final $$RemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableFilterComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotesTableOrderingComposer
    extends Composer<_$LocalDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteType => $composableBuilder(
    column: $table.noteType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get moodIsAutomatic => $composableBuilder(
    column: $table.moodIsAutomatic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get moodConfidence => $composableBuilder(
    column: $table.moodConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get moodModelVersion => $composableBuilder(
    column: $table.moodModelVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get trashedAt => $composableBuilder(
    column: $table.trashedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get noteType =>
      $composableBuilder(column: $table.noteType, builder: (column) => column);

  GeneratedColumn<String> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumn<bool> get moodIsAutomatic => $composableBuilder(
    column: $table.moodIsAutomatic,
    builder: (column) => column,
  );

  GeneratedColumn<double> get moodConfidence => $composableBuilder(
    column: $table.moodConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get moodModelVersion => $composableBuilder(
    column: $table.moodModelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get trashedAt =>
      $composableBuilder(column: $table.trashedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> checklistItemsRefs<T extends Object>(
    Expression<T> Function($$ChecklistItemsTableAnnotationComposer a) f,
  ) {
    final $$ChecklistItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.checklistItems,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChecklistItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.checklistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> remindersRefs<T extends Object>(
    Expression<T> Function($$RemindersTableAnnotationComposer a) f,
  ) {
    final $$RemindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableAnnotationComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, $$NotesTableReferences),
          Note,
          PrefetchHooks Function({bool checklistItemsRefs, bool remindersRefs})
        > {
  $$NotesTableTableManager(_$LocalDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> noteType = const Value.absent(),
                Value<String> mood = const Value.absent(),
                Value<bool> moodIsAutomatic = const Value.absent(),
                Value<double> moodConfidence = const Value.absent(),
                Value<int> moodModelVersion = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime?> trashedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                title: title,
                body: body,
                noteType: noteType,
                mood: mood,
                moodIsAutomatic: moodIsAutomatic,
                moodConfidence: moodConfidence,
                moodModelVersion: moodModelVersion,
                isPinned: isPinned,
                isArchived: isArchived,
                trashedAt: trashedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> noteType = const Value.absent(),
                Value<String> mood = const Value.absent(),
                Value<bool> moodIsAutomatic = const Value.absent(),
                Value<double> moodConfidence = const Value.absent(),
                Value<int> moodModelVersion = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime?> trashedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                title: title,
                body: body,
                noteType: noteType,
                mood: mood,
                moodIsAutomatic: moodIsAutomatic,
                moodConfidence: moodConfidence,
                moodModelVersion: moodModelVersion,
                isPinned: isPinned,
                isArchived: isArchived,
                trashedAt: trashedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$NotesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({checklistItemsRefs = false, remindersRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (checklistItemsRefs) db.checklistItems,
                    if (remindersRefs) db.reminders,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (checklistItemsRefs)
                        await $_getPrefetchedData<
                          Note,
                          $NotesTable,
                          ChecklistItem
                        >(
                          currentTable: table,
                          referencedTable: $$NotesTableReferences
                              ._checklistItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NotesTableReferences(
                                db,
                                table,
                                p0,
                              ).checklistItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.noteId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (remindersRefs)
                        await $_getPrefetchedData<Note, $NotesTable, Reminder>(
                          currentTable: table,
                          referencedTable: $$NotesTableReferences
                              ._remindersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NotesTableReferences(
                                db,
                                table,
                                p0,
                              ).remindersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.noteId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, $$NotesTableReferences),
      Note,
      PrefetchHooks Function({bool checklistItemsRefs, bool remindersRefs})
    >;
typedef $$ChecklistItemsTableCreateCompanionBuilder =
    ChecklistItemsCompanion Function({
      required String id,
      required String noteId,
      required String content,
      Value<bool> isDone,
      required int sortOrder,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ChecklistItemsTableUpdateCompanionBuilder =
    ChecklistItemsCompanion Function({
      Value<String> id,
      Value<String> noteId,
      Value<String> content,
      Value<bool> isDone,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ChecklistItemsTableReferences
    extends
        BaseReferences<_$LocalDatabase, $ChecklistItemsTable, ChecklistItem> {
  $$ChecklistItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $NotesTable _noteIdTable(_$LocalDatabase db) =>
      db.notes.createAlias('checklist_items__note_id__notes__id');

  $$NotesTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<String>('note_id')!;

    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ChecklistItemsTableFilterComposer
    extends Composer<_$LocalDatabase, $ChecklistItemsTable> {
  $$ChecklistItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$NotesTableFilterComposer get noteId {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChecklistItemsTableOrderingComposer
    extends Composer<_$LocalDatabase, $ChecklistItemsTable> {
  $$ChecklistItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$NotesTableOrderingComposer get noteId {
    final $$NotesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableOrderingComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChecklistItemsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $ChecklistItemsTable> {
  $$ChecklistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<bool> get isDone =>
      $composableBuilder(column: $table.isDone, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$NotesTableAnnotationComposer get noteId {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChecklistItemsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $ChecklistItemsTable,
          ChecklistItem,
          $$ChecklistItemsTableFilterComposer,
          $$ChecklistItemsTableOrderingComposer,
          $$ChecklistItemsTableAnnotationComposer,
          $$ChecklistItemsTableCreateCompanionBuilder,
          $$ChecklistItemsTableUpdateCompanionBuilder,
          (ChecklistItem, $$ChecklistItemsTableReferences),
          ChecklistItem,
          PrefetchHooks Function({bool noteId})
        > {
  $$ChecklistItemsTableTableManager(
    _$LocalDatabase db,
    $ChecklistItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChecklistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChecklistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChecklistItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<bool> isDone = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChecklistItemsCompanion(
                id: id,
                noteId: noteId,
                content: content,
                isDone: isDone,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String noteId,
                required String content,
                Value<bool> isDone = const Value.absent(),
                required int sortOrder,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ChecklistItemsCompanion.insert(
                id: id,
                noteId: noteId,
                content: content,
                isDone: isDone,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ChecklistItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (noteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.noteId,
                                referencedTable: $$ChecklistItemsTableReferences
                                    ._noteIdTable(db),
                                referencedColumn:
                                    $$ChecklistItemsTableReferences
                                        ._noteIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ChecklistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $ChecklistItemsTable,
      ChecklistItem,
      $$ChecklistItemsTableFilterComposer,
      $$ChecklistItemsTableOrderingComposer,
      $$ChecklistItemsTableAnnotationComposer,
      $$ChecklistItemsTableCreateCompanionBuilder,
      $$ChecklistItemsTableUpdateCompanionBuilder,
      (ChecklistItem, $$ChecklistItemsTableReferences),
      ChecklistItem,
      PrefetchHooks Function({bool noteId})
    >;
typedef $$RemindersTableCreateCompanionBuilder =
    RemindersCompanion Function({
      required String id,
      required String noteId,
      required DateTime nextFireAt,
      required String timezone,
      Value<String> recurrenceKind,
      Value<String?> recurrenceJson,
      Value<DateTime?> snoozeUntil,
      Value<DateTime?> endsAt,
      Value<bool> isEnabled,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$RemindersTableUpdateCompanionBuilder =
    RemindersCompanion Function({
      Value<String> id,
      Value<String> noteId,
      Value<DateTime> nextFireAt,
      Value<String> timezone,
      Value<String> recurrenceKind,
      Value<String?> recurrenceJson,
      Value<DateTime?> snoozeUntil,
      Value<DateTime?> endsAt,
      Value<bool> isEnabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$RemindersTableReferences
    extends BaseReferences<_$LocalDatabase, $RemindersTable, Reminder> {
  $$RemindersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NotesTable _noteIdTable(_$LocalDatabase db) =>
      db.notes.createAlias('reminders__note_id__notes__id');

  $$NotesTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<String>('note_id')!;

    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $ReminderOccurrencesTable,
    List<ReminderOccurrence>
  >
  _reminderOccurrencesRefsTable(_$LocalDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.reminderOccurrences,
        aliasName: 'reminders__id__reminder_occurrences__reminder_id',
      );

  $$ReminderOccurrencesTableProcessedTableManager get reminderOccurrencesRefs {
    final manager = $$ReminderOccurrencesTableTableManager(
      $_db,
      $_db.reminderOccurrences,
    ).filter((f) => f.reminderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _reminderOccurrencesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RemindersTableFilterComposer
    extends Composer<_$LocalDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextFireAt => $composableBuilder(
    column: $table.nextFireAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceKind => $composableBuilder(
    column: $table.recurrenceKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceJson => $composableBuilder(
    column: $table.recurrenceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get snoozeUntil => $composableBuilder(
    column: $table.snoozeUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$NotesTableFilterComposer get noteId {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> reminderOccurrencesRefs(
    Expression<bool> Function($$ReminderOccurrencesTableFilterComposer f) f,
  ) {
    final $$ReminderOccurrencesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminderOccurrences,
      getReferencedColumn: (t) => t.reminderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReminderOccurrencesTableFilterComposer(
            $db: $db,
            $table: $db.reminderOccurrences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RemindersTableOrderingComposer
    extends Composer<_$LocalDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextFireAt => $composableBuilder(
    column: $table.nextFireAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceKind => $composableBuilder(
    column: $table.recurrenceKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceJson => $composableBuilder(
    column: $table.recurrenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get snoozeUntil => $composableBuilder(
    column: $table.snoozeUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$NotesTableOrderingComposer get noteId {
    final $$NotesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableOrderingComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$LocalDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get nextFireAt => $composableBuilder(
    column: $table.nextFireAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timezone =>
      $composableBuilder(column: $table.timezone, builder: (column) => column);

  GeneratedColumn<String> get recurrenceKind => $composableBuilder(
    column: $table.recurrenceKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceJson => $composableBuilder(
    column: $table.recurrenceJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get snoozeUntil => $composableBuilder(
    column: $table.snoozeUntil,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get endsAt =>
      $composableBuilder(column: $table.endsAt, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$NotesTableAnnotationComposer get noteId {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> reminderOccurrencesRefs<T extends Object>(
    Expression<T> Function($$ReminderOccurrencesTableAnnotationComposer a) f,
  ) {
    final $$ReminderOccurrencesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.reminderOccurrences,
          getReferencedColumn: (t) => t.reminderId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ReminderOccurrencesTableAnnotationComposer(
                $db: $db,
                $table: $db.reminderOccurrences,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $RemindersTable,
          Reminder,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (Reminder, $$RemindersTableReferences),
          Reminder,
          PrefetchHooks Function({bool noteId, bool reminderOccurrencesRefs})
        > {
  $$RemindersTableTableManager(_$LocalDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<DateTime> nextFireAt = const Value.absent(),
                Value<String> timezone = const Value.absent(),
                Value<String> recurrenceKind = const Value.absent(),
                Value<String?> recurrenceJson = const Value.absent(),
                Value<DateTime?> snoozeUntil = const Value.absent(),
                Value<DateTime?> endsAt = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                noteId: noteId,
                nextFireAt: nextFireAt,
                timezone: timezone,
                recurrenceKind: recurrenceKind,
                recurrenceJson: recurrenceJson,
                snoozeUntil: snoozeUntil,
                endsAt: endsAt,
                isEnabled: isEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String noteId,
                required DateTime nextFireAt,
                required String timezone,
                Value<String> recurrenceKind = const Value.absent(),
                Value<String?> recurrenceJson = const Value.absent(),
                Value<DateTime?> snoozeUntil = const Value.absent(),
                Value<DateTime?> endsAt = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion.insert(
                id: id,
                noteId: noteId,
                nextFireAt: nextFireAt,
                timezone: timezone,
                recurrenceKind: recurrenceKind,
                recurrenceJson: recurrenceJson,
                snoozeUntil: snoozeUntil,
                endsAt: endsAt,
                isEnabled: isEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RemindersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({noteId = false, reminderOccurrencesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (reminderOccurrencesRefs) db.reminderOccurrences,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (noteId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.noteId,
                                    referencedTable: $$RemindersTableReferences
                                        ._noteIdTable(db),
                                    referencedColumn: $$RemindersTableReferences
                                        ._noteIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (reminderOccurrencesRefs)
                        await $_getPrefetchedData<
                          Reminder,
                          $RemindersTable,
                          ReminderOccurrence
                        >(
                          currentTable: table,
                          referencedTable: $$RemindersTableReferences
                              ._reminderOccurrencesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RemindersTableReferences(
                                db,
                                table,
                                p0,
                              ).reminderOccurrencesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.reminderId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $RemindersTable,
      Reminder,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (Reminder, $$RemindersTableReferences),
      Reminder,
      PrefetchHooks Function({bool noteId, bool reminderOccurrencesRefs})
    >;
typedef $$ReminderOccurrencesTableCreateCompanionBuilder =
    ReminderOccurrencesCompanion Function({
      required String id,
      required String reminderId,
      required DateTime scheduledFor,
      required String status,
      Value<DateTime?> actedAt,
      Value<DateTime?> snoozedUntil,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ReminderOccurrencesTableUpdateCompanionBuilder =
    ReminderOccurrencesCompanion Function({
      Value<String> id,
      Value<String> reminderId,
      Value<DateTime> scheduledFor,
      Value<String> status,
      Value<DateTime?> actedAt,
      Value<DateTime?> snoozedUntil,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ReminderOccurrencesTableReferences
    extends
        BaseReferences<
          _$LocalDatabase,
          $ReminderOccurrencesTable,
          ReminderOccurrence
        > {
  $$ReminderOccurrencesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RemindersTable _reminderIdTable(_$LocalDatabase db) => db.reminders
      .createAlias('reminder_occurrences__reminder_id__reminders__id');

  $$RemindersTableProcessedTableManager get reminderId {
    final $_column = $_itemColumn<String>('reminder_id')!;

    final manager = $$RemindersTableTableManager(
      $_db,
      $_db.reminders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_reminderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReminderOccurrencesTableFilterComposer
    extends Composer<_$LocalDatabase, $ReminderOccurrencesTable> {
  $$ReminderOccurrencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get actedAt => $composableBuilder(
    column: $table.actedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$RemindersTableFilterComposer get reminderId {
    final $$RemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reminderId,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableFilterComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReminderOccurrencesTableOrderingComposer
    extends Composer<_$LocalDatabase, $ReminderOccurrencesTable> {
  $$ReminderOccurrencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get actedAt => $composableBuilder(
    column: $table.actedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RemindersTableOrderingComposer get reminderId {
    final $$RemindersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reminderId,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableOrderingComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReminderOccurrencesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $ReminderOccurrencesTable> {
  $$ReminderOccurrencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get actedAt =>
      $composableBuilder(column: $table.actedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$RemindersTableAnnotationComposer get reminderId {
    final $$RemindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reminderId,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableAnnotationComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReminderOccurrencesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $ReminderOccurrencesTable,
          ReminderOccurrence,
          $$ReminderOccurrencesTableFilterComposer,
          $$ReminderOccurrencesTableOrderingComposer,
          $$ReminderOccurrencesTableAnnotationComposer,
          $$ReminderOccurrencesTableCreateCompanionBuilder,
          $$ReminderOccurrencesTableUpdateCompanionBuilder,
          (ReminderOccurrence, $$ReminderOccurrencesTableReferences),
          ReminderOccurrence,
          PrefetchHooks Function({bool reminderId})
        > {
  $$ReminderOccurrencesTableTableManager(
    _$LocalDatabase db,
    $ReminderOccurrencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReminderOccurrencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReminderOccurrencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ReminderOccurrencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> reminderId = const Value.absent(),
                Value<DateTime> scheduledFor = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> actedAt = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReminderOccurrencesCompanion(
                id: id,
                reminderId: reminderId,
                scheduledFor: scheduledFor,
                status: status,
                actedAt: actedAt,
                snoozedUntil: snoozedUntil,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String reminderId,
                required DateTime scheduledFor,
                required String status,
                Value<DateTime?> actedAt = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ReminderOccurrencesCompanion.insert(
                id: id,
                reminderId: reminderId,
                scheduledFor: scheduledFor,
                status: status,
                actedAt: actedAt,
                snoozedUntil: snoozedUntil,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReminderOccurrencesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({reminderId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (reminderId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.reminderId,
                                referencedTable:
                                    $$ReminderOccurrencesTableReferences
                                        ._reminderIdTable(db),
                                referencedColumn:
                                    $$ReminderOccurrencesTableReferences
                                        ._reminderIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReminderOccurrencesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $ReminderOccurrencesTable,
      ReminderOccurrence,
      $$ReminderOccurrencesTableFilterComposer,
      $$ReminderOccurrencesTableOrderingComposer,
      $$ReminderOccurrencesTableAnnotationComposer,
      $$ReminderOccurrencesTableCreateCompanionBuilder,
      $$ReminderOccurrencesTableUpdateCompanionBuilder,
      (ReminderOccurrence, $$ReminderOccurrencesTableReferences),
      ReminderOccurrence,
      PrefetchHooks Function({bool reminderId})
    >;
typedef $$SyncRecordsTableCreateCompanionBuilder =
    SyncRecordsCompanion Function({
      required String id,
      required String recordType,
      required String encryptedPayload,
      Value<int> payloadVersion,
      required int clientRevision,
      Value<int?> serverRevision,
      Value<bool> hasLocalChanges,
      Value<bool> hasConflict,
      Value<String?> conflictOfRecordId,
      Value<DateTime?> deletedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SyncRecordsTableUpdateCompanionBuilder =
    SyncRecordsCompanion Function({
      Value<String> id,
      Value<String> recordType,
      Value<String> encryptedPayload,
      Value<int> payloadVersion,
      Value<int> clientRevision,
      Value<int?> serverRevision,
      Value<bool> hasLocalChanges,
      Value<bool> hasConflict,
      Value<String?> conflictOfRecordId,
      Value<DateTime?> deletedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SyncRecordsTableFilterComposer
    extends Composer<_$LocalDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get payloadVersion => $composableBuilder(
    column: $table.payloadVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clientRevision => $composableBuilder(
    column: $table.clientRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasLocalChanges => $composableBuilder(
    column: $table.hasLocalChanges,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasConflict => $composableBuilder(
    column: $table.hasConflict,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictOfRecordId => $composableBuilder(
    column: $table.conflictOfRecordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncRecordsTableOrderingComposer
    extends Composer<_$LocalDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get payloadVersion => $composableBuilder(
    column: $table.payloadVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clientRevision => $composableBuilder(
    column: $table.clientRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasLocalChanges => $composableBuilder(
    column: $table.hasLocalChanges,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasConflict => $composableBuilder(
    column: $table.hasConflict,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictOfRecordId => $composableBuilder(
    column: $table.conflictOfRecordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncRecordsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => column,
  );

  GeneratedColumn<int> get payloadVersion => $composableBuilder(
    column: $table.payloadVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get clientRevision => $composableBuilder(
    column: $table.clientRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasLocalChanges => $composableBuilder(
    column: $table.hasLocalChanges,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasConflict => $composableBuilder(
    column: $table.hasConflict,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conflictOfRecordId => $composableBuilder(
    column: $table.conflictOfRecordId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncRecordsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $SyncRecordsTable,
          SyncRecord,
          $$SyncRecordsTableFilterComposer,
          $$SyncRecordsTableOrderingComposer,
          $$SyncRecordsTableAnnotationComposer,
          $$SyncRecordsTableCreateCompanionBuilder,
          $$SyncRecordsTableUpdateCompanionBuilder,
          (
            SyncRecord,
            BaseReferences<_$LocalDatabase, $SyncRecordsTable, SyncRecord>,
          ),
          SyncRecord,
          PrefetchHooks Function()
        > {
  $$SyncRecordsTableTableManager(_$LocalDatabase db, $SyncRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> recordType = const Value.absent(),
                Value<String> encryptedPayload = const Value.absent(),
                Value<int> payloadVersion = const Value.absent(),
                Value<int> clientRevision = const Value.absent(),
                Value<int?> serverRevision = const Value.absent(),
                Value<bool> hasLocalChanges = const Value.absent(),
                Value<bool> hasConflict = const Value.absent(),
                Value<String?> conflictOfRecordId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncRecordsCompanion(
                id: id,
                recordType: recordType,
                encryptedPayload: encryptedPayload,
                payloadVersion: payloadVersion,
                clientRevision: clientRevision,
                serverRevision: serverRevision,
                hasLocalChanges: hasLocalChanges,
                hasConflict: hasConflict,
                conflictOfRecordId: conflictOfRecordId,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String recordType,
                required String encryptedPayload,
                Value<int> payloadVersion = const Value.absent(),
                required int clientRevision,
                Value<int?> serverRevision = const Value.absent(),
                Value<bool> hasLocalChanges = const Value.absent(),
                Value<bool> hasConflict = const Value.absent(),
                Value<String?> conflictOfRecordId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncRecordsCompanion.insert(
                id: id,
                recordType: recordType,
                encryptedPayload: encryptedPayload,
                payloadVersion: payloadVersion,
                clientRevision: clientRevision,
                serverRevision: serverRevision,
                hasLocalChanges: hasLocalChanges,
                hasConflict: hasConflict,
                conflictOfRecordId: conflictOfRecordId,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $SyncRecordsTable,
      SyncRecord,
      $$SyncRecordsTableFilterComposer,
      $$SyncRecordsTableOrderingComposer,
      $$SyncRecordsTableAnnotationComposer,
      $$SyncRecordsTableCreateCompanionBuilder,
      $$SyncRecordsTableUpdateCompanionBuilder,
      (
        SyncRecord,
        BaseReferences<_$LocalDatabase, $SyncRecordsTable, SyncRecord>,
      ),
      SyncRecord,
      PrefetchHooks Function()
    >;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$ChecklistItemsTableTableManager get checklistItems =>
      $$ChecklistItemsTableTableManager(_db, _db.checklistItems);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$ReminderOccurrencesTableTableManager get reminderOccurrences =>
      $$ReminderOccurrencesTableTableManager(_db, _db.reminderOccurrences);
  $$SyncRecordsTableTableManager get syncRecords =>
      $$SyncRecordsTableTableManager(_db, _db.syncRecords);
}
