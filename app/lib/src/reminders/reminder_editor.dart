import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../notes/note_models.dart';
import 'reminder_time_options.dart';

class ReminderEditorSelection {
  const ReminderEditorSelection(
    this.at,
    this.recurrence, {
    this.recurrenceInterval = 1,
    this.cycle,
  });

  final DateTime? at;
  final ReminderRecurrence recurrence;
  final int recurrenceInterval;
  final ReminderCycle? cycle;
}

Future<ReminderEditorSelection?> showReminderEditor(
  BuildContext context, {
  required DateTime? initialAt,
  required ReminderRecurrence initialRecurrence,
  int initialRecurrenceInterval = 1,
  ReminderCycle? initialCycle,
  DateTime Function()? nowProvider,
}) {
  final currentTime = nowProvider ?? DateTime.now;
  final initialSelection = initialAt ?? defaultReminderDateTime(currentTime());
  var selectedDate = reminderDateOnly(initialSelection);
  var selectedTime = TimeOfDay.fromDateTime(initialSelection);
  var recurrence = initialRecurrence;
  var recurrenceInterval = initialRecurrenceInterval.clamp(1, 999).toInt();
  var cycleEnabled = initialCycle != null;
  var activeDuration =
      initialCycle?.activeDuration ??
      const ReminderDuration(value: 1, unit: ReminderDurationUnit.weeks);
  var restDuration =
      initialCycle?.restDuration ??
      const ReminderDuration(value: 1, unit: ReminderDurationUnit.weeks);
  var cycleEndMode = initialCycle?.endAt != null
      ? _CycleEndMode.date
      : initialCycle?.maxCycles != null
      ? _CycleEndMode.cycles
      : _CycleEndMode.never;
  var cycleEndDate = reminderDateOnly(
    initialCycle?.endAt ?? initialSelection.add(const Duration(days: 28)),
  );
  var maxCycles = initialCycle?.maxCycles ?? 3;

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
        final availablePresets = recurrence == ReminderRecurrence.none
            ? availableReminderTimePresets(selectedDate: selectedDate, now: now)
            : reminderTimePresets;
        final cycleEndAt = combineReminderDateAndTime(
          cycleEndDate,
          selectedTime,
        );
        final cycleIsValid =
            !cycleEnabled ||
            cycleEndMode != _CycleEndMode.date ||
            !cycleEndAt.isBefore(selectedAt);
        final isValid =
            (recurrence != ReminderRecurrence.none ||
                selectedAt.isAfter(now)) &&
            cycleIsValid;
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
            if (cycleEndDate.isBefore(selectedDate)) {
              cycleEndDate = selectedDate;
            }
            if (recurrence == ReminderRecurrence.none) {
              selectedTime = validReminderTimeForDate(
                selectedDate: selectedDate,
                preferredTime: selectedTime,
                now: selectionNow,
              );
            }
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
                      Text(
                        recurrence == ReminderRecurrence.none
                            ? 'Date'
                            : 'Starts',
                        style: textTheme.titleMedium,
                      ),
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
                        onSelected:
                            (recurrence != ReminderRecurrence.none ||
                                canScheduleReminderOnDate(today, now))
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
                                    cycleIsValid
                                        ? 'Choose a future time for this reminder.'
                                        : 'The end date cannot be before the start date.',
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
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Repeat',
                      prefixIcon: Icon(Icons.event_repeat_rounded),
                    ),
                    items: [
                      for (final value in ReminderRecurrence.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(
                            _repeatOptionLabel(value),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() {
                          recurrence = value;
                          if (value == ReminderRecurrence.none) {
                            recurrenceInterval = 1;
                            cycleEnabled = false;
                          }
                        });
                      }
                    },
                  ),
                  AnimatedSize(
                    duration: selectionMotion,
                    curve: Curves.easeOutCubic,
                    child: recurrence == ReminderRecurrence.none
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Interval',
                                prefixIcon: Icon(Icons.repeat_rounded),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Decrease interval',
                                    onPressed: recurrenceInterval > 1
                                        ? () => setSheetState(
                                            () => recurrenceInterval--,
                                          )
                                        : null,
                                    icon: const Icon(Icons.remove_rounded),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final selected =
                                          await _pickRecurrenceInterval(
                                            sheetContext,
                                            recurrenceInterval,
                                          );
                                      if (selected != null &&
                                          sheetContext.mounted) {
                                        setSheetState(
                                          () => recurrenceInterval = selected,
                                        );
                                      }
                                    },
                                    child: Text('$recurrenceInterval'),
                                  ),
                                  IconButton(
                                    tooltip: 'Increase interval',
                                    onPressed: recurrenceInterval < 999
                                        ? () => setSheetState(
                                            () => recurrenceInterval++,
                                          )
                                        : null,
                                    icon: const Icon(Icons.add_rounded),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      recurrence.unitLabel(recurrenceInterval),
                                      style: textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  AnimatedSize(
                    duration: selectionMotion,
                    curve: Curves.easeOutCubic,
                    child: recurrence == ReminderRecurrence.none
                        ? const SizedBox(width: double.infinity)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 8),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Active/rest cycle'),
                                secondary: const Icon(
                                  Icons.event_repeat_rounded,
                                ),
                                value: cycleEnabled,
                                onChanged: (value) =>
                                    setSheetState(() => cycleEnabled = value),
                              ),
                              AnimatedSize(
                                duration: selectionMotion,
                                curve: Curves.easeOutCubic,
                                child: !cycleEnabled
                                    ? const SizedBox(width: double.infinity)
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _ReminderDurationField(
                                            label: 'Active for',
                                            duration: activeDuration,
                                            onChanged: (value) => setSheetState(
                                              () => activeDuration = value,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          _ReminderDurationField(
                                            label: 'Rest for',
                                            duration: restDuration,
                                            onChanged: (value) => setSheetState(
                                              () => restDuration = value,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          DropdownButtonFormField<
                                            _CycleEndMode
                                          >(
                                            initialValue: cycleEndMode,
                                            isExpanded: true,
                                            decoration: const InputDecoration(
                                              labelText: 'Ends',
                                              prefixIcon: Icon(
                                                Icons.flag_outlined,
                                              ),
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: _CycleEndMode.never,
                                                child: Text('Never'),
                                              ),
                                              DropdownMenuItem(
                                                value: _CycleEndMode.date,
                                                child: Text('On a date'),
                                              ),
                                              DropdownMenuItem(
                                                value: _CycleEndMode.cycles,
                                                child: Text(
                                                  'After a number of cycles',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                            onChanged: (value) {
                                              if (value != null) {
                                                setSheetState(
                                                  () => cycleEndMode = value,
                                                );
                                              }
                                            },
                                          ),
                                          if (cycleEndMode ==
                                              _CycleEndMode.date) ...[
                                            const SizedBox(height: 12),
                                            ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              leading: const Icon(
                                                Icons.event_outlined,
                                              ),
                                              title: const Text('End date'),
                                              subtitle: Text(
                                                localizations.formatMediumDate(
                                                  cycleEndDate,
                                                ),
                                              ),
                                              trailing: const Icon(
                                                Icons.chevron_right_rounded,
                                              ),
                                              onTap: () async {
                                                final selected =
                                                    await _pickCycleEndDate(
                                                      sheetContext,
                                                      cycleEndDate,
                                                      firstDate: selectedDate,
                                                    );
                                                if (selected != null &&
                                                    sheetContext.mounted) {
                                                  setSheetState(
                                                    () =>
                                                        cycleEndDate = selected,
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                          if (cycleEndMode ==
                                              _CycleEndMode.cycles) ...[
                                            const SizedBox(height: 12),
                                            _NumberStepperField(
                                              label: 'Number of cycles',
                                              value: maxCycles,
                                              unit: maxCycles == 1
                                                  ? 'cycle'
                                                  : 'cycles',
                                              onChanged: (value) =>
                                                  setSheetState(
                                                    () => maxCycles = value,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                              ),
                            ],
                          ),
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
                                ReminderEditorSelection(
                                  selectedAt,
                                  recurrence,
                                  recurrenceInterval: recurrenceInterval,
                                  cycle:
                                      recurrence == ReminderRecurrence.none ||
                                          !cycleEnabled
                                      ? null
                                      : ReminderCycle(
                                          activeDuration: activeDuration,
                                          restDuration: restDuration,
                                          endAt:
                                              cycleEndMode == _CycleEndMode.date
                                              ? cycleEndAt
                                              : null,
                                          maxCycles:
                                              cycleEndMode ==
                                                  _CycleEndMode.cycles
                                              ? maxCycles
                                              : null,
                                        ),
                                ),
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

String _repeatOptionLabel(ReminderRecurrence recurrence) {
  return switch (recurrence) {
    ReminderRecurrence.none => 'Does not repeat',
    ReminderRecurrence.daily => 'Days',
    ReminderRecurrence.weekly => 'Weeks',
    ReminderRecurrence.monthly => 'Months',
    ReminderRecurrence.yearly => 'Years',
  };
}

enum _CycleEndMode { never, date, cycles }

class _ReminderDurationField extends StatelessWidget {
  const _ReminderDurationField({
    required this.label,
    required this.duration,
    required this.onChanged,
  });

  final String label;
  final ReminderDuration duration;
  final ValueChanged<ReminderDuration> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Decrease $label',
            onPressed: duration.value > 1
                ? () => onChanged(
                    ReminderDuration(
                      value: duration.value - 1,
                      unit: duration.unit,
                    ),
                  )
                : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          TextButton(
            onPressed: () async {
              final selected = await _pickBoundedNumber(
                context,
                duration.value,
                title: label,
                fieldLabel: 'Length',
              );
              if (selected != null && context.mounted) {
                onChanged(
                  ReminderDuration(value: selected, unit: duration.unit),
                );
              }
            },
            child: Text('${duration.value}'),
          ),
          IconButton(
            tooltip: 'Increase $label',
            onPressed: duration.value < 999
                ? () => onChanged(
                    ReminderDuration(
                      value: duration.value + 1,
                      unit: duration.unit,
                    ),
                  )
                : null,
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ReminderDurationUnit>(
                value: duration.unit,
                isExpanded: true,
                items: [
                  for (final unit in ReminderDurationUnit.values)
                    DropdownMenuItem(
                      value: unit,
                      child: Text(unit.unitLabel(duration.value)),
                    ),
                ],
                onChanged: (unit) {
                  if (unit != null) {
                    onChanged(
                      ReminderDuration(value: duration.value, unit: unit),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberStepperField extends StatelessWidget {
  const _NumberStepperField({
    required this.label,
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Decrease $label',
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          TextButton(
            onPressed: () async {
              final selected = await _pickBoundedNumber(
                context,
                value,
                title: label,
                fieldLabel: 'Count',
              );
              if (selected != null && context.mounted) {
                onChanged(selected);
              }
            },
            child: Text('$value'),
          ),
          IconButton(
            tooltip: 'Increase $label',
            onPressed: value < 999 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(unit)),
        ],
      ),
    );
  }
}

Future<int?> _pickRecurrenceInterval(BuildContext context, int initialValue) {
  return _pickBoundedNumber(
    context,
    initialValue,
    title: 'Repeat interval',
    fieldLabel: 'Every',
  );
}

Future<int?> _pickBoundedNumber(
  BuildContext context,
  int initialValue, {
  required String title,
  required String fieldLabel,
}) async {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController(text: '$initialValue');
  try {
    return await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(labelText: fieldLabel),
            validator: (value) {
              final interval = int.tryParse(value ?? '');
              if (interval == null || interval < 1 || interval > 999) {
                return 'Enter a number from 1 to 999.';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(int.parse(controller.text));
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(int.parse(controller.text));
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
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

Future<DateTime?> _pickCycleEndDate(
  BuildContext context,
  DateTime initial, {
  required DateTime firstDate,
}) {
  final start = reminderDateOnly(firstDate);
  final lastDate = DateTime(start.year + 100, start.month, start.day);
  final initialDate = initial.isBefore(start)
      ? start
      : initial.isAfter(lastDate)
      ? lastDate
      : initial;
  return showDatePicker(
    context: context,
    helpText: 'Choose cycle end date',
    initialDate: initialDate,
    firstDate: start,
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
