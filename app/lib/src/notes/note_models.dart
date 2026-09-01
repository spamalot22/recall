import 'package:flutter/material.dart';

class NotePreview {
  const NotePreview({
    required this.id,
    required this.title,
    required this.body,
    required this.mood,
    required this.reminderLabel,
    this.checklistItems = const [],
    this.pinned = false,
    this.archived = false,
    this.recurring = false,
    this.reminderAt,
  });

  final String id;
  final String title;
  final String body;
  final ColorMood mood;
  final String reminderLabel;
  final List<ChecklistItemPreview> checklistItems;
  final bool pinned;
  final bool archived;
  final bool recurring;
  final DateTime? reminderAt;

  int get completedChecklistItems =>
      checklistItems.where((item) => item.done).length;
}

class NoteEditorSnapshot {
  const NoteEditorSnapshot({
    required this.id,
    required this.title,
    required this.body,
    required this.mood,
    required this.moodIsAutomatic,
    required this.pinned,
    this.checklistItems = const [],
    this.reminder,
  });

  final String id;
  final String title;
  final String body;
  final ColorMood mood;
  final bool moodIsAutomatic;
  final bool pinned;
  final List<ChecklistItemDraft> checklistItems;
  final NoteReminder? reminder;
}

class NoteReminder {
  const NoteReminder({
    required this.nextFireAt,
    required this.recurrence,
    this.recurrenceInterval = 1,
    this.snoozeUntil,
  }) : assert(recurrenceInterval >= 1 && recurrenceInterval <= 999);

  final DateTime nextFireAt;
  final ReminderRecurrence recurrence;
  final int recurrenceInterval;
  final DateTime? snoozeUntil;

  bool get repeats => recurrence != ReminderRecurrence.none;

  DateTime? nextOccurrenceAfter(DateTime after) {
    return reminderOccurrencesAfter(this, after: after, count: 1).firstOrNull;
  }
}

class ScheduledNoteReminder {
  const ScheduledNoteReminder({
    required this.noteId,
    required this.title,
    required this.body,
    required this.reminder,
  });

  final String noteId;
  final String title;
  final String body;
  final NoteReminder reminder;
}

enum ReminderRecurrence {
  none,
  daily,
  weekly,
  monthly,
  yearly;

  String get label {
    return switch (this) {
      ReminderRecurrence.none => 'Once',
      ReminderRecurrence.daily => 'Daily',
      ReminderRecurrence.weekly => 'Weekly',
      ReminderRecurrence.monthly => 'Monthly',
      ReminderRecurrence.yearly => 'Yearly',
    };
  }

  String unitLabel(int interval) {
    final plural = interval != 1;
    return switch (this) {
      ReminderRecurrence.none => 'time',
      ReminderRecurrence.daily => plural ? 'days' : 'day',
      ReminderRecurrence.weekly => plural ? 'weeks' : 'week',
      ReminderRecurrence.monthly => plural ? 'months' : 'month',
      ReminderRecurrence.yearly => plural ? 'years' : 'year',
    };
  }

  String intervalLabel(int interval) {
    if (this == ReminderRecurrence.none) {
      return 'Once';
    }
    if (interval == 1) {
      return label;
    }
    return 'Every $interval ${unitLabel(interval)}';
  }

  static ReminderRecurrence fromName(String name) {
    return ReminderRecurrence.values.firstWhere(
      (recurrence) => recurrence.name == name,
      orElse: () => ReminderRecurrence.none,
    );
  }
}

List<DateTime> reminderOccurrencesAfter(
  NoteReminder reminder, {
  required DateTime after,
  required int count,
}) {
  if (count <= 0) {
    return const [];
  }
  if (!reminder.repeats) {
    return reminder.nextFireAt.isAfter(after)
        ? [reminder.nextFireAt]
        : const [];
  }

  final firstIndex = _firstReminderOccurrenceIndex(reminder, after);
  return [
    for (var offset = 0; offset < count; offset++)
      _reminderOccurrenceAt(reminder, firstIndex + offset),
  ];
}

