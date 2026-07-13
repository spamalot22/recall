import 'package:flutter/material.dart';

enum ReminderTimePeriod { morning, afternoon, evening }

@immutable
class ReminderTimePreset {
  const ReminderTimePreset({
    required this.period,
    required this.label,
    required this.time,
  });

  final ReminderTimePeriod period;
  final String label;
  final TimeOfDay time;
}

const reminderTimePresets = <ReminderTimePreset>[
  ReminderTimePreset(
    period: ReminderTimePeriod.morning,
    label: 'Morning',
    time: TimeOfDay(hour: 9, minute: 0),
  ),
  ReminderTimePreset(
    period: ReminderTimePeriod.afternoon,
    label: 'Afternoon',
    time: TimeOfDay(hour: 13, minute: 0),
  ),
  ReminderTimePreset(
    period: ReminderTimePeriod.evening,
    label: 'Evening',
    time: TimeOfDay(hour: 18, minute: 0),
  ),
];

DateTime reminderDateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime combineReminderDateAndTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

bool isSameReminderDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

bool isSameReminderTime(TimeOfDay first, TimeOfDay second) {
  return first.hour == second.hour && first.minute == second.minute;
}

List<ReminderTimePreset> availableReminderTimePresets({
  required DateTime selectedDate,
  required DateTime now,
}) {
  final selectedDay = reminderDateOnly(selectedDate);
  final today = reminderDateOnly(now);
  if (selectedDay.isBefore(today)) {
    return const [];
  }
  if (selectedDay.isAfter(today)) {
    return reminderTimePresets;
  }

  return reminderTimePresets
      .where(
        (preset) =>
            combineReminderDateAndTime(selectedDay, preset.time).isAfter(now),
      )
      .toList(growable: false);
}

bool canScheduleReminderOnDate(DateTime date, DateTime now) {
  final selectedDay = reminderDateOnly(date);
  final today = reminderDateOnly(now);
  if (selectedDay.isAfter(today)) {
    return true;
  }
  if (selectedDay.isBefore(today)) {
    return false;
  }

  return isSameReminderDate(_nextSelectableMinute(now), selectedDay);
}

TimeOfDay validReminderTimeForDate({
  required DateTime selectedDate,
  required TimeOfDay preferredTime,
  required DateTime now,
}) {
  final preferred = combineReminderDateAndTime(selectedDate, preferredTime);
  if (preferred.isAfter(now)) {
    return preferredTime;
  }

  final presets = availableReminderTimePresets(
    selectedDate: selectedDate,
    now: now,
  );
  if (presets.isNotEmpty) {
    return presets.first.time;
  }

  final nextQuarter = _nextQuarterHour(now);
  if (isSameReminderDate(nextQuarter, selectedDate)) {
    return TimeOfDay.fromDateTime(nextQuarter);
  }
  final nextMinute = _nextSelectableMinute(now);
  if (isSameReminderDate(nextMinute, selectedDate)) {
    return TimeOfDay.fromDateTime(nextMinute);
  }
  return reminderTimePresets.first.time;
}

DateTime defaultReminderDateTime(DateTime now) {
  final today = reminderDateOnly(now);
  final time = validReminderTimeForDate(
    selectedDate: today,
    preferredTime: reminderTimePresets.first.time,
    now: now,
  );
  final todayAtTime = combineReminderDateAndTime(today, time);
  if (todayAtTime.isAfter(now)) {
    return todayAtTime;
  }

  return combineReminderDateAndTime(
    today.add(const Duration(days: 1)),
    reminderTimePresets.first.time,
  );
}

DateTime _nextQuarterHour(DateTime now) {
  final nextQuarterMinute = ((now.minute ~/ 15) + 1) * 15;
  return DateTime(now.year, now.month, now.day, now.hour, nextQuarterMinute);
}

DateTime _nextSelectableMinute(DateTime now) {
  return DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
}
