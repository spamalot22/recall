# Recall Implementation Plan

## Product Direction

Recall is a local-first notes and reminders app inspired by Google Keep, with better recurring reminders, encrypted multi-user sync, and optional self-hosted backup.

The Android app is the primary target for v1. The architecture should keep future iOS, desktop, and web clients possible.

## Core Principles

- Local-first: the app works without the backend.
- Reminder-first: recurring reminders are predictable, inspectable, and reliable.
- End-to-end encrypted sync: the server stores encrypted user data and cannot read note contents.
- Multi-user from v1: every server-side record is scoped to an authenticated user.
- Self-host friendly: Docker Compose deployment, private by default, safe to expose through Tailscale Serve/Funnel when configured carefully.
- Conservative scope: text notes, checklist notes, reminders, search, trash, sync, and recovery keys before attachments or AI.

## Initial Tech Stack

### Flutter App

- Flutter and Dart.
- `drift` with SQLite for local persistence.
- Riverpod for state management.
- `go_router` for navigation.
- Local notifications for reminder delivery.
- Android alarm integration where required for reliable reminders.
- Local cryptography for note encryption and recovery-key handling.

### Backend

- Node.js 22.
- TypeScript.
- Fastify.
- Drizzle ORM.
- PostgreSQL.
- Docker Compose.
- Distroless Node runtime image for the API container.

## Repository Layout

```text
recall/
  app/                    Flutter app
  server/                 Fastify API
  docs/                   Architecture and planning notes
  docker-compose.yml      Self-hosted deployment
  README.md
```

## V1 Product Scope

### Notes

- Text notes.
- Checklist notes.
- Pin and archive.
- Trash instead of immediate deletion.
- Local search.
- Card grid as the default home view.

### Color Moods

- Curated color mood presets instead of free-form colors.
- Automatic default mood assignment based on local note state.
- User override support.
- Light and dark variants for each mood.
- Mood data stored inside encrypted note payloads.

Initial automatic assignment rules can be simple:

- Reminder due soon: urgent mood.
- Recurring reminder: routine mood.
- Checklist note: task or errand mood.
- Pinned note: focus mood.
- Plain note: clear mood.

### Reminders

- Time-based reminders only.
- One-time reminders.
- Recurring reminders:
  - Daily.
  - Weekdays.
  - Weekly on selected days.
  - Monthly on day of month.
  - Yearly.
  - Every N days/weeks/months.
  - Optional end date.
- Snooze:
  - 10 minutes.
  - 1 hour.
  - Tomorrow.
  - Custom date/time.
- Reminder occurrence history for fired, dismissed, skipped, and snoozed occurrences.
- No location-based reminders in v1.

### Accounts And Security

- Multi-user backend.
- Email/password authentication.
- Argon2id password hashing.
- Per-device sessions.
- Short-lived access tokens.
- Rotating refresh tokens.
- Device/session revocation support.
- Public registration disabled by default.
- Initial user bootstrap via environment variables or an admin setup flow.
- Recovery key flow in v1.

### End-To-End Encryption

- App generates a random user master encryption key.
- Password-derived key wraps the master key.
- Recovery-key-derived key also wraps the master key.
- Server stores encrypted key bundles.
- App encrypts/decrypts note data locally.
- Server stores encrypted payloads and sync metadata only.
- Forgotten password plus lost recovery key means encrypted notes are unrecoverable.

### Sync

- True sync from v1, not only backup/restore.
- Granular encrypted records rather than one blob for the entire user database.
- Server records are always scoped by `user_id`.
- Preserve conflicting versions instead of silent last-write-wins overwrites.
- Use encrypted tombstones for deleted records so deletion sync is reliable.

### Deployment

- One Docker Compose stack for Portainer-friendly deployment.
- API and database run as separate services.
- PostgreSQL has no host port by default.
- API binds to localhost by default.
- Tailscale Serve/Funnel is optional and documented, not the default assumption.
- API container uses a distroless runtime image and non-root user.
- Container hardening:
  - `read_only: true`
  - `cap_drop: [ALL]`
  - `security_opt: [no-new-privileges:true]`
  - tmpfs for `/tmp` if needed

