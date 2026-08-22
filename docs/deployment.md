# Deployment Notes

Recall's backend is designed to be private by default and Portainer-friendly.

The stack pulls the published `ghcr.io/spamalot22/recall-server` image. It does
not build the Node API on the home server. Release tags publish matching
`linux/amd64` and `linux/arm64` images and update the `latest` tag.

For reproducible deployments, set this Portainer stack environment variable to
the release being deployed:

```text
TAG=0.1.21
```

Leave `TAG=latest` only when the stack should follow the newest release. After
changing the tag, use Portainer's image-pull and redeploy controls so the new
image is fetched before the container is replaced.

## Default Network Shape

```text
phone on home LAN -> recall_api -> recall_db
```

- `recall_api` binds to `127.0.0.1` until LAN access is explicitly configured.
- `recall_db` has no host port.
- API and database communicate through a private Docker bridge network.

## Home LAN Setup

Give the home server a DHCP reservation or static address. In Portainer, add the
following stack environment variables, replacing the example address with that
fixed LAN address:

```text
RECALL_API_BIND_ADDRESS=192.168.1.10
RECALL_API_PORT=8787
```

Redeploy the stack, then open this URL from the phone while it is connected to
home Wi-Fi:

```text
http://192.168.1.10:8787/health
```

It should return a small JSON health response. In Recall, use
`http://192.168.1.10:8787` as the Backup URL. Use the numeric address rather
than a local hostname: HTTP is accepted only for literal private or loopback
addresses.

Do not forward port `8787` on the router. If the server has a host firewall,
allow TCP `8787` only from the home LAN subnet. Docker publishes only the API;
PostgreSQL remains reachable solely from the private Compose network.

### Transport Security

Encrypted note contents remain end-to-end encrypted before they reach the API.
Login passwords, access tokens, and sync metadata are protected by the home
network but are not protected from LAN interception when plain HTTP is used.
Use WPA2/WPA3, do not use this mode on an untrusted/shared LAN, and prefer a
locally trusted HTTPS reverse proxy if other people or devices on the LAN are
not trusted. Public addresses and hostnames remain HTTPS-only in the app.

## Battery-Aware Sync

Android background work is constrained to unmetered networking. For a private
numeric Backup URL, Recall also compares the server address with the phone's
active local addresses and skips automatic sync unless both are on the same
IPv4 `/24` or IPv6 `/64` subnet. An unavailable LAN server is not submitted to
WorkManager for repeated retries; pending encrypted changes remain local until
the next eligible run.

Manual sync deliberately bypasses this LAN gate so configuration errors can be
diagnosed from Settings. Android still chooses the exact time for periodic work.

## Internet Exposure

The supplied stack is not intended for direct internet exposure. Before adding
an HTTPS reverse proxy or tunnel, confirm:

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

Any non-LAN deployment must use a publicly trusted HTTPS URL.

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

The API image is published only after the server build, tests, and dependency
audit pass. Its runtime remains distroless and non-root. The PostgreSQL image is
pulled separately and the database is not exposed on a host port.
