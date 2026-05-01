# Driving the local site from Claude Code (MCP)

Connect a [Model Context Protocol](https://modelcontextprotocol.io) client
(Claude Code, etc.) to the local Talaxie WordPress install so you can
manage content and abilities from your AI tooling.

## What gets installed

| Component | Role |
|---|---|
| [`WordPress/mcp-adapter`](https://github.com/WordPress/mcp-adapter) | Bridges WordPress Abilities API → MCP. Exposes the `/mcp/*` REST endpoints. |
| [`WordPress/abilities-api`](https://github.com/WordPress/abilities-api) | Defines the Abilities API and a few core abilities (`core/get-site-info`, etc.). |
| `talaxie-dev-app-passwords` mu-plugin | Forces application passwords ON for `http://talaxie.test` (WordPress refuses them on plain HTTP by default). |
| `WP_APPLICATION_PASSWORDS_AVAILABLE = true` constant | Same goal, set in `wp-config.php`. |

All three are managed by `bin/bootstrap.sh` when `TALAXIE_INSTALL_MCP=true`
in `.env`.

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

The script clones both repos, installs Composer deps, activates the
plugins, drops the dev-only mu-plugin and adds the WordPress constant.

## Create an Application Password for Claude Code

```bash
vendor/bin/wp user application-password create admin "Claude Code MCP" \
    --porcelain --path=site-web
```

Copy the printed value (24 chars, no spaces) into your `.env`:

```
WP_ADMIN_APP_PASSWORD=...
```

## Register the MCP server in Claude Code

Compute the Basic-auth value and run the `claude mcp add` command:

```bash
APP="$(grep '^WP_ADMIN_APP_PASSWORD=' .env | cut -d= -f2-)"
BASIC=$(echo -n "admin:${APP}" | base64 -w0)

claude mcp add talaxie-wp \
    --transport http \
    --url http://talaxie.test/wp-json/mcp/mcp-adapter-default-server \
    --header "Authorization: Basic ${BASIC}"
```

Verify it's registered:

```bash
claude mcp list   # talaxie-wp should appear and be marked connected
```

## Smoke test from the shell (independent of Claude Code)

```bash
APP="$(grep '^WP_ADMIN_APP_PASSWORD=' .env | cut -d= -f2-)"

# 1. initialize — captures the session id
SID=$(curl -sD - --user "admin:${APP}" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke","version":"0.1"}}}' \
    http://talaxie.test/wp-json/mcp/mcp-adapter-default-server \
    | awk 'tolower($1)=="mcp-session-id:" {print $2}' | tr -d '\r')

# 2. tools/list using that session
curl -s --user "admin:${APP}" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -H "Mcp-Session-Id: ${SID}" \
    -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
    http://talaxie.test/wp-json/mcp/mcp-adapter-default-server | jq .
```

You should see three tools: `mcp-adapter-discover-abilities`,
`mcp-adapter-get-ability-info`, `mcp-adapter-execute-ability`.

## What does Claude Code see, exactly?

The MCP adapter exposes only **three meta-tools**, on purpose:

| Tool | What it does |
|---|---|
| `mcp-adapter-discover-abilities` | Returns the catalog of registered abilities (e.g. `core/get-site-info`, `core/get-user-info`). |
| `mcp-adapter-get-ability-info` | Detailed schema of one ability. |
| `mcp-adapter-execute-ability` | Runs an ability by name with parameters. |

Claude calls `discover` once, then `execute` for whatever it needs. Adding
new abilities (via `talaxie-wp-core` or other plugins) makes them
immediately available without re-registering anything in Claude Code.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `401 rest_forbidden` | Nginx strips `Authorization` | Add `fastcgi_param HTTP_AUTHORIZATION $http_authorization;` to vhost |
| `401 rest_forbidden` even with the fix above | Application passwords disabled (HTTP) | Make sure the `talaxie-dev-app-passwords` mu-plugin is in `wp-content/mu-plugins/` |
| `400 Missing Mcp-Session-Id header` | Calling a method before `initialize` | Always call `initialize` first, capture `Mcp-Session-Id` from the response headers |
| Empty `tools/list` | No ability registered | Make sure `abilities-api` is **active** (it ships a few core abilities) |

## Production note

The mu-plugin `talaxie-dev-app-passwords.php` is **gated on `HTTP_HOST === 'talaxie.test'`**,
so it cannot accidentally relax security in production. Even so, for a
public deployment you should use HTTPS and let WordPress's native logic
gate application passwords.
