#!/usr/bin/env bash
# =============================================================================
# Talaxie — Reset local development database
# =============================================================================
#
# Drops all WordPress tables in the local dev database and reinstalls
# WordPress from scratch using the values defined in .env. Useful when
# the dev DB is in an inconsistent state or you want a clean slate.
#
# Requires bin/bootstrap.sh to have been run at least once (vendor/bin/wp
# must exist, and the DB user must have privileges on the target database).
#
# Usage:
#   ./bin/reset-db.sh
#   composer reset-db
#
# DESTRUCTIVE: requires interactive confirmation (type the DB name).
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
WP_BIN="${REPO_ROOT}/vendor/bin/wp"

# ----- Pre-flight ------------------------------------------------------------

if [[ ! -f "$ENV_FILE" ]]; then
    log_error ".env not found. Run bin/bootstrap.sh first."
    exit 1
fi

if [[ ! -x "$WP_BIN" ]]; then
    log_error "wp-cli not found at $WP_BIN. Run bin/bootstrap.sh first."
    exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# ----- Confirmation ----------------------------------------------------------

log_phase "Reset local development database"
log_warn "This will DROP all tables in '${DB_NAME}' and reinstall WordPress."
log_warn "All site content, users, and settings will be LOST."
echo ""
read -r -p "Type the database name to confirm (${DB_NAME}): " confirm
if [[ "$confirm" != "$DB_NAME" ]]; then
    log_error "Confirmation mismatch. Aborted."
    exit 1
fi

# ----- Drop tables -----------------------------------------------------------

log_phase "Dropping all tables"
"$WP_BIN" db reset --yes --path="$WP_DIR"
log_ok "Tables dropped"

# ----- Reinstall WordPress ---------------------------------------------------

log_phase "Reinstalling WordPress"
"$WP_BIN" core install \
    --path="$WP_DIR" \
    --url="$WP_HOME" \
    --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN_USER" \
    --admin_password="$WP_ADMIN_PASSWORD" \
    --admin_email="$WP_ADMIN_EMAIL" \
    --skip-email
log_ok "WordPress reinstalled"

# ----- Re-activate default theme (best-effort) -------------------------------

if "$WP_BIN" theme is-installed twentytwentyfive --path="$WP_DIR" 2>/dev/null; then
    "$WP_BIN" theme activate twentytwentyfive --path="$WP_DIR" >/dev/null 2>&1 || true
    log_ok "Default theme activated"
fi

# ----- Summary ---------------------------------------------------------------

log_phase "Done"
echo ""
echo "  Site URL:  ${WP_HOME}"
echo "  Admin URL: ${WP_HOME}/wp-admin/"
echo "  Login:     ${WP_ADMIN_USER}"
echo ""
