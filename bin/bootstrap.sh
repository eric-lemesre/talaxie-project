#!/usr/bin/env bash
# =============================================================================
# Talaxie — Bootstrap local dev environment
# =============================================================================
#
# One-command setup of a working WordPress install in site-web/:
#   - pre-flight checks (PHP 8.1+, Composer, MySQL/MariaDB client)
#   - composer install (downloads WordPress core + wp-cli)
#   - ensures database exists (creates it via DB_ROOT_* credentials if given,
#     otherwise prints SQL commands to run manually as root)
#   - generates wp-config.php with project conventions
#   - runs `wp core install` non-interactively
#
# Requirements: PHP 8.1+, Composer, MariaDB/MySQL client + server, bash 4+.
# Targets Linux/macOS (Windows users: use WSL).
#
# Usage:
#   ./bin/bootstrap.sh
#   composer bootstrap
#
# Idempotent: safe to re-run. Existing wp-config.php and installed WordPress
# are preserved; only missing pieces are created.
# =============================================================================

set -euo pipefail

# ----- Colors & logging ------------------------------------------------------

if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''
fi

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_phase() { echo -e "\n${BOLD}${CYAN}==> $*${NC}"; }

# ----- Paths -----------------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ENV_FILE="${REPO_ROOT}/.env"
WP_DIR="${REPO_ROOT}/site-web"
WP_CONFIG="${WP_DIR}/wp-config.php"
WP_BIN="${REPO_ROOT}/vendor/bin/wp"

# ----- Phase 0 — Pre-flight --------------------------------------------------

phase_preflight() {
    log_phase "Phase 0 — Pre-flight checks"

    case "$(uname -s)" in
        Linux|Darwin) log_ok "OS supported: $(uname -s)" ;;
        *)
            log_error "Unsupported OS: $(uname -s). This script targets Linux/macOS."
            exit 1
            ;;
    esac

    if ! command -v php >/dev/null 2>&1; then
        log_error "PHP not found. Install PHP 8.1 or higher."
        exit 1
    fi
    local php_ver
    php_ver=$(php -r 'echo PHP_VERSION;')
    if ! php -r 'exit(version_compare(PHP_VERSION, "8.1", ">=") ? 0 : 1);'; then
        log_error "PHP 8.1+ required, found ${php_ver}."
        exit 1
    fi
    log_ok "PHP ${php_ver}"

    if ! command -v composer >/dev/null 2>&1; then
        log_error "Composer not found."
        log_info "Quick install (Linux/macOS):"
        echo "    php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\""
        echo "    sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer"
        echo "    php -r \"unlink('composer-setup.php');\""
        exit 1
    fi
    log_ok "Composer $(composer --version --no-ansi 2>/dev/null | awk '{print $3}')"

    if ! command -v mysql >/dev/null 2>&1 && ! command -v mariadb >/dev/null 2>&1; then
        log_error "mysql/mariadb client not found."
        exit 1
    fi
    log_ok "MySQL/MariaDB client present"

    if [[ ! -f "$ENV_FILE" ]]; then
        log_error ".env not found at $ENV_FILE"
        log_info "Copy the template and fill in values:"
        echo "    cp .env.example .env"
        echo "    \$EDITOR .env"
        exit 1
    fi
    log_ok ".env found"
}

# ----- Phase 1 — Load .env ---------------------------------------------------

phase_load_env() {
    log_phase "Phase 1 — Load .env"

    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a

    local required=(
        WP_HOME WP_SITEURL WP_TITLE WP_LOCALE
        WP_ADMIN_USER WP_ADMIN_PASSWORD WP_ADMIN_EMAIL
        WP_TABLE_PREFIX
        DB_NAME DB_USER DB_PASSWORD DB_HOST DB_CHARSET DB_COLLATE
    )
    local missing=()
    for var in "${required[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing+=("$var")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing variables in .env: ${missing[*]}"
        exit 1
    fi

    if [[ "$WP_ADMIN_PASSWORD" == "changeme" || "$DB_PASSWORD" == "changeme" ]]; then
        log_warn "Default 'changeme' password detected — fine for local dev, but please change it."
    fi

    log_ok "Configuration loaded"
}

