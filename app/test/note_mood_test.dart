import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/notes/note_models.dart';

void main() {
  group('automaticMoodForNote', () {
    test('uses focused title language as strong evidence', () {
      expect(
        automaticMoodForNote(
          title: 'Research project plan',
          body: 'Ideas and next steps',
        ),
        ColorMood.focus,
      );
    });

    test('classifies errands from checklist content', () {
      expect(
        automaticMoodForNote(
          title: 'Saturday',
          body: '',
          checklistItems: const ['Buy groceries', 'Pick up prescription'],
        ),
        ColorMood.errand,
      );
    });

    test('does not treat explicitly relaxed notes as urgent', () {
      expect(
        automaticMoodForNote(
          title: 'Not urgent',
          body: 'No rush, finish this someday',
        ),
        ColorMood.clear,
      );
    });

    test('explicit urgency dominates otherwise strong errand cues', () {
      expect(
        automaticMoodForNote(
          title: 'Urgent: buy groceries',
          body: 'Pick up the shopping before closing',
        ),
        ColorMood.urgent,
      );
    });

    test('uses recurrence as routine context', () {
      expect(
        automaticMoodForNote(
          title: 'Check meter',
          body: '',
          reminder: NoteReminder(
            nextFireAt: DateTime(2026, 8, 1, 9),
            recurrence: ReminderRecurrence.monthly,
          ),
          now: DateTime(2026, 7, 10, 9),
        ),
        ColorMood.routine,
      );
    });

    test('uses a near reminder as urgent context', () {
      expect(
        automaticMoodForNote(
          title: 'Call Alex',
          body: '',
          reminder: NoteReminder(
            nextFireAt: DateTime(2026, 7, 10, 12),
            recurrence: ReminderRecurrence.none,
          ),
          now: DateTime(2026, 7, 10, 9),
        ),
        ColorMood.urgent,
      );
    });
  });

  test('moods use accessible Material color scheme role pairs', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.green);

    expect(ColorMood.focus.resolve(scheme).background, scheme.primaryContainer);
    expect(
      ColorMood.focus.resolve(scheme).foreground,
      scheme.onPrimaryContainer,
    );
    expect(
      ColorMood.errand.resolve(scheme).background,
      scheme.secondaryContainer,
    );
    expect(
      ColorMood.routine.resolve(scheme).background,
      scheme.tertiaryContainer,
    );
    expect(ColorMood.urgent.resolve(scheme).background, scheme.errorContainer);
  });
}
