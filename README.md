# auth2-proxy

Single-host docker-compose stack: **HAProxy** in front of **oauth2-proxy** and
**Keycloak**, with **nginx** as the protected upstream.

```
browser
   │
   ▼
HAProxy :80           ── /auth/* ──▶ Keycloak (KC_HTTP_RELATIVE_PATH=/auth)
   │
   └── everything else ──▶ oauth2-proxy ── /oauth/* (its own callback/start/etc)
                                  │
                                  └── authenticated ──▶ nginx
```

`/` is served by nginx **after** auth, so an unauthenticated visit is
intercepted by oauth2-proxy and redirected to Keycloak login.

## Quick start

Requires Docker Desktop (or Docker Engine + compose plugin) and
[`just`](https://github.com/casey/just).

```sh
just init       # detect LAN IP, write .env
just up         # docker compose up -d --wait
just urls       # print the URLs to open
just test       # headed Playwright run: visit /, log in, assert userinfo
```

The `just test` recipe brings the stack up, installs `@playwright/test` + a
local chromium, and drives the full login flow in a **visible** browser
(`slowMo` + per-step pauses so you can watch). Tweak pacing with
`just test slow_mo=300 step_pause_ms=500`. For CI, use `just test-ci`
(headless, no pauses).

Default test login (from `keycloak/realm-export.json`):

```
username: test
password: test
```

Keycloak admin console (master realm):

```
http://<HOST_IP>/auth/admin/   admin / admin
```

## Configuration

Everything tunable lives in `.env` (created from `.env.example`):

| var | default | purpose |
| --- | --- | --- |
| `HOST_IP` | auto-detected | IP HAProxy binds to and that appears in OIDC URLs |
| `HOST_PORT` | `80` | Public port |
| `KEYCLOAK_ADMIN` / `_PASSWORD` | `admin` / `admin` | Keycloak master-realm admin |
| `OAUTH2_PROXY_CLIENT_SECRET` | `oauth2-proxy-secret` | Must match `clients[].secret` in the realm export |
| `OAUTH2_PROXY_COOKIE_SECRET` | 32 hex chars | Cookie signing key (16/24/32 bytes) |

To rebind to a new IP (e.g. after switching networks):

```sh
just init && just up
```

## Files

| path | what |
| --- | --- |
| `docker-compose.yml` | Service definitions |
| `haproxy/haproxy.cfg` | Edge routing rules |
| `oauth2-proxy/oauth2-proxy.cfg` | oauth2-proxy config (secrets via env) |
| `keycloak/realm-export.json` | Pre-imported realm `proxy` with client + test user |
| `nginx/default.conf`, `nginx/html/*` | Protected landing pages |
| `justfile` | `init`, `up`, `down`, `logs`, `urls`, `cookie-secret`, ... |

## Notes

- **Plain HTTP** for the demo. Behind real TLS, set `cookie_secure = true`
  in `oauth2-proxy/oauth2-proxy.cfg` and update `X-Forwarded-Proto` in
  `haproxy/haproxy.cfg` to `https`.
- The realm-export uses wildcard redirect URIs (`http://*/oauth/callback`)
  so any `HOST_IP` works without re-importing.
- Keycloak's first start with `--import-realm` takes ~30s; HAProxy's
  health check will mark the backend up once Keycloak's `/auth/health/ready`
  returns 200.
