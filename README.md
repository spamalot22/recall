# Recall

Recall is a local-first notes and reminders app with reliable recurring reminders, end-to-end encrypted sync, and an optional self-hosted backend.

## Current Status

This repository is in initial scaffolding. The v1 target is Android-first Flutter plus a Dockerized Node/Fastify/PostgreSQL backend.

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