int _firstReminderOccurrenceIndex(NoteReminder reminder, DateTime after) {
  final anchor = reminder.nextFireAt;
  if (anchor.isAfter(after)) {
    return 0;
  }

  final interval = reminder.recurrenceInterval;
  var index = switch (reminder.recurrence) {
    ReminderRecurrence.none => 0,
    ReminderRecurrence.daily =>
      _calendarDayDifference(anchor, after) ~/ interval,
    ReminderRecurrence.weekly =>
      _calendarDayDifference(anchor, after) ~/ (interval * 7),
    ReminderRecurrence.monthly => _monthDifference(anchor, after) ~/ interval,
    ReminderRecurrence.yearly => (after.year - anchor.year) ~/ interval,
  };
  if (index < 0) {
    index = 0;
  }
  while (!_reminderOccurrenceAt(reminder, index).isAfter(after)) {
    index++;
  }
  return index;
}

DateTime _reminderOccurrenceAt(NoteReminder reminder, int index) {
  final anchor = reminder.nextFireAt;
  final interval = reminder.recurrenceInterval;
  return switch (reminder.recurrence) {
    ReminderRecurrence.none => anchor,
    ReminderRecurrence.daily => _dateTimeLike(
      anchor,
      anchor.year,
      anchor.month,
      anchor.day + (index * interval),
    ),
    ReminderRecurrence.weekly => _dateTimeLike(
      anchor,
      anchor.year,
      anchor.month,
      anchor.day + (index * interval * 7),
    ),
    ReminderRecurrence.monthly => _monthlyOccurrence(anchor, index * interval),
    ReminderRecurrence.yearly => _yearlyOccurrence(anchor, index * interval),
  };
}

DateTime _monthlyOccurrence(DateTime anchor, int monthOffset) {
  final zeroBasedMonth = anchor.month - 1 + monthOffset;
  final year = anchor.year + zeroBasedMonth ~/ 12;
  final month = zeroBasedMonth % 12 + 1;
  final day = anchor.day.clamp(1, _daysInMonth(year, month)).toInt();
  return _dateTimeLike(anchor, year, month, day);
}

DateTime _yearlyOccurrence(DateTime anchor, int yearOffset) {
  final year = anchor.year + yearOffset;
  final day = anchor.day.clamp(1, _daysInMonth(year, anchor.month)).toInt();
  return _dateTimeLike(anchor, year, anchor.month, day);
}

DateTime _dateTimeLike(DateTime anchor, int year, int month, int day) {
  if (anchor.isUtc) {
    return DateTime.utc(
      year,
      month,
      day,
      anchor.hour,
      anchor.minute,
      anchor.second,
      anchor.millisecond,
      anchor.microsecond,
    );
  }
  return DateTime(
    year,
    month,
    day,
    anchor.hour,
    anchor.minute,
    anchor.second,
    anchor.millisecond,
    anchor.microsecond,
  );
}

int _calendarDayDifference(DateTime start, DateTime end) {
  final startDay = DateTime.utc(start.year, start.month, start.day);
  final endDay = DateTime.utc(end.year, end.month, end.day);
  return endDay.difference(startDay).inDays;
}

int _monthDifference(DateTime start, DateTime end) {
  return (end.year - start.year) * 12 + end.month - start.month;
}

int _daysInMonth(int year, int month) {
  return DateTime.utc(year, month + 1, 0).day;
}

class ChecklistItemPreview {
  const ChecklistItemPreview(this.text, {this.done = false});

  final String text;
  final bool done;
}

class ChecklistItemDraft {
  const ChecklistItemDraft({required this.text, this.done = false});

  final String text;
  final bool done;
}

class MoodColors {
  const MoodColors({
    required this.background,
    required this.foreground,
    required this.accent,
    required this.outline,
  });

  final Color background;
  final Color foreground;
  final Color accent;
  final Color outline;
}

enum ColorMood {
  clear,
  focus,
  urgent,
  routine,
  errand,
  joyful,
  warm,
  calm,
  reflective,
  tense,
  intense,
  surprised;

