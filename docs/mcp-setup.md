# Driving the local site from Claude Code (MCP)

Connect a [Model Context Protocol](https://modelcontextprotocol.io) client
(Claude Code, etc.) to the local Talaxie WordPress install so you can
manage content and abilities from your AI tooling.

## What gets installed

| Component | Role |
|---|---|
| [`WordPress/mcp-adapter`](https://github.com/WordPress/mcp-adapter) | Bridges WordPress Abilities API → MCP. Exposes the `/mcp/*` REST endpoints. |
| WordPress core 6.9 Abilities API | Provides `wp_register_ability()`, `WP_Ability`, `WP_Abilities_Registry`, REST routes `/wp-abilities/v1/*` and a few core abilities. **No plugin to install** — it ships with WordPress 6.9. |
| [`talaxie-wp-core`](https://github.com/eric-lemesre/talaxie-wp-core) plugin | Adds 30 Talaxie abilities (Site, Posts, Pages, Media, Releases, Users, Plugins, Network, Audit, Generic REST proxy) and exposes them via two dedicated MCP servers (see [§ MCP servers](#mcp-servers-exposed-by-talaxie-wp-core)). |
| `talaxie-dev-app-passwords` mu-plugin | Forces application passwords ON for `http://talaxie.test` (WordPress refuses them on plain HTTP by default). |
| `WP_APPLICATION_PASSWORDS_AVAILABLE = true` constant | Same goal, set in `wp-config.php`. |
| `WP_ENVIRONMENT_TYPE = 'local'` constant | Tells WordPress this install is local. Required to expose the test-server (the prod-server is exposed everywhere). |

The whole stack is managed by `bin/bootstrap.sh` when `TALAXIE_INSTALL_MCP=true`
in `.env`. The mu-plugin and the two constants are added there too.

> **Historical note** — The standalone `WordPress/abilities-api` repo
> was a feature plugin while the API was incubated. It was **archived on
> 2026-02-05** when the API landed in WordPress 6.9 core. **Do not
> install it** alongside WP 6.9+: it would duplicate the registry.

## One-time host setup (Nginx must forward `Authorization`)

Nginx + PHP-FPM strips the `Authorization` header by default. Without this
fix, every authenticated REST call returns `HTTP 401 rest_forbidden`.

Edit your local Nginx vhost (`/etc/nginx/sites-available/talaxie.test`) and
add this line right after the `fastcgi_pass` directive:

```nginx
location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php-fpm-talaxie.sock;
    fastcgi_param HTTP_AUTHORIZATION $http_authorization;   # ← add this
    fastcgi_intercept_errors on;
}
```

Reload: `sudo nginx -t && sudo systemctl reload nginx`.

## Bootstrap with the MCP stack

In your `.env`:

```
TALAXIE_INSTALL_MCP=true
```

Then re-run the bootstrap (idempotent — clones are skipped if already present):

```bash
./bin/bootstrap.sh
```

The script clones `mcp-adapter`, installs its Composer deps, activates
it, drops the dev-only mu-plugin and adds the WordPress constant. The
Abilities API itself is provided by WordPress 6.9 core — no extra
install needed.

## Create an Application Password for Claude Code

```bash
vendor/bin/wp user application-password create admin "Claude Code MCP" \
    --porcelain --path=site-web
```

Copy the printed value (24 chars, no spaces) into your `.env`:

```
WP_ADMIN_APP_PASSWORD=...
```

## MCP servers exposed by talaxie-wp-core

The plugin registers **two MCP servers** so an operator can pick the
right surface for the situation:

| Server slug | Endpoint | Surface | Exposed when |
|---|---|---|---|
| `talaxie-mcp-prod-server` | `/wp-json/mcp/talaxie-mcp-prod-server` | 21 production-safe abilities (read + safe CRUD: posts, pages, media, releases, users-read, plugins-read, audit-list) | always |
| `talaxie-mcp-test-server` | `/wp-json/mcp/talaxie-mcp-test-server` | All 30 abilities, including destructive (`*-delete`, `users-create`, `plugins-activate`, `site-update-option`, `network/*`, `rest-call`) | only when `WP_ENVIRONMENT_TYPE` is `local` or `development` |

The third server `mcp-adapter-default-server` (shipped by the adapter)
exposes only the three meta-tools and is always present.

## Register the MCP servers in Claude Code

Compute the Basic-auth value once:

```bash
APP="$(grep '^WP_ADMIN_APP_PASSWORD=' .env | cut -d= -f2-)"
BASIC=$(echo -n "admin:${APP}" | base64 -w0)
```

**Register the prod server** (the one you want for everyday work):

```bash
claude mcp add talaxie-wp-prod \
    --transport http \
    --url http://talaxie.test/wp-json/mcp/talaxie-mcp-prod-server \
    --header "Authorization: Basic ${BASIC}"
```

**Register the test server** (full surface, for tasks that must mutate
options, plugins or users):

```bash
claude mcp add talaxie-wp-test \
    --transport http \
    --url http://talaxie.test/wp-json/mcp/talaxie-mcp-test-server \
    --header "Authorization: Basic ${BASIC}"
```

**Verify both are registered:**

```bash
claude mcp list   # talaxie-wp-prod and talaxie-wp-test should both appear
```

> Day-to-day, prefer `talaxie-wp-prod` — it mirrors what the bot would
> see in production and prevents an agent from accidentally touching a
> destructive ability. Switch to `talaxie-wp-test` only for tasks that
> demonstrably need the larger surface.

## Smoke test from the shell (independent of Claude Code)

Pick the server you want to probe (`mcp-adapter-default-server` for
the meta-tools, or `talaxie-mcp-prod-server` / `talaxie-mcp-test-server`
for the talaxie-core surface).

```bash
APP="$(grep '^WP_ADMIN_APP_PASSWORD=' .env | cut -d= -f2-)"
URL=http://talaxie.test/wp-json/mcp/talaxie-mcp-prod-server   # or any other server slug

# 1. initialize — captures the session id
SID=$(curl -sD - --user "admin:${APP}" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke","version":"0.1"}}}' \
    "$URL" \
    | awk 'tolower($1)=="mcp-session-id:" {print $2}' | tr -d '\r')

# 2. tools/list using that session
curl -s --user "admin:${APP}" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -H "Mcp-Session-Id: ${SID}" \
    -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
    "$URL" | jq .

# 3. tools/call site-get-info
curl -s --user "admin:${APP}" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -H "Mcp-Session-Id: ${SID}" \
    -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"talaxie-core-site-get-info","arguments":{}}}' \
    "$URL" | jq .
```

On the **prod server**, `tools/list` returns 21 entries (see the
catalogue below). On the **test server**, it returns 30. On
`mcp-adapter-default-server`, it returns the three meta-tools.

> Note on tool naming: the adapter normalises `talaxie-core/site-get-info`
> into `talaxie-core-site-get-info` (single dash) when exposing it
> over the wire. Use the latter form in `tools/call` payloads.

## What does Claude Code see, exactly?

The default server exposes the three **meta-tools** shipped by
`mcp-adapter`:

| Tool | What it does |
|---|---|
| `mcp-adapter-discover-abilities` | Returns the catalog of registered abilities. |
| `mcp-adapter-get-ability-info` | Detailed schema of one ability. |
| `mcp-adapter-execute-ability` | Runs an ability by name with parameters. |

The two **talaxie servers** expose every ability *directly* as a tool
(no `execute-ability` indirection). The flat surface is easier for an
LLM to pick from, and the input schemas are visible in
`tools/list` results.

The talaxie-core ability catalogue includes:

- **Site** — `site-get-info`, `site-get-option`, `site-update-option` (test-only)
- **Posts** — `posts-list`, `posts-get`, `posts-create`, `posts-update`
- **Pages** — `pages-list`, `pages-get`, `pages-create`, `pages-update`, `pages-delete` (test-only)
- **Media** — `media-list`, `media-upload`, `media-delete` (test-only)
- **Releases** — `releases-list`, `releases-get`, `releases-create`, `releases-update`, `releases-delete` (full CRUD even on prod — releases are the bot's job)
- **Users** — `users-list`, `users-get`, `users-create` (test-only), `users-update` (test-only)
- **Plugins** — `plugins-list`, `plugins-activate` (test-only)
- **Network** — `network-create-site`, `network-delete-site` (test-only, multisite only)
- **Generic** — `rest-call` (test-only fallback to `wp/v2/*`)
- **Audit** — `audit-list`

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `401 rest_forbidden` | Nginx strips `Authorization` | Add `fastcgi_param HTTP_AUTHORIZATION $http_authorization;` to vhost |
| `401 rest_forbidden` even with the fix above | Application passwords disabled (HTTP) | Make sure the `talaxie-dev-app-passwords` mu-plugin is in `wp-content/mu-plugins/` |
| `400 Missing Mcp-Session-Id header` | Calling a method before `initialize` | Always call `initialize` first, capture `Mcp-Session-Id` from the response headers |
| `404 Not Found` on `/wp-json/mcp/talaxie-mcp-test-server` | `WP_ENVIRONMENT_TYPE` is missing or set to `production`/`staging` | Add `define( 'WP_ENVIRONMENT_TYPE', 'local' );` to `wp-config.php` (the bootstrap does this on a fresh install) |
| `tools/call` returns `permission_denied` with `required_capability: <cap>` | The `ai_bot` user (or whichever user authenticates) lacks the capability and you didn't pass `_sudo` | Generate a sudo token from *Tools > MCP Sudo* (wp-admin), or `wp talaxie mcp sudo-token --scope=<cap>`, and include it as `_sudo` in the ability `arguments` |
| Empty `tools/list` on `talaxie-mcp-prod-server` | Plugin not activated, or `wp_abilities_api_init` did not fire | `wp plugin is-active talaxie-core --path=site-web`; cycle the plugin if needed |

## Production note

The mu-plugin `talaxie-dev-app-passwords.php` is **gated on `HTTP_HOST === 'talaxie.test'`**,
so it cannot accidentally relax security in production. Even so, for a
public deployment you should use HTTPS and let WordPress's native logic
gate application passwords.

On a production install:

- `WP_ENVIRONMENT_TYPE` should be set to `production` (or simply left
  undefined — WordPress defaults to `production`). With this value the
  test server is **not** registered, so the destructive abilities are
  unreachable even if a sudo token leaks.
- Never set `TALAXIE_MCP_DEV_MODE` in `wp-config.php`. The dev-mode
  bypass disables the capability gate entirely. The plugin refuses to
  honour the constant outside `local`/`development` environments and
  shows a permanent admin notice if it sees it set anyway.
- The drift-detection endpoint (`GET
  /wp-json/talaxie-core/v1/mcp/abilities-on-server`) lets you verify
  remotely that no destructive ability has leaked onto the prod server.

## Sudo tokens — generating elevation for an agent

When an ability returns `permission_denied` with a `required_capability`
field, the calling user lacks that WordPress capability. The Talaxie
sudo flow lets a human admin issue a short-lived elevation token:

- **wp-admin** — *Tools > MCP Sudo*: pick a scope (one or more
  capabilities), set a TTL (default 15 min, max 60 min), optionally
  flag it as single-use. The cleartext token is shown **once**.
- **WP-CLI** — `wp talaxie mcp sudo-token --scope=manage_options
  --ttl=15m [--single-use]`. Print: `wp talaxie mcp sudo-list`. Revoke:
  `wp talaxie mcp sudo-revoke <id>` or `--all`.
- **REST** — `POST /wp-json/talaxie-core/v1/mcp/sudo-token` (caller
  must already hold `manage_options`).

Pass the token to the agent (or any caller) as the `_sudo` field of the
ability `arguments`:

```json
{
  "name": "talaxie-core-site-update-option",
  "arguments": {
    "name": "blogname",
    "value": "Updated",
    "_sudo": "tlx_sudo_<32-chars>"
  }
}
```

Every elevation is recorded in the audit CPT
(`talaxie_mcp_audit`), retrievable via the `talaxie-core-audit-list`
ability or directly under *Tools > MCP audit* in wp-admin.
