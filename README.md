# oauth2-proxy + keycloak

**HAProxy** in front of **oauth2-proxy** and **Keycloak**, with **nginx**
as the protected upstream. Deployable two ways:

- `docker-compose/` — single-host docker-compose stack.
- `helm/oauth2-keycloak/` — Helm chart for Kubernetes; the edge HAProxy
  layer collapses into a stock `Ingress` resource.

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
just compose up       # detect LAN IP, render realm, docker compose up -d --wait
just compose urls     # print the URLs to open
just test-compose     # bring stack up → run headed Playwright → tear down
```

`test-compose` installs `@playwright/test` + a local chromium and drives
the full login flow in a **visible** browser (`slowMo` + per-step pauses
so you can watch). Tweak pacing with `just test-compose '' 300 500` (the
first arg is reserved for `--keep`; pass it to leave the stack running
after the test). For CI, use `just test-compose-ci` (headless, no pauses).

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
just compose down && just compose up
```

## Files

| path | what |
| --- | --- |
| `Dockerfiles/keycloak/Dockerfile` | Two-stage build that pre-imports the realm into Keycloak's H2 db |
| `Dockerfiles/keycloak/realm-export.template.json` | Single source of truth for the realm (gomplate-templated) |
| `docker-compose/docker-compose.yml` | Service definitions |
| `docker-compose/haproxy/haproxy.cfg` | Edge routing rules |
| `docker-compose/oauth2-proxy/oauth2-proxy.cfg` | oauth2-proxy config (secrets via env) |
| `docker-compose/nginx/default.conf`, `docker-compose/nginx/html/*` | Protected landing pages |
| `helm/oauth2-keycloak/` | Helm chart (Keycloak + oauth2-proxy + nginx + Ingress) |
| `justfile` | Top-level recipes (test-compose, test-helm, cookie-secret) + `mod` imports for compose/helm/tests |
| `tests/auth.spec.ts` | Playwright login-flow test |

## Helm / Kubernetes

```sh
just helm up           # ensures ingress-nginx, then helm upgrade --install
just helm urls         # print the URLs
just test-helm         # deploy → run headed Playwright → tear down
```

Or directly:

```sh
helm install auth2-proxy ./helm/oauth2-keycloak \
    --set host=127.0.0.1
```

The chart drops the dedicated HAProxy pod and uses an `Ingress` resource
instead, so it works with `ingress-nginx` or any other Ingress controller.

See `helm/oauth2-keycloak/values.yaml` for tunables.

## Notes

- **Plain HTTP** for the demo. Behind real TLS, set `cookie_secure = true`
  in `docker-compose/oauth2-proxy/oauth2-proxy.cfg` and update
  `X-Forwarded-Proto` in `docker-compose/haproxy/haproxy.cfg` to `https`.
- The realm-export pins `redirectUris` to the exact `HOST_IP[:HOST_PORT]`
  (plus `localhost` / `127.0.0.1` for the compose stack). It is re-rendered
  by `just compose init` / by the helm chart on each install — never use
  a `http://*/oauth/callback` wildcard, which lets any host on the network
  intercept the OAuth code.
- Both the compose stack and the helm chart use a single locally-built
  Keycloak image (`Dockerfiles/keycloak/Dockerfile`, tagged
  `auth2-proxy/keycloak:local`) with `kc.sh build` pre-run and the realm
  pre-imported into the embedded H2 db, so the container starts in a few
  seconds instead of ~30s. `just build-keycloak <host> <port>` (or the
  upstream recipes `just compose init` / `just helm up` which call it)
  re-renders the realm and rebuilds the image when host/port changes.
