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
    this.snoozeUntil,
  });

  final DateTime nextFireAt;
  final ReminderRecurrence recurrence;
  final DateTime? snoozeUntil;

  bool get repeats => recurrence != ReminderRecurrence.none;
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

  static ReminderRecurrence fromName(String name) {
    return ReminderRecurrence.values.firstWhere(
      (recurrence) => recurrence.name == name,
      orElse: () => ReminderRecurrence.none,
    );
  }
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
  });

  final Color background;
  final Color foreground;
  final Color accent;
}

enum ColorMood {
  clear,
  focus,
  urgent,
  routine,
  errand;

  MoodColors resolve(ColorScheme scheme) {
    return switch (this) {
      ColorMood.clear => MoodColors(
        background: scheme.surfaceContainerLow,
        foreground: scheme.onSurface,
        accent: scheme.primary,
      ),
      ColorMood.focus => MoodColors(
        background: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
        accent: scheme.primary,
      ),
      ColorMood.urgent => MoodColors(
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
        accent: scheme.error,
      ),
      ColorMood.routine => MoodColors(
        background: scheme.tertiaryContainer,
        foreground: scheme.onTertiaryContainer,
        accent: scheme.tertiary,
      ),
      ColorMood.errand => MoodColors(
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
        accent: scheme.secondary,
      ),
    };
  }

  static ColorMood fromName(String name) {
    return ColorMood.values.firstWhere(
      (mood) => mood.name == name,
      orElse: () => ColorMood.clear,
    );
  }
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
  return ranked.first.value >= 2 ? ranked.first.key : ColorMood.clear;
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
    1.8,
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
