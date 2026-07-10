# Deployment Notes

Recall's backend is designed to be private by default and Portainer-friendly.

## Default Network Shape

```text
Tailscale/localhost -> recall_api -> recall_db
```

- `recall_api` binds to `127.0.0.1` on the Docker host.
- `recall_db` has no host port.
- API and database communicate through a private Docker bridge network.

## Tailscale

Use Tailscale Serve for private tailnet access:

```bash
tailscale serve --bg http://127.0.0.1:8787
```

Treat Tailscale Funnel as an explicit opt-in mode. Before enabling Funnel, confirm:

- Public registration is disabled unless intentionally needed.
- Bootstrap credentials have been rotated or removed.
- JWT secrets and database password are unique and strong.
- `/health` reveals no sensitive metadata.
- Logs do not include plaintext tokens or encrypted payload contents.
- Rate limiting is enabled on authentication routes.

`TRUST_PROXY` is empty by default, so forwarded client-IP headers are ignored.
Leave it empty unless rate limits need the original Funnel client IP. When it is
needed, set it to the exact IP or narrow CIDR of the local trusted proxy as seen
by the API container. Never set it to `true`, `0.0.0.0/0`, or `::/0`.

The app must use the HTTPS URL presented by Tailscale Serve or Funnel. Plain HTTP
is accepted only for local Android-emulator development.

## Initial Account Setup

Public registration is disabled by default. Configure
`RECALL_BOOTSTRAP_EMAIL` and `RECALL_BOOTSTRAP_PASSWORD` before the first start,
then sign in from the app. On that first login the app generates the account
master key and recovery key and uploads only their wrapped key bundle.

If public registration is intentionally enabled, new accounts can be created
from the same app screen. Disable it again after account setup unless ongoing
self-registration is required.

Database migration `0002_tiny_the_watchers.sql` adds the verifier used for
password recovery. The client sends a SHA-256 verifier, not the recovery key,
and unwraps the master key locally before submitting a newly wrapped password
key. A successful recovery revokes the account's existing sessions.

## Production Secrets

Replace every `change-this` value in `.env` before starting the production
stack. Recall refuses to start in production with placeholder database/JWT
secrets, identical access and refresh JWT secrets, low-diversity JWT secrets,
or broad proxy trust. Generate independent values, for example:

```bash
openssl rand -hex 24
openssl rand -base64 48
openssl rand -base64 48
```

Use the first value for both `POSTGRES_PASSWORD` and the password component of
`DATABASE_URL`. Use the other two values separately for `JWT_ACCESS_SECRET` and
`JWT_REFRESH_SECRET`. Remove bootstrap credentials from the stack after the
first account has been created.

## Container Hardening

The API service is intended to run:

- from a distroless Node runtime image
- as a non-root user
- with a read-only filesystem
- with all Linux capabilities dropped
- with `no-new-privileges`
- with only `/tmp` writable through tmpfs if needed
