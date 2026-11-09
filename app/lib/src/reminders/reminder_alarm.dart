import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../notes/note_models.dart';

class ReminderAlarm {
  const ReminderAlarm(this.noteId, this.at, this.rule);

  final String noteId;
  final DateTime at;
  final String rule;

  String get payload => jsonEncode({
    'note': noteId,
    'at': at.toUtc().millisecondsSinceEpoch,
    'rule': rule,
  });

  static ReminderAlarm? parse(String? payload) {
    if (payload == null || payload.length > 1024) return null;
    try {
      final value = jsonDecode(payload);
      if (value is! Map ||
          value['note'] is! String ||
          value['at'] is! int ||
          value['rule'] is! String) {
        return null;
      }
      final note = value['note'] as String;
      if (note.isEmpty || note.length > 128) return null;
      return ReminderAlarm(
        note,
        DateTime.fromMillisecondsSinceEpoch(value['at'] as int, isUtc: true),
        value['rule'] as String,
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  static String? noteIdFromPayload(String? payload) {
    final alarm = parse(payload);
    if (alarm != null) return alarm.noteId;
    if (payload == null ||
        payload.isEmpty ||
        payload.length > 128 ||
        payload.startsWith('{')) {
      return null;
    }
    return payload;
  }

  static Future<String> fingerprint(
    NoteReminder reminder,
    String title,
    String body,
  ) async {
    final cycle = reminder.cycle;
    final value = jsonEncode([
      reminder.nextFireAt.toUtc().millisecondsSinceEpoch,
      reminder.recurrence.name,
      reminder.recurrenceInterval,
      if (cycle != null)
        [
          cycle.activeDuration.value,
          cycle.activeDuration.unit.name,
          cycle.restDuration.value,
          cycle.restDuration.unit.name,
          cycle.anchorAt?.toUtc().millisecondsSinceEpoch,
          cycle.endAt?.toUtc().millisecondsSinceEpoch,
          cycle.maxCycles,
        ],
      title,
      body,
    ]);
    return base64UrlEncode((await Sha256().hash(utf8.encode(value))).bytes);
  }
}