  MoodColors resolve(ColorScheme scheme) {
    return switch (this) {
      ColorMood.clear => MoodColors(
        background: scheme.surfaceContainerHigh,
        foreground: scheme.onSurface,
        accent: scheme.primary,
        outline: scheme.outlineVariant,
      ),
      ColorMood.focus => _seededMood(scheme, const Color(0xFF4055B5)),
      ColorMood.urgent => _seededMood(scheme, const Color(0xFFBA1A1A)),
      ColorMood.routine => _seededMood(scheme, const Color(0xFF24745C)),
      ColorMood.errand => _seededMood(scheme, const Color(0xFF9A5D00)),
      ColorMood.joyful => _seededMood(scheme, const Color(0xFFB56B00)),
      ColorMood.warm => _seededMood(scheme, const Color(0xFFA53F68)),
      ColorMood.calm => _seededMood(scheme, const Color(0xFF007C91)),
      ColorMood.reflective => _seededMood(scheme, const Color(0xFF32658F)),
      ColorMood.tense => _seededMood(scheme, const Color(0xFF74558D)),
      ColorMood.intense => _seededMood(scheme, const Color(0xFFC33D18)),
      ColorMood.surprised => _seededMood(scheme, const Color(0xFF008577)),
    };
  }

  static ColorMood fromName(String name) {
    return ColorMood.values.firstWhere(
      (mood) => mood.name == name,
      orElse: () => ColorMood.clear,
    );
  }
}

MoodColors _seededMood(ColorScheme appScheme, Color seed) {
  final palette = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: appScheme.brightness,
    contrastLevel: 0.15,
  );
  return MoodColors(
    background: palette.primaryContainer,
    foreground: palette.onPrimaryContainer,
    accent: palette.primary,
    outline: palette.primary.withValues(alpha: 0.38),
  );
}

ColorMood automaticMoodForNote({
  required String title,
  required String body,
  Iterable<String> checklistItems = const [],
  NoteReminder? reminder,
  DateTime? now,
}) {
  final scores = <ColorMood, double>{
    for (final mood in ColorMood.values)
      if (mood != ColorMood.clear) mood: 0,
  };
  var explicitUrgency = false;
  var imminentReminder = false;

  void scoreText(String source, double multiplier) {
    final text = source.trim().toLowerCase();
    if (text.isEmpty) {
      return;
    }
    var urgencyText = text;
    for (final negation in _urgencyNegations) {
      if (negation.hasMatch(urgencyText)) {
        scores[ColorMood.urgent] = scores[ColorMood.urgent]! - 2.5 * multiplier;
        urgencyText = urgencyText.replaceAll(negation, ' ');
      }
    }
    explicitUrgency = explicitUrgency || _explicitUrgency.hasMatch(urgencyText);
    for (final rule in _moodRules) {
      final candidate = rule.mood == ColorMood.urgent ? urgencyText : text;
      final matches = rule.pattern
          .allMatches(candidate)
          .length
          .clamp(0, 3)
          .toInt();
      scores[rule.mood] =
          scores[rule.mood]! + (matches * rule.weight * multiplier);
    }
    if (text.contains('http://') || text.contains('https://')) {
      scores[ColorMood.focus] = scores[ColorMood.focus]! + 1.25 * multiplier;
    }
  }

  scoreText(title, 1.7);
  scoreText(body, 1);
  for (final item in checklistItems) {
    scoreText(item, 1.15);
  }

  if (reminder?.repeats ?? false) {
    scores[ColorMood.routine] = scores[ColorMood.routine]! + 4;
  }
  final reminderAt = reminder?.snoozeUntil ?? reminder?.nextFireAt;
  if (reminderAt != null) {
    final until = reminderAt.difference(now ?? DateTime.now());
    imminentReminder = until <= const Duration(hours: 6);
    final urgency = until.isNegative
        ? 7.0
        : until <= const Duration(hours: 6)
        ? 6.0
        : until <= const Duration(days: 1)
        ? 4.0
        : until <= const Duration(days: 3)
        ? 1.5
        : 0.0;
    scores[ColorMood.urgent] = scores[ColorMood.urgent]! + urgency;
  }

  if (explicitUrgency || imminentReminder) {
    return ColorMood.urgent;
  }

  final ranked = scores.entries.toList()
    ..sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      return byScore != 0
          ? byScore
          : _moodTieBreak
                .indexOf(a.key)
                .compareTo(_moodTieBreak.indexOf(b.key));
    });
  final winner = ranked.first;
  final threshold = winner.key == ColorMood.urgent ? 2.3 : 2.0;
  return winner.value >= threshold ? winner.key : ColorMood.clear;
}

