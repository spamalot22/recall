# Recall Agent Instructions

## Resource-Constrained Host

This checkout runs on a resource-constrained remote server. Heavy local builds
have caused the server to become unresponsive.

- Never run local Android packaging or Gradle build commands, including
  `flutter build apk`, `flutter build appbundle`, `gradlew assemble*`, or
  `gradlew bundle*`.
- Never run local Docker image builds or other similarly resource-intensive
  compilation unless the user explicitly approves that exact operation in the
  current conversation.
- Verify Android/Gradle integration and release packaging through the GitHub
  Actions pipelines in `.github/workflows/`.
- Prefer lightweight local checks such as formatting, static analysis, and
  focused tests. Leave the complete test/build matrix to GitHub Actions when a
  change needs broad verification.
- Do not run resource-intensive verification jobs in parallel.
- After a disconnected or interrupted command, do not automatically resume a
  build session. Treat its result as unknown and use GitHub Actions instead.

These restrictions apply even when sufficient disk space appears available;
memory, CPU, and I/O pressure are also constraints on this host.
