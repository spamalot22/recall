import 'package:flutter/material.dart';

import '../notes/note_models.dart';
import 'reminder_time_options.dart';

class ReminderEditorSelection {
  const ReminderEditorSelection(this.at, this.recurrence);

  final DateTime? at;
  final ReminderRecurrence recurrence;
}

Future<ReminderEditorSelection?> showReminderEditor(
  BuildContext context, {
  required DateTime? initialAt,
  required ReminderRecurrence initialRecurrence,
  DateTime Function()? nowProvider,
}) {
  final currentTime = nowProvider ?? DateTime.now;
  final initialSelection = initialAt ?? defaultReminderDateTime(currentTime());
  var selectedDate = reminderDateOnly(initialSelection);
  var selectedTime = TimeOfDay.fromDateTime(initialSelection);
  var recurrence = initialRecurrence;

  return showModalBottomSheet<ReminderEditorSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final now = currentTime();
        final today = reminderDateOnly(now);
        final tomorrow = today.add(const Duration(days: 1));
        final selectedAt = combineReminderDateAndTime(
          selectedDate,
          selectedTime,
        );
        final availablePresets = availableReminderTimePresets(
          selectedDate: selectedDate,
          now: now,
        );
        final isValid = selectedAt.isAfter(now);
        final theme = Theme.of(sheetContext);
        final localizations = MaterialLocalizations.of(sheetContext);
        final textTheme = theme.textTheme;
        final selectionMotion = MediaQuery.disableAnimationsOf(sheetContext)
            ? Duration.zero
            : const Duration(milliseconds: 180);

        void selectDate(DateTime date) {
          final selectionNow = currentTime();
          setSheetState(() {
            selectedDate = reminderDateOnly(date);
            selectedTime = validReminderTimeForDate(
              selectedDate: selectedDate,
              preferredTime: selectedTime,
              now: selectionNow,
            );
          });
        }

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    initialAt == null ? 'Add reminder' : 'Edit reminder',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('Date', style: textTheme.titleMedium),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          localizations.formatMediumDate(selectedDate),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.today_outlined, size: 18),
                        label: const Text('Today'),
                        selected: isSameReminderDate(selectedDate, today),
                        onSelected: canScheduleReminderOnDate(today, now)
                            ? (_) => selectDate(today)
                            : null,
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.wb_sunny_outlined, size: 18),
                        label: const Text('Tomorrow'),
                        selected: isSameReminderDate(selectedDate, tomorrow),
                        onSelected: (_) => selectDate(tomorrow),
                      ),
                      ActionChip(
                        avatar: const Icon(
                          Icons.edit_calendar_outlined,
                          size: 18,
                        ),
                        label: const Text('Choose date'),
                        onPressed: () async {
                          final custom = await _pickReminderDate(
                            sheetContext,
                            selectedDate,
                            now: currentTime(),
                          );
                          if (custom != null && sheetContext.mounted) {
                            selectDate(custom);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text('Time', style: textTheme.titleMedium),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          localizations.formatTimeOfDay(selectedTime),
                          textAlign: TextAlign.end,
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in availablePresets)
                        ChoiceChip(
                          avatar: Icon(_presetIcon(preset), size: 18),
                          label: Text(
                            '${preset.label} '
                            '(${localizations.formatTimeOfDay(preset.time)})',
                          ),
                          selected: isSameReminderTime(
                            selectedTime,
                            preset.time,
                          ),
                          onSelected: (_) =>
                              setSheetState(() => selectedTime = preset.time),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.schedule_outlined, size: 18),
                        label: const Text('Choose time'),
                        onPressed: () async {
                          final custom = await _pickReminderTime(
                            sheetContext,
                            selectedTime,
                          );
                          if (custom != null && sheetContext.mounted) {
                            setSheetState(() => selectedTime = custom);
                          }
                        },
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: selectionMotion,
                    curve: Curves.easeOutCubic,
                    child: isValid
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 18,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Choose a future time for this reminder.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<ReminderRecurrence>(
                    initialValue: recurrence,
                    decoration: const InputDecoration(
                      labelText: 'Repeat',
                      prefixIcon: Icon(Icons.event_repeat_rounded),
                    ),
                    items: [
                      for (final value in ReminderRecurrence.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => recurrence = value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (initialAt != null)
                        TextButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(
                            const ReminderEditorSelection(
                              null,
                              ReminderRecurrence.none,
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Remove'),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: isValid
                            ? () => Navigator.of(sheetContext).pop(
                                ReminderEditorSelection(selectedAt, recurrence),
                              )
                            : null,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Done'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

Future<DateTime?> _pickReminderDate(
  BuildContext context,
  DateTime initial, {
  required DateTime now,
}) {
  final firstDate = reminderDateOnly(now);
  final lastDate = DateTime(now.year + 10, now.month, now.day);
  final initialDate = initial.isBefore(firstDate)
      ? firstDate
      : initial.isAfter(lastDate)
      ? lastDate
      : initial;
  return showDatePicker(
    context: context,
    helpText: 'Choose reminder date',
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );
}

Future<TimeOfDay?> _pickReminderTime(BuildContext context, TimeOfDay initial) {
  return showTimePicker(
    context: context,
    helpText: 'Choose reminder time',
    initialTime: initial,
  );
}

IconData _presetIcon(ReminderTimePreset preset) {
  return switch (preset.period) {
    ReminderTimePeriod.morning => Icons.light_mode_outlined,
    ReminderTimePeriod.afternoon => Icons.wb_sunny_outlined,
    ReminderTimePeriod.evening => Icons.dark_mode_outlined,
  };
}
