# Maintenance: 2026-11-09

## Dependencies

Updated compatible Node and Flutter dependencies, including JWT verification,
Zod, URI parsing, Vitest/Vite, notification scheduling, secure storage, timezone
data and WorkManager. The repository's fail-closed npm audit reports zero
vulnerabilities after the update. Kept Drift aligned with the checked-in
generated database code rather than regenerating it on this constrained host.

## Reminder delivery

The previous maintenance path cancelled every alarm before rebuilding the
schedule. A delayed alarm could disappear when maintenance ran after its due
time; a failure rebuilding the batch could also leave upcoming reminders absent.

Cycle occurrences now have IDs derived from the note and occurrence instant.
Maintenance replaces future alarms before removing obsolete entries, preserves
matching overdue alarms for up to 24 hours, and rolls back newly introduced
alarms if a replacement batch fails. Snoozes receive the same overdue grace.
Foreground and background scheduler operations share a cross-isolate lock, and
one reminder's failure does not stop other notes being scheduled. Deletion also
removes already displayed notifications owned by the note.

Fixed a separate daylight-saving bug: resolving a nonexistent spring-forward
time at a cycle boundary could permanently shift later cycles by an hour. Cycle
arithmetic now retains the intended wall-clock time. Calendar shortcuts also
use calendar-day arithmetic instead of elapsed 24-hour durations. Notification
plugin 22.3.3 includes an upstream Android repeating-notification DST fix.

The UI shows the next planned notification on note cards, the note editor's
reminder button and the cycle editor. This is the calculated schedule, not an
assertion that Android has delivered or will permit the notification.

## Verification

Regression coverage includes one week active/four weeks resting, the next active
week being queued during rest, maintenance after a delayed due time, overdue
snoozes, partial replacement failures, per-note failures, deletion, spring-forward
cycle consistency, legacy notification payloads and the next-notification preview.
CI and release checks explicitly run the delivery suite in America/New_York as
well as the default environment. Android packaging, PostgreSQL integration and
container builds remain GitHub Actions responsibilities.

The exact cause of the reported missed notification cannot be established
without the phone's alarm/notification state. These are reproduced code defects;
real-device delivery after the next rest period still needs confirmation.
