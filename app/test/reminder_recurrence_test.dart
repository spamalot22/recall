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
}