## Backend Service Shape

Initial services:

- `recall_api`: Fastify API.
- `recall_db`: PostgreSQL.

Expected server responsibilities:

- User authentication.
- Device/session management.
- Encrypted key bundle storage.
- Encrypted record sync.
- Conflict metadata.
- Minimal health endpoint.
- Audit events for security-sensitive actions.

The server must not require or accept plaintext note contents.

## Early Database Concepts

Server-side tables should include:

- `users`
- `devices`
- `sessions`
- `key_bundles`
- `encrypted_records`
- `sync_cursors`
- `audit_events`

The `encrypted_records` table should include metadata needed for sync:

- record id
- user id
- record type
- encrypted payload
- payload version
- client revision
- server revision
- created at
- updated at
- deleted at or tombstone marker
- source device id
- conflict/origin metadata

## Local App Data Concepts

Local app tables should include:

- notes
- checklist items
- reminders
- recurrence rules
- reminder occurrences
- encrypted sync records or sync journal
- devices/account state

Local search indexes can be plaintext on device because data is decrypted locally. Server-side search is out of scope for v1.

## Suggested Milestones

### Milestone 1: Skeleton

- Create Flutter app shell.
- Create Fastify TypeScript server.
- Add Docker Compose with API and PostgreSQL.
- Add basic README.
- Add development scripts.
- Add health endpoint.
- Add CI-friendly lint/test commands.

### Milestone 2: Backend Auth Foundation

- Add Drizzle schema and migrations.
- Add users, devices, sessions, key bundles, and audit events.
- Implement Argon2id password hashing.
- Implement login, refresh, logout, and session revocation.
- Add registration disabled-by-default behavior.
- Add bootstrap/admin setup path.
- Add request validation, rate limits, and security headers.

### Milestone 3: Encryption Foundation

- Add app-side master key generation.
- Add password-derived key wrapping.
- Add recovery-key generation and wrapping.
- Add unlock flow on login.
- Add encrypted key bundle upload/download.
- Document recovery limitations clearly.

### Milestone 4: Local Notes MVP

- Add local SQLite schema with drift.
- Build card grid home view.
- Add create/edit text note.
- Add checklist note support.
- Add pin/archive/trash.
- Add curated color moods with light/dark variants.
- Add local search.

### Milestone 5: Reminder MVP

- Add one-time reminders.
- Add recurring reminder presets.
- Add reminder occurrence tracking.
- Add snooze.
- Add local notification scheduling.
- Add Android-specific alarm handling if needed.

### Milestone 6: Encrypted Sync

- Add encrypted record model.
- Add push/pull sync endpoints.
- Add device sync cursor handling.
- Add tombstone sync.
- Add conflict preservation.
- Add manual sync trigger in the app.
- Add basic automatic sync when online.

### Milestone 7: Deployment Hardening

- Switch API runtime image to distroless.
- Run API as non-root.
- Add Compose hardening.
- Bind API to localhost by default.
- Document Tailscale Serve setup.
- Document optional Funnel exposure checklist.
- Add production configuration guide.

### Milestone 8: Polish And Release Prep

- Improve empty, loading, offline, and error states.
- Add import/export strategy if needed.
- Add app settings.
- Add recovery key confirmation UX.
- Add basic backups documentation.
- Add integration tests for auth and sync.
- Add Flutter widget tests for core note/reminder flows.

## Deferred From V1

- Attachments.
- Voice notes.
- OCR.
- AI features.
- Collaboration/shared notes.
- Web client.
- Location-based reminders.
- Realtime sync.
- Full custom RRULE editor.
- Server-side note search.

## Open Decisions

- Exact Flutter crypto package selection.
- Exact Android reminder package and native integration strategy.
- Exact conflict UI.
- Initial curated color mood names and palettes.
- Whether bootstrap user setup happens entirely through env vars or a one-time setup endpoint.