# ----- Phase 2 — Composer install --------------------------------------------

phase_composer_install() {
    log_phase "Phase 2 — Composer install"

    composer install --no-interaction --prefer-dist
    log_ok "Composer dependencies installed"

    if [[ ! -x "$WP_BIN" ]]; then
        log_error "wp-cli not found at $WP_BIN after composer install."
        exit 1
    fi
}

# ----- Phase 3 — Database ----------------------------------------------------

phase_database() {
    log_phase "Phase 3 — Database"

    if [[ -n "${DB_ROOT_PASSWORD:-}" ]]; then
        local root_user="${DB_ROOT_USER:-root}"
        log_info "Creating database and user via root credentials..."
        mysql -u"${root_user}" -p"${DB_ROOT_PASSWORD}" -h"${DB_HOST}" <<EOSQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
    DEFAULT CHARACTER SET ${DB_CHARSET}
    COLLATE ${DB_COLLATE};
CREATE USER IF NOT EXISTS '${DB_USER}'@'${DB_HOST}' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'${DB_HOST}';
FLUSH PRIVILEGES;
EOSQL
        log_ok "Database ${DB_NAME} and user ${DB_USER} ensured"
        return 0
    fi

    if mysql -u"${DB_USER}" -p"${DB_PASSWORD}" -h"${DB_HOST}" -e "USE \`${DB_NAME}\`;" 2>/dev/null; then
        log_ok "Connection to ${DB_NAME} verified"
        return 0
    fi

    log_error "Cannot connect as ${DB_USER}@${DB_HOST} to ${DB_NAME}."
    log_info "Either set DB_ROOT_USER/DB_ROOT_PASSWORD in .env to let this script create the DB,"
    log_info "or run these commands as root:"
    echo ""
    echo "    CREATE DATABASE \`${DB_NAME}\` CHARACTER SET ${DB_CHARSET} COLLATE ${DB_COLLATE};"
    echo "    CREATE USER '${DB_USER}'@'${DB_HOST}' IDENTIFIED BY '${DB_PASSWORD}';"
    echo "    GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'${DB_HOST}';"
    echo "    FLUSH PRIVILEGES;"
    echo ""
    exit 1
}

# ----- Phase 4 — wp-config.php -----------------------------------------------

phase_wp_config() {
    log_phase "Phase 4 — wp-config.php"

    if [[ -f "$WP_CONFIG" ]]; then
        log_info "wp-config.php already exists, skipping generation."
        return 0
    fi

    local extra_php
    extra_php=$(cat <<EOF
define( 'WP_HOME', '${WP_HOME}' );
define( 'WP_SITEURL', '${WP_SITEURL}' );
define( 'WP_DEBUG', ${WP_DEBUG:-false} );
define( 'WP_DEBUG_LOG', true );
define( 'WP_DEBUG_DISPLAY', false );
define( 'DISALLOW_FILE_EDIT', true );
EOF
)

    "$WP_BIN" config create \
        --path="$WP_DIR" \
        --dbname="$DB_NAME" \
        --dbuser="$DB_USER" \
        --dbpass="$DB_PASSWORD" \
        --dbhost="$DB_HOST" \
        --dbcharset="$DB_CHARSET" \
        --dbcollate="$DB_COLLATE" \
        --dbprefix="$WP_TABLE_PREFIX" \
        --locale="$WP_LOCALE" \
        --extra-php <<<"$extra_php"

    log_ok "wp-config.php generated"
}

# ----- Phase 5 — WordPress install -------------------------------------------

phase_wp_install() {
    log_phase "Phase 5 — WordPress install"

    if "$WP_BIN" core is-installed --path="$WP_DIR" 2>/dev/null; then
        log_info "WordPress already installed, skipping."
        return 0
    fi

    "$WP_BIN" core install \
        --path="$WP_DIR" \
        --url="$WP_HOME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email

    log_ok "WordPress installed"
}

# ----- Phase 6 — Clone theme & plugin repos ----------------------------------

