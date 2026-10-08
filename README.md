# Deploy and Host OpenWA

Open source WhatsApp API gateway — self-host the messaging layer: session
management, Webhooks, automations, and a React dashboard, in one container.
MIT-licensed, actively developed (rmyndharis/OpenWA, 15k+ stars, 2026-10).

[![Deploy to Railway](https://railway.app/button.svg)](https://railway.com/deploy/openwa)

## Dependencies for OpenWA

One service, one volume. No sidecar required for a standard deploy — the
SQLite database and all session state live on the `openwa-data` volume at
`/app/data`.

| Variable          | Default      | Optional | Notes                                                                                              |
|-------------------|--------------|----------|----------------------------------------------------------------------------------------------------|
| `NODE_ENV`        | `production` | yes      | Runtime mode; keep production.                                                                       |
| `PORT`            | `2785`       | yes      | Single port for dashboard, REST API (`/api/*`), and Swagger (`/api/docs` when enabled).             |
| `TZ`              | `UTC`        | yes      | Timezone for logs and the "today" stats rollup.                                                      |
| `DATABASE_TYPE`   | `sqlite`     | yes      | `sqlite` (zero-config, on the volume) or `postgres` (+ `DATABASE_HOST/PORT/USERNAME/PASSWORD`, e.g. a sibling Postgres service). |
| `API_KEY_PEPPER`  | *(blank)*    | yes      | Optional HMAC pepper for API-key hashing. Set before first boot if at all — enabling later locks out existing keys. |
| `BASE_URL`        | *(blank)*    | yes      | Public URL of the instance for outbound payloads/callbacks.                                          |
| `ENABLE_SWAGGER`  | *(blank)*    | yes      | `true` = interactive docs at `/api/docs`. Leave off on a public domain.                              |
| `AUTO_START_SESSIONS` | *(blank)* | yes     | `true` = auto-reconnect paired WhatsApp sessions on boot.                                            |

### Deployment Dependencies

- One service (the bundled gateway: NestJS API + React dashboard + WhatsApp
  session engine, all in a single image).
- One volume mounted at `/app/data` (Railway volume) — SQLite DB, WhatsApp
  session profiles, media, plugins.
- Optional: a Postgres service as a sibling if you prefer a database over
  SQLite.

## About Hosting

OpenWA ships as one hardened container (Node 22 + Puppeteer/Chromium for the
whatsapp-web.js engine, ffmpeg, and the React dashboard bundled and served by
the same NestJS process on a single port). The upstream `docker-entrypoint.sh`
handles privilege handoff to the non-root `openwa` user and pre-creates the
data directories — the template's `Dockerfile` only layers on the
`HEALTHCHECK` (pointed at `/api/health/ready`, the same route the upstream's
own compose file uses) and the `EXPOSE`.

Deployment surface:

- **Service `openwa`** — listens on `2785`; REST API at `/api/*`; dashboard at
  `/`; Swagger at `/api/docs` (when `ENABLE_SWAGGER=true`); metrics at
  `/api/metrics`; health at `/api/health` (`live` / `ready`).
- **Volume `openwa-data`** — mounted at `/app/data`; SQLite DB, WhatsApp
  session profiles, plugin state, media cache.

## Why Deploy

- **One container, one port, one volume** — API, dashboard, and WhatsApp
  session engine bundled into a single image; no separate dashboard service,
  no required DB.
- **Full API + Webhooks** — every action available as a REST call under
  `/api/*` and as signed Webhook events; pair it with n8n, a bot, or any
  HTTP client.
- **MCP server inside** — opt-in Model-Context-Protocol tools (`MCP_ENABLED=true`)
  so AI agents can drive WhatsApp through standard tool calls.
- **Multi-session, multi-role keys** — admin/operator/viewer API keys with
  per-session scoping, all managed from the dashboard.
- **SQLite or Postgres** — start with zero-config SQLite on the volume,
  graduate to Postgres without code changes.
- **MIT-licensed, trending fast** — 15k+ stars, active 2026-09/10 releases.

## Common Use Cases

- **Self-hosted WhatsApp backend** for your customer bots and notification
  pipelines.
- **n8n / agent glue** — pair the REST or MCP API with a workflow runner so
  WhatsApp messages become triggers and destinations.
- **Business inbox** — multi-session gateway for a team, with role-scoped
  API keys per member.
- **Automations** — auto-reply rules, webhook fanout, group ops, contact
  management, all managed from the React dashboard or the API.

## Login / Initial Access

OpenWA generates a single **admin API key** on first boot. It is the only
credential — there is no separate username/password.

- **Dashboard URL**: `https://<your-service>.up.railway.app` (your Railway
  public domain, set automatically on deploy)
- **Credentials**: `X-API-Key: owa_k1_<64-char-hex>` — no username field
- **How to find your key** (first boot only):
  ```bash
  railway logs 2>&1 | grep "Admin API key"
  # or
  railway logs 2>&1 | grep -oE "owa_k1_[a-f0-9]{64}"
  ```
  The key is also persisted at `/app/data/.api-key` inside the container —
  read it from the volume if the initial log line scrolled past:
  ```bash
  railway ssh -- "cat /app/data/.api-key"
  ```
- Use the same key to "Sign in" in the React dashboard UI (paste into the
  API key field — no username required).

## Quick Start

1. **Deploy** — the form pre-fills `NODE_ENV`, `PORT`, `TZ`, `DATABASE_TYPE`;
   the `openwa-data` volume is created for you.
2. **Grab your admin API key** — the first boot generates one and **prints it
   once in the service logs**. Copy it before the container restarts.
   (Also available: `railway ssh -- "cat /app/data/.api-key"`.)
3. **Open the dashboard** at your up.railway.app domain — sign in with the
   admin API key.
4. **Create a session** (dashboard or `POST /api/sessions`) → **start it** →
   **scan the QR** with WhatsApp on your phone.
5. **Send your first message** from the API:

   ```bash
   curl -X POST https://YOUR-HOST/api/sessions/{id}/messages/send-text \
     -H "Content-Type: application/json" \
     -H "X-API-Key: ***" \
     -d '{"chatId": "15551234567@c.us", "text": "Hello from OpenWA"}'
   ```
6. **Wire Webhooks or MCP** for inbound events — see the API docs at
   `/api/docs` (enable `ENABLE_SWAGGER=true` first if not already on).

> OpenWA is an **unofficial** WhatsApp gateway and carries the usual
> account-risk caveats of third-party WhatsApp clients. Use a dedicated
> number for bots; see the upstream README's "Before you connect a number"
> guidance.
