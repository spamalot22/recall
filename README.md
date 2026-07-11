# Recall

Recall is a local-first notes and reminders app with reliable recurring reminders, end-to-end encrypted sync, and an optional self-hosted backend.

## Current Status

Recall now has an Android-first local notes experience, reliable local reminders,
an encrypted local SQLite database, and optional end-to-end encrypted sync to the
Dockerized Node/Fastify/PostgreSQL backend.

Implemented client features include text notes, checklists, search, pinning,
archive, trash, Material You theming, locally inferred colour moods with manual
overrides, recurring reminders, encrypted account setup, password recovery
keys, automatic sync while the app is active, manual sync, conflict copies, and
signed in-app APK updates. Native Android background execution is temporarily
disabled after an Android 16 startup regression.

## Layout

```text
app/          Flutter app
server/       Fastify + TypeScript backend
docs/         Architecture and planning notes
```

## Backend Development

```bash
cd server
npm install
cp .env.example .env
npm run build
npm run dev
```

The backend expects PostgreSQL through `DATABASE_URL`.

## Docker

```bash
cp .env.example .env
docker compose up --build
```

By default, the API binds to localhost only:

```text
127.0.0.1:8787
```

PostgreSQL is not exposed on a host port. For remote access, expose the API through Tailscale Serve first. Tailscale Funnel should be treated as an explicit opt-in deployment mode after hardening and review.

## Flutter Development

```bash
cd app
flutter pub get
flutter run
```

The first app target is Android.

An optional default backup URL can be compiled into development builds:

```bash
flutter run --dart-define=RECALL_API_URL=https://recall.example.com
```

Users can also enter the URL in **Settings > Connect encrypted backup**. Recall
requires HTTPS except for Android-emulator development through `10.0.2.2` or
`localhost`.

## Encryption And Recovery

- The local database is encrypted with SQLite3MultipleCiphers using a random
  256-bit key protected by platform secure storage.
- Each sync record is encrypted with AES-256-GCM before upload.
- The account master key is wrapped independently by the password and recovery
  key. The backend stores only wrapped keys, a recovery verifier, and encrypted
  records.
- Store the recovery key outside the device. Losing both the password and
  recovery key makes the encrypted notes unrecoverable.
- A local installation is bound to its first connected user account to prevent
  one user's local notes from being uploaded to another account accidentally.

Sync runs after local changes and whenever the app opens or resumes. Conflicting
remote content is preserved as a visible `Conflict:` note copy instead of being
silently overwritten.

## Releases

CI runs on pushes to `main` and pull requests. Android APK publishing only runs when a bare semantic version tag is pushed:

```bash
git tag 1.1.1
git push origin 1.1.1
```

Tags such as `v1.1.1` or `1.1.1-beta.1` do not publish.

Release builds fail when the release keystore is not configured; they never
fall back to debug signing. The in-app updater accepts only the expected GitHub
release asset, bounds the download size, and asks Android to install it only
after its package name, version code, and signing certificate match the
installed Recall app.
