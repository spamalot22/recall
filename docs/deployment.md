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

## Container Hardening

The API service is intended to run:

- from a distroless Node runtime image
- as a non-root user
- with a read-only filesystem
- with all Linux capabilities dropped
- with `no-new-privileges`
- with only `/tmp` writable through tmpfs if needed
