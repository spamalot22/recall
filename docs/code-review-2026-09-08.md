# Code review: 2026-09-08

This review covers the handwritten app storage, account, sync, reminder,
note-editing and ordering code, plus the backend sync routes and release gates.
Generated code and third-party dependencies are not independently audited here.

## Issues fixed

- Interrupted sync could skip remote notes because upload acknowledgements were
  incorrectly used as download progress. Schema 5 adds a transactional pull
  cursor, initially zero so existing installations replay remote records safely.
- Upload acknowledgements and incoming records could overwrite edits made during
  sync, including edits within the same second. Compare encrypted snapshots with
  current note contents, validate acknowledgements, and preserve conflict copies.
- Permanent deletion while disconnected could be forgotten. Persist deletion
  markers and queue the tombstone atomically with deleting the local note.
- Foreign-key enforcement was missing. Enable cascades, clean up orphaned child
  rows during migration, and reject stale edits to deleted or trashed notes.
- Negative card positions were rejected when restoring notes from backup.
- Large uploads and downloads could exceed the 1 MiB HTTP limit. Bound batches
  by bytes as well as record count, with progress-preserving pagination.
- Retried uploads could produce unnecessary conflict copies. Acknowledge identical
  retries without changing revision; retain the original encrypted identity when
  a conflict is itself copied, and clear conflict metadata after editing it.
- Incoming record identities and types were insufficiently validated. Reject
  mismatched encrypted identities and attempts to relabel another existing note
  as a conflict. Invalid pages roll back instead of advancing the cursor.
- POSIX file locks did not exclude background isolates in the same process.
  A separate SQLite lock file now serializes sync and credential replacement;
  database-key creation uses a separate lock. Lock files contain no credentials
  or note content. Network header/body waits are bounded for sync and sign-in.
- Credential updates used multiple independent secure-storage writes. New
  sessions use one encrypted value, retain legacy read compatibility, and keep
  a signed-out marker so interrupted cleanup cannot revive older credentials.
- Background notification engines may lack the Activity timezone channel. Use
  rolling UTC instants computed from the device calendar in that case, retaining
  seconds instead of truncating potentially near-future alarms into the past.
- Saving an existing elapsed reminder could reject otherwise valid text edits;
  editing also discarded snoozes. Preserve unchanged anchors and snoozes.
- Close could discard very recent edits before the navigation guard rebuilt.
  Explicitly save dirty content and guard against duplicate saves.
- Note actions and undo callbacks could access disposed widget references.
  Capture the services before awaiting writes or removing the card/editor.
- Dragging could access stale geometry or invalid ordering after notes changed.
  Guard the geometry and validate membership before committing an order.
- Recurring notes could remain urgent because sentiment context used the original
  past anchor. Use the next actual occurrence instead.
- Manually dispatched server publishing could build the selected branch under an
  unrelated version tag. Check out the validated release tag explicitly.

## Verification and release requirements

Focused Flutter suites cover sync failures and concurrent edits, isolate locking,
secure-session migration, database encryption and migration, background sync,
recurrence, notification scheduling, note storage, mood context, and widget flows.
Run tests serially on this host; do not build Android packages or Docker images.

The new PostgreSQL integration suite uses only `RECALL_TEST_DATABASE_URL`, never
the deployment `DATABASE_URL`. It checks real migrations, idempotent retries,
nested conflicts, byte-bounded pagination, and tenant separation. It is skipped
locally without a disposable database and required by CI and both release workflows
through their PostgreSQL service. Existing dependency-audit failure gates remain.

Before publishing, GitHub Actions must pass PostgreSQL integration tests, the full
Flutter matrix, dependency auditing, and Android/container builds. Real Samsung
locked-screen and background notification delivery still needs device testing.
This review does not itself publish or tag a release.