phase_clone_components() {
    log_phase "Phase 6 — Clone Talaxie theme & plugin"

    local theme_repo="${TALAXIE_THEME_REPO:-git@github.com:eric-lemesre/talaxie-wp-theme.git}"
    local theme_dir="${WP_DIR}/wp-content/themes/talaxie"
    local core_repo="${TALAXIE_CORE_REPO:-git@github.com:eric-lemesre/talaxie-wp-core.git}"
    local core_dir="${WP_DIR}/wp-content/plugins/talaxie-core"

    # Theme
    if [[ -d "$theme_dir/.git" ]]; then
        log_info "Theme already cloned at ${theme_dir}, skipping."
    else
        log_info "Cloning theme from ${theme_repo}..."
        git clone "$theme_repo" "$theme_dir"
        log_ok "Theme cloned"
    fi
    if [[ -f "$theme_dir/composer.json" ]]; then
        log_info "Installing theme dev dependencies..."
        ( cd "$theme_dir" && composer install --no-interaction --prefer-dist --no-progress )
        log_ok "Theme dependencies installed"
    fi

    # Plugin
    if [[ -d "$core_dir/.git" ]]; then
        log_info "Plugin already cloned at ${core_dir}, skipping."
    else
        log_info "Cloning plugin from ${core_repo}..."
        git clone "$core_repo" "$core_dir"
        log_ok "Plugin cloned"
    fi
    if [[ -f "$core_dir/composer.json" ]]; then
        log_info "Installing plugin runtime dependencies..."
        ( cd "$core_dir" && composer install --no-interaction --prefer-dist --no-progress )
        log_ok "Plugin dependencies installed"
    fi
}

# ----- Phase 7 — Activate theme & plugin -------------------------------------

phase_activate_components() {
    log_phase "Phase 7 — Activate Talaxie theme & plugin"

    if [[ -d "${WP_DIR}/wp-content/themes/talaxie" ]]; then
        if "$WP_BIN" theme activate talaxie --path="$WP_DIR" >/dev/null 2>&1; then
            log_ok "Theme 'talaxie' activated"
        else
            log_warn "Could not activate theme 'talaxie' — check vendor/ and theme.json"
        fi
    fi

    if [[ -d "${WP_DIR}/wp-content/plugins/talaxie-core" ]]; then
        if "$WP_BIN" plugin activate talaxie-core --path="$WP_DIR" >/dev/null 2>&1; then
            log_ok "Plugin 'talaxie-core' activated"
        else
            log_warn "Could not activate plugin 'talaxie-core' — check vendor/autoload.php"
        fi
    fi
}

# ----- Phase 8 — MCP setup (optional) ----------------------------------------

