import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/notes/note_models.dart';

void main() {
  test('calculates an anchored every-two-days schedule', () {
    final reminder = NoteReminder(
      nextFireAt: DateTime.utc(2026, 1, 10, 22),
      recurrence: ReminderRecurrence.daily,
      recurrenceInterval: 2,
    );

    expect(
      reminderOccurrencesAfter(
        reminder,
        after: DateTime.utc(2026, 1, 11),
        count: 3,
      ),
      [
        DateTime.utc(2026, 1, 12, 22),
        DateTime.utc(2026, 1, 14, 22),
        DateTime.utc(2026, 1, 16, 22),
      ],
    );
  });

  test('calculates an anchored every-three-weeks schedule', () {
    final reminder = NoteReminder(
      nextFireAt: DateTime.utc(2026, 1, 5, 9, 30),
      recurrence: ReminderRecurrence.weekly,
      recurrenceInterval: 3,
    );

    expect(
      reminderOccurrencesAfter(
        reminder,
        after: DateTime.utc(2026, 1, 5, 9, 30),
        count: 2,
      ),
      [DateTime.utc(2026, 1, 26, 9, 30), DateTime.utc(2026, 2, 16, 9, 30)],
    );
  });

  test('monthly schedules use the last day of shorter months', () {
    final reminder = NoteReminder(
      nextFireAt: DateTime.utc(2027, 1, 31, 22),
      recurrence: ReminderRecurrence.monthly,
    );

    expect(
      reminderOccurrencesAfter(
        reminder,
        after: DateTime.utc(2027, 1, 31, 22),
        count: 3,
      ),
      [
        DateTime.utc(2027, 2, 28, 22),
        DateTime.utc(2027, 3, 31, 22),
        DateTime.utc(2027, 4, 30, 22),
      ],
    );
  });

  test('multi-month schedules stay anchored to the original day', () {
    final reminder = NoteReminder(
      nextFireAt: DateTime.utc(2026, 8, 31, 18),
      recurrence: ReminderRecurrence.monthly,
      recurrenceInterval: 2,
    );

    expect(
      reminderOccurrencesAfter(
        reminder,
        after: DateTime.utc(2026, 8, 1),
        count: 4,
      ),
      [
        DateTime.utc(2026, 8, 31, 18),
        DateTime.utc(2026, 10, 31, 18),
        DateTime.utc(2026, 12, 31, 18),
        DateTime.utc(2027, 2, 28, 18),
      ],
    );
  });

  test('yearly leap-day schedules use the last day of February', () {
    final reminder = NoteReminder(
      nextFireAt: DateTime.utc(2028, 2, 29, 8),
      recurrence: ReminderRecurrence.yearly,
    );

    expect(
      reminderOccurrencesAfter(
        reminder,
        after: DateTime.utc(2028, 2, 29, 8),
        count: 4,
      ),
      [
        DateTime.utc(2029, 2, 28, 8),
        DateTime.utc(2030, 2, 28, 8),
        DateTime.utc(2031, 2, 28, 8),
        DateTime.utc(2032, 2, 29, 8),
      ],
    );
  });

  test('one-time reminders have no occurrence after firing', () {
    final reminder = NoteReminder(
      nextFireAt: DateTime.utc(2026, 1, 1, 12),
      recurrence: ReminderRecurrence.none,
    );

    expect(
      reminderOccurrencesAfter(
        reminder,
        after: DateTime.utc(2026, 1, 1, 12),
        count: 1,
      ),
      isEmpty,
    );
  });

  test('alerts daily for an active week then skips complete rest weeks', () {
    final reminder = NoteReminder(
      nextFireAt: DateTime.utc(2026, 9, 7, 22),
      recurrence: ReminderRecurrence.daily,
      cycle: const ReminderCycle(
        activeDuration: ReminderDuration(
          value: 1,
          unit: ReminderDurationUnit.weeks,
        ),
        restDuration: ReminderDuration(
          value: 2,
          unit: ReminderDurationUnit.weeks,
        ),
      ),
    );

    expect(
      reminderOccurrencesAfter(
        reminder,
        after: DateTime.utc(2026, 9, 7, 21),
        count: 10,
      ),
      [
        for (var day = 7; day <= 13; day++) DateTime.utc(2026, 9, day, 22),
        DateTime.utc(2026, 9, 28, 22),
        DateTime.utc(2026, 9, 29, 22),
        DateTime.utc(2026, 9, 30, 22),
      ],
    );
  });

  test('uses an earlier cycle anchor without alerting before the start', () {
    final reminder = NoteReminder(
      nextFireAt: DateTime.utc(2026, 9, 4, 22),
      recurrence: ReminderRecurrence.daily,
      cycle: ReminderCycle(
        anchorAt: DateTime.utc(2026, 8, 31, 22),
        activeDuration: const ReminderDuration(
          value: 1,
          unit: ReminderDurationUnit.weeks,
        ),
        restDuration: const ReminderDuration(
          value: 4,
          unit: ReminderDurationUnit.weeks,
        ),
      ),
    );

    expect(
      reminderOccurrencesAfter(
        reminder,
        after: DateTime.utc(2026, 9, 2, 12),
        count: 6,
      ),
      [
        DateTime.utc(2026, 9, 4, 22),
        DateTime.utc(2026, 9, 5, 22),
        DateTime.utc(2026, 9, 6, 22),
        DateTime.utc(2026, 10, 5, 22),
        DateTime.utc(2026, 10, 6, 22),
        DateTime.utc(2026, 10, 7, 22),
      ],
    );
  });

  test('skips directly across old fixed-length cycles', () {
    final recentAnchor = DateTime.utc(2026, 8, 31, 22);
    final reminder = NoteReminder(
      nextFireAt: DateTime.utc(2026, 9, 4, 22),
      recurrence: ReminderRecurrence.daily,
      cycle: ReminderCycle(
        anchorAt: recentAnchor.subtract(const Duration(days: 35 * 1000)),
        activeDuration: const ReminderDuration(
          value: 1,
          unit: ReminderDurationUnit.weeks,
        ),
        restDuration: const ReminderDuration(
          value: 4,
          unit: ReminderDurationUnit.weeks,
        ),
      ),
    );

    final occurrences = reminderOccurrencesAfter(
      reminder,
      after: DateTime.utc(2026, 9, 4, 12),
      count: 3,
    );

    expect(occurrences, [
      DateTime.utc(2026, 9, 4, 22),
      DateTime.utc(2026, 9, 5, 22),
      DateTime.utc(2026, 9, 6, 22),
    ]);
  });

  test('skips directly across old month-based cycles', () {
    final reminder = NoteReminder(
      nextFireAt: DateTime.utc(2000, 1, 31, 10),
      recurrence: ReminderRecurrence.monthly,
      cycle: const ReminderCycle(
        activeDuration: ReminderDuration(
          value: 1,
          unit: ReminderDurationUnit.months,
        ),
        restDuration: ReminderDuration(
          value: 1,
          unit: ReminderDurationUnit.months,
        ),
      ),
    );

    expect(
      reminderOccurrencesAfter(
        reminder,
        after: DateTime.utc(2026, 1, 1),
        count: 2,
      ),
      [DateTime.utc(2026, 1, 31, 10), DateTime.utc(2026, 3, 31, 10)],
    );
  });

  test('frequency restarts at the beginning of each active period', () {
    final reminder = NoteReminder(
      nextFireAt: DateTime.utc(2026, 9, 7, 9),
      recurrence: ReminderRecurrence.daily,
      recurrenceInterval: 2,
      cycle: const ReminderCycle(
        activeDuration: ReminderDuration(
          value: 1,
          unit: ReminderDurationUnit.weeks,
        ),
        restDuration: ReminderDuration(
          value: 2,
          unit: ReminderDurationUnit.weeks,
        ),
      ),
    );

    expect(
      reminderOccurrencesAfter(
        reminder,
        after: DateTime.utc(2026, 9, 7, 8),
        count: 6,
      ),
      [
        DateTime.utc(2026, 9, 7, 9),
        DateTime.utc(2026, 9, 9, 9),
        DateTime.utc(2026, 9, 11, 9),
        DateTime.utc(2026, 9, 13, 9),
        DateTime.utc(2026, 9, 28, 9),
        DateTime.utc(2026, 9, 30, 9),
      ],
    );
  });

  test('cycle count limits the number of active periods', () {
    final reminder = NoteReminder(
      nextFireAt: DateTime.utc(2026, 9, 1, 8),
      recurrence: ReminderRecurrence.daily,
      cycle: const ReminderCycle(
        activeDuration: ReminderDuration(
          value: 2,
          unit: ReminderDurationUnit.days,
        ),
        restDuration: ReminderDuration(
          value: 1,
          unit: ReminderDurationUnit.days,
        ),
        maxCycles: 2,
      ),
    );

    expect(
      reminderOccurrencesAfter(
        reminder,
        after: DateTime.utc(2026, 9, 1, 7),
        count: 10,
      ),
      [
        DateTime.utc(2026, 9, 1, 8),
        DateTime.utc(2026, 9, 2, 8),
        DateTime.utc(2026, 9, 4, 8),
        DateTime.utc(2026, 9, 5, 8),
      ],
    );
  });

  test('cycle end date includes an occurrence at the selected time', () {
    final endAt = DateTime.utc(2026, 9, 4, 8);
    final reminder = NoteReminder(
      nextFireAt: DateTime.utc(2026, 9, 1, 8),
      recurrence: ReminderRecurrence.daily,
      cycle: ReminderCycle(
        activeDuration: const ReminderDuration(
          value: 2,
          unit: ReminderDurationUnit.days,
        ),
        restDuration: const ReminderDuration(
          value: 1,
          unit: ReminderDurationUnit.days,
        ),
        endAt: endAt,
      ),
    );

    expect(
      reminderOccurrencesAfter(
        reminder,
        after: DateTime.utc(2026, 9, 1, 7),
        count: 10,
      ),
      [DateTime.utc(2026, 9, 1, 8), DateTime.utc(2026, 9, 2, 8), endAt],
    );
  });

  test('consecutive monthly cycle periods preserve the intended day', () {
    final reminder = NoteReminder(
      nextFireAt: DateTime.utc(2027, 1, 31, 10),
      recurrence: ReminderRecurrence.monthly,
      cycle: const ReminderCycle(
        activeDuration: ReminderDuration(
          value: 1,
          unit: ReminderDurationUnit.months,
        ),
        restDuration: ReminderDuration(
          value: 1,
          unit: ReminderDurationUnit.months,
        ),
      ),
    );

    expect(
      reminderOccurrencesAfter(
        reminder,
        after: DateTime.utc(2027, 1, 1),
        count: 3,
      ),
      [
        DateTime.utc(2027, 1, 31, 10),
        DateTime.utc(2027, 3, 31, 10),
        DateTime.utc(2027, 5, 31, 10),
      ],
    );
  });
}