class _MoodRule {
  _MoodRule(this.mood, String pattern, this.weight)
    : pattern = RegExp(pattern, caseSensitive: false);

  final ColorMood mood;
  final RegExp pattern;
  final double weight;
}

final _moodRules = [
  _MoodRule(
    ColorMood.urgent,
    r'\b(?:urgent|asap|overdue|emergency|immediately|critical)\b',
    6,
  ),
  _MoodRule(
    ColorMood.urgent,
    r'\b(?:deadline|due|submit|expires?|expiring|must)\b',
    2.4,
  ),
  _MoodRule(
    ColorMood.urgent,
    r'\b(?:today|tonight|tomorrow|this morning|this afternoon)\b',
    1.2,
  ),
  _MoodRule(
    ColorMood.urgent,
    r"\b(?:don't forget|do not forget|need to)\b",
    1.5,
  ),
  _MoodRule(
    ColorMood.errand,
    r'\b(?:groceries|grocery|shopping|supermarket|shop|store|chemist)\b',
    3,
  ),
  _MoodRule(
    ColorMood.errand,
    r'\b(?:buy|buying|purchase|reorder|return package|exchange)\b',
    2.7,
  ),
  _MoodRule(
    ColorMood.errand,
    r'\b(?:pick up|pickup|collect|drop off|post office|pharmacy)\b',
    2.8,
  ),
  _MoodRule(
    ColorMood.errand,
    r'\b(?:pack|packing|book tickets?|pay bill|invoice|renew)\b',
    2,
  ),
  _MoodRule(
    ColorMood.routine,
    r'\b(?:daily|weekly|monthly|yearly|every day|every week|every month)\b',
    3,
  ),
  _MoodRule(
    ColorMood.routine,
    r'\b(?:routine|habit|recurring|repeat|chores?|maintenance)\b',
    2.8,
  ),
  _MoodRule(
    ColorMood.routine,
    r'\b(?:clean|laundry|dishes|vacuum|water plants?|workout|exercise|medication|medicine|vitamins?)\b',
    2.2,
  ),
  _MoodRule(
    ColorMood.focus,
    r'\b(?:project|research|study|write|writing|read|reading|draft|design|plan|brainstorm)\b',
    2.4,
  ),
  _MoodRule(
    ColorMood.focus,
    r'\b(?:meeting notes?|agenda|reference|idea|review|learn|course|report|proposal|strategy|goals?)\b',
    2,
  ),
];

final _urgencyNegations = [
  RegExp(
    r'\b(?:not urgent|not overdue|not critical|not due|no rush|whenever|someday|eventually)\b',
  ),
  RegExp(r'\b(?:cancelled|canceled|ignore the deadline)\b'),
];

final _explicitUrgency = RegExp(
  r'\b(?:urgent|asap|overdue|emergency|immediately|critical)\b',
);

const _moodTieBreak = [
  ColorMood.urgent,
  ColorMood.errand,
  ColorMood.routine,
  ColorMood.focus,
];

const sampleNotes = [
  NotePreview(
    id: 'sample-monthly-filter-order',
    title: 'Monthly filter order',
    body: 'Check furnace and fridge filter sizes before reordering.',
    mood: ColorMood.routine,
    reminderLabel: 'Repeats monthly',
    recurring: true,
    pinned: true,
  ),
  NotePreview(
    id: 'sample-trip-packing',
    title: 'Trip packing',
    body: '',
    mood: ColorMood.errand,
    reminderLabel: 'Tomorrow 8:00 AM',
    checklistItems: [
      ChecklistItemPreview('Chargers', done: true),
      ChecklistItemPreview('Medication'),
      ChecklistItemPreview('Boarding passes'),
    ],
  ),
];