phase_mcp_setup() {
    if [[ "${TALAXIE_INSTALL_MCP:-false}" != "true" ]]; then
        return 0
    fi

    log_phase "Phase 8 — MCP setup (mcp-adapter + abilities-api)"

    local plugins_dir="${WP_DIR}/wp-content/plugins"
    local mu_dir="${WP_DIR}/wp-content/mu-plugins"

    # Clone mcp-adapter
    if [[ -d "${plugins_dir}/mcp-adapter/.git" ]]; then
        log_info "mcp-adapter already cloned, skipping."
    else
        log_info "Cloning WordPress/mcp-adapter..."
        git clone --depth=1 https://github.com/WordPress/mcp-adapter.git "${plugins_dir}/mcp-adapter"
        log_ok "mcp-adapter cloned"
    fi
    if [[ -f "${plugins_dir}/mcp-adapter/composer.json" ]]; then
        ( cd "${plugins_dir}/mcp-adapter" && composer install --no-dev --no-interaction --prefer-dist --no-progress )
        log_ok "mcp-adapter dependencies installed"
    fi

    # Clone abilities-api
    if [[ -d "${plugins_dir}/abilities-api/.git" ]]; then
        log_info "abilities-api already cloned, skipping."
    else
        log_info "Cloning WordPress/abilities-api..."
        git clone --depth=1 https://github.com/WordPress/abilities-api.git "${plugins_dir}/abilities-api"
        log_ok "abilities-api cloned"
    fi
    if [[ -f "${plugins_dir}/abilities-api/composer.json" ]]; then
        ( cd "${plugins_dir}/abilities-api" && composer install --no-dev --no-interaction --prefer-dist --no-progress )
        log_ok "abilities-api dependencies installed"
    fi

    # Activate both plugins
    if "$WP_BIN" plugin activate abilities-api --path="$WP_DIR" >/dev/null 2>&1; then
        log_ok "abilities-api activated"
    else
        log_warn "abilities-api activation issue"
    fi
    if "$WP_BIN" plugin activate mcp-adapter --path="$WP_DIR" >/dev/null 2>&1; then
        log_ok "mcp-adapter activated"
    else
        log_warn "mcp-adapter activation issue"
    fi

    # Local-dev mu-plugin: force application passwords ON for talaxie.test (HTTP).
    mkdir -p "$mu_dir"
    local mu_file="${mu_dir}/talaxie-dev-app-passwords.php"
    if [[ ! -f "$mu_file" ]]; then
        cat > "$mu_file" <<'MUEOF'
<?php
/**
 * Plugin Name: Talaxie Dev — Force Application Passwords
 * Description: Forces application passwords ON for the local HTTP dev site (talaxie.test). DO NOT USE IN PRODUCTION.
 * Version: 0.1.0
 *
 * @package Talaxie\Dev
 */

defined( 'ABSPATH' ) || exit;

if ( isset( $_SERVER['HTTP_HOST'] ) && $_SERVER['HTTP_HOST'] === 'talaxie.test' ) {
    add_filter( 'wp_is_application_passwords_available', '__return_true' );
    add_filter( 'wp_is_application_passwords_available_for_user', '__return_true' );
}
MUEOF
        log_ok "mu-plugin talaxie-dev-app-passwords created"
    fi

    # Ensure WP_APPLICATION_PASSWORDS_AVAILABLE is defined in wp-config.php.
    if ! "$WP_BIN" config has WP_APPLICATION_PASSWORDS_AVAILABLE --type=constant --path="$WP_DIR" >/dev/null 2>&1; then
        "$WP_BIN" config set WP_APPLICATION_PASSWORDS_AVAILABLE true --type=constant --raw --path="$WP_DIR" >/dev/null
        log_ok "WP_APPLICATION_PASSWORDS_AVAILABLE constant added to wp-config.php"
    fi

    echo ""
    log_info "Next manual step: create an Application Password for the admin and connect Claude Code."
    log_info "  vendor/bin/wp user application-password create admin 'Claude Code MCP' --porcelain --path=site-web"
    log_info "  Then add it to .env as WP_ADMIN_APP_PASSWORD=..."
    log_info "  Compute Basic auth: echo -n 'admin:<password>' | base64 -w0"
    log_info "  Register in Claude Code:"
    log_info "    claude mcp add talaxie-wp --transport http \\"
    log_info "        --url http://talaxie.test/wp-json/mcp/mcp-adapter-default-server \\"
    log_info "        --header 'Authorization: Basic <base64>'"
    log_info ""
    log_info "Note: Nginx vhost must forward HTTP_AUTHORIZATION to PHP-FPM. See docs/mcp-setup.md."
}

# ----- Phase 9 — Summary -----------------------------------------------------

phase_summary() {
    log_phase "Done"

    echo ""
    echo -e "${BOLD}=== Local environment ready ===${NC}"
    echo ""
    echo "  Site URL:      ${WP_HOME}"
    echo "  Admin URL:     ${WP_HOME}/wp-admin/"
    echo "  Admin user:    ${WP_ADMIN_USER}"
    echo "  WP path:       ${WP_DIR}"
    echo "  Theme:         site-web/wp-content/themes/talaxie/    (separate Git repo)"
    echo "  Plugin:        site-web/wp-content/plugins/talaxie-core/  (separate Git repo)"
    echo ""
    echo "  Useful commands:"
    echo "    composer wp <subcommand>     # run wp-cli scoped to this install"
    echo "    composer reset-db            # wipe and re-import dev DB"
    echo "    cd site-web/wp-content/themes/talaxie && git status     # work on the theme"
    echo "    cd site-web/wp-content/plugins/talaxie-core && git status  # work on the plugin"
    echo ""
}

# ----- Main ------------------------------------------------------------------

main() {
    phase_preflight
    phase_load_env
    phase_composer_install
    phase_database
    phase_wp_config
    phase_wp_install
    phase_clone_components
    phase_activate_components
    phase_mcp_setup
    phase_summary
}

main "$@"
