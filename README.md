# Deploy and Host OpenWA

Open source WhatsApp API gateway — self-host the messaging layer: session
management, Webhooks, automations, and a React dashboard, in one container.
MIT-licensed, actively developed (rmyndharis/OpenWA, 15k+ stars, 2026-10).

[![Deploy to Railway](https://railway.app/button.svg)](https://railway.com/deploy/jX4IUa)

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
| `API_MASTER_KEY`  | *auto*       | yes      | Prefilled via Railway's `secret()` with a fresh `owa_k1_<64-hex>` per deploy. Overwrite with your own 32+ char value to use it verbatim. Only taken on first boot. |
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

OpenWA uses a single **API key** as the admin credential — there is no
separate username/password.

**Default (no action needed):** the deploy form prefills `API_MASTER_KEY`
with a unique `owa_k1_<64-hex>` key generated by Railway's `secret()`
function — a fresh, random key for every deployment. On first boot OpenWA
seeds that exact value as the default ADMIN key (plus a fallback random
one if it was left blank). Read your key from:

- **the project's Variables tab** (`API_MASTER_KEY`, unsealed — copy it
  before you close the deploy form, or any time afterwards),
- the first-boot service logs (key printed once on the first boot only):
  `railway logs 2>&1 | grep -oE "owa_k1_[a-f0-9]{64}"`,
- inside the container, persisted on the volume:
  `/app/data/.api-key` (`railway ssh -- "cat /app/data/.api-key"`).

**Prefer your own key:** overwrite `API_MASTER_KEY` in the deploy form
with any value of 32+ characters — OpenWA seeds *that exact value* as the
default ADMIN key on first boot instead.

In all cases the key is only taken in on the very first boot (empty key
table); after that, OpenWA stores only a hash + key prefix.

**Dashboard URL**: `https://<your-service>.up.railway.app` (the Railway
public domain, set automatically on deploy). In the dashboard login field,
paste the API key — there is **no username field**.

> Rotate by minting a new key in the dashboard and revoking the old one.

## Quick Start

1. **Deploy** — the form pre-fills `NODE_ENV`, `PORT`, `TZ`, `DATABASE_TYPE`;
   the `openwa-data` volume is created for you.
2. **Grab your admin API key** — the deploy form already holds a unique
   `API_MASTER_KEY` value (auto-generated per deployment). Copy it from the
   project's **Variables** tab (or first-boot logs:
   `railway logs 2>&1 | grep -oE "owa_k1_[a-f0-9]{64}"`).
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
