#!/bin/bash
# =============================================================================
# Talaxie — Script de migration OVH mutualisé vers VPS
# =============================================================================
#
# Ce script migre le site WordPress talaxie.org et le bot Discord Talaxie
# depuis un hébergement mutualisé OVH vers un VPS OVH autonome.
#
# Pré-requis : les fichiers du projet doivent être transférés sur le VPS dans
# /tmp/talaxie-migration/ AVANT l'exécution de ce script :
#
#   rsync -avz --exclude='.venv' --exclude='__pycache__' \
#       Talaxie-Project/ root@NEW_VPS_IP:/tmp/talaxie-migration/
#
# Usage :
#   sudo bash migrate-to-vps.sh [OPTIONS]
#
# Options :
#   --dry-run         Affiche les actions sans les exécuter
#   --skip-phase=N    Saute la phase N (0-5), répétable
#   --help            Affiche cette aide
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Variables configurables
# =============================================================================

DOMAIN="talaxie.org"
DB_NAME="talaxiu48"
DB_USER="talaxiu48"
TABLE_PREFIX="mod270_"

STAGING_DIR="/tmp/talaxie-migration"
WEB_ROOT="/var/www/${DOMAIN}"
BOT_DIR="/opt/talaxie-bot"
BOT_USER="talaxie"

PHP_VERSION="8.2"

# Collation MySQL 8 à remplacer dans le dump
MYSQL8_COLLATION="utf8mb4_0900_ai_ci"
MARIADB_COLLATION="utf8mb4_unicode_520_ci"

# Espace disque minimum requis (en Ko) — 2 Go
MIN_DISK_KB=2097152

# =============================================================================
# Couleurs et logging
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

LOG_FILE="/var/log/talaxie-migration-$(date +%Y%m%d-%H%M%S).log"

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*" | tee -a "$LOG_FILE"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*" | tee -a "$LOG_FILE"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"; }
log_phase() { echo -e "\n${BOLD}${CYAN}========== $* ==========${NC}\n" | tee -a "$LOG_FILE"; }

# =============================================================================
# Trap et nettoyage
# =============================================================================

cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Le script a échoué (code $exit_code). Consultez le log : $LOG_FILE"
    fi
}
trap cleanup EXIT

# =============================================================================
# Parsing des arguments
# =============================================================================

DRY_RUN=false
declare -A SKIP_PHASES=()

show_help() {
    sed -n '/^# Usage/,/^# ====/p' "$0" | grep -v '^# ====' | sed 's/^# //'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-phase=*)
            phase="${1#--skip-phase=}"
            SKIP_PHASES[$phase]=1
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            log_error "Option inconnue : $1"
            echo "Utilisez --help pour voir les options disponibles."
            exit 1
            ;;
    esac
done

# Wrapper dry-run : exécute la commande ou l'affiche
run() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} $*" | tee -a "$LOG_FILE"
    else
        "$@"
    fi
}

should_skip() {
    [[ -v "SKIP_PHASES[$1]" ]]
}

# =============================================================================
# Phase 0 : Pre-flight checks
# =============================================================================

phase0_preflight() {
    log_phase "Phase 0 : Pre-flight checks"

    # Root check
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Ce script doit être exécuté en tant que root (sudo)."
        exit 1
    fi
    log_ok "Exécution en tant que root"

    # OS check
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            debian)
                if [ "${VERSION_ID:-0}" -lt 12 ]; then
                    log_error "Debian 12+ requis (détecté : $PRETTY_NAME)"
                    exit 1
                fi
                ;;
            ubuntu)
                major="${VERSION_ID%%.*}"
                if [ "$major" -lt 22 ]; then
                    log_error "Ubuntu 22.04+ requis (détecté : $PRETTY_NAME)"
                    exit 1
                fi
                ;;
            *)
                log_warn "OS non testé : $PRETTY_NAME. Le script est prévu pour Debian 12+ / Ubuntu 22.04+."
                ;;
        esac
        log_ok "OS : $PRETTY_NAME"
    else
        log_warn "Impossible de détecter l'OS (/etc/os-release absent)."
    fi

    # Staging dir
    if [ ! -d "$STAGING_DIR" ]; then
        log_error "Répertoire de staging absent : $STAGING_DIR"
        log_error "Transférez d'abord les fichiers avec rsync."
        exit 1
    fi
    log_ok "Répertoire de staging : $STAGING_DIR"

    # Fichiers requis
    local required_files=(
        "site-web/wp-config.php"
        "site-web/talaxiu48_mysql_db.sql"
        "discord/bot/bot.py"
        "discord/bot/config.py"
        "discord/bot/requirements.txt"
        "discord/bot/.env"
        "infra/.env"
    )
    for f in "${required_files[@]}"; do
        if [ ! -f "${STAGING_DIR}/${f}" ]; then
            log_error "Fichier requis manquant : ${STAGING_DIR}/${f}"
            exit 1
        fi
    done
    log_ok "Tous les fichiers requis sont présents"

    # Espace disque
    local avail_kb
    avail_kb=$(df --output=avail / | tail -1 | tr -d ' ')
    if [ "$avail_kb" -lt "$MIN_DISK_KB" ]; then
        log_error "Espace disque insuffisant : $(( avail_kb / 1024 )) Mo disponibles, $(( MIN_DISK_KB / 1024 )) Mo requis."
        exit 1
    fi
    log_ok "Espace disque : $(( avail_kb / 1024 )) Mo disponibles"

    # Chargement du mot de passe DB depuis infra/.env
    DB_PASSWORD=$(grep '^TALAXIE_ORG_DB_PSWD=' "${STAGING_DIR}/infra/.env" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    if [ -z "$DB_PASSWORD" ]; then
        log_error "TALAXIE_ORG_DB_PSWD introuvable dans ${STAGING_DIR}/infra/.env"
        exit 1
    fi
    log_ok "Mot de passe DB chargé depuis infra/.env"

    # Auto-détection de l'IP du VPS
    VPS_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || hostname -I | awk '{print $1}')
    VPS_IPV6=$(ip -6 addr show scope global 2>/dev/null | awk '/inet6/{print $2; exit}' | cut -d'/' -f1 || true)
    log_ok "IP du VPS : ${VPS_IP}${VPS_IPV6:+ / $VPS_IPV6}"

    # Résumé
    echo ""
    echo -e "${BOLD}=== Résumé de la migration ===${NC}"
    echo -e "  Domaine        : ${CYAN}${DOMAIN}${NC}"
    echo -e "  IP VPS         : ${CYAN}${VPS_IP}${NC}"
    echo -e "  Base de données: ${CYAN}${DB_NAME}${NC}"
    echo -e "  Web root       : ${CYAN}${WEB_ROOT}${NC}"
    echo -e "  Bot dir        : ${CYAN}${BOT_DIR}${NC}"
    echo -e "  Staging        : ${CYAN}${STAGING_DIR}${NC}"
    echo -e "  Dry run        : ${CYAN}${DRY_RUN}${NC}"
    echo -e "  Log            : ${CYAN}${LOG_FILE}${NC}"
    if [ ${#SKIP_PHASES[@]} -gt 0 ]; then
        echo -e "  Phases skip    : ${CYAN}${!SKIP_PHASES[*]}${NC}"
    fi
    echo ""

    if [ "$DRY_RUN" = false ]; then
        read -r -p "Continuer la migration ? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[yYoO] ]]; then
            log_info "Migration annulée par l'utilisateur."
            exit 0
        fi
    fi
}

# =============================================================================
# Phase 1 : Setup VPS (paquets, firewall, utilisateur)
# =============================================================================

phase1_setup_vps() {
    log_phase "Phase 1 : Setup VPS"

    log_info "Mise à jour du système..."
    run apt-get update -y
    run apt-get upgrade -y

    log_info "Installation des paquets..."
    run apt-get install -y \
        nginx \
        "php${PHP_VERSION}-fpm" \
        "php${PHP_VERSION}-mysql" \
        "php${PHP_VERSION}-xml" \
        "php${PHP_VERSION}-mbstring" \
        "php${PHP_VERSION}-curl" \
        "php${PHP_VERSION}-gd" \
        "php${PHP_VERSION}-zip" \
        "php${PHP_VERSION}-intl" \
        "php${PHP_VERSION}-imagick" \
        "php${PHP_VERSION}-opcache" \
        mariadb-server \
        python3 \
        python3-venv \
        certbot \
        python3-certbot-nginx \
        ufw \
        curl \
        rsync
    log_ok "Paquets installés"

    log_info "Configuration du firewall (UFW)..."
    run ufw allow OpenSSH
    run ufw allow 'Nginx Full'
    if [ "$DRY_RUN" = false ]; then
        echo "y" | ufw enable || true
    else
        echo -e "  ${YELLOW}[DRY-RUN]${NC} ufw enable"
    fi
    log_ok "UFW configuré (SSH, HTTP, HTTPS)"

    log_info "Création de l'utilisateur système ${BOT_USER}..."
    if ! id "$BOT_USER" &>/dev/null; then
        run useradd --system --no-create-home --shell /usr/sbin/nologin "$BOT_USER"
        log_ok "Utilisateur ${BOT_USER} créé"
    else
        log_ok "Utilisateur ${BOT_USER} existe déjà"
    fi
}

# =============================================================================
# Phase 2 : MariaDB (base de données)
# =============================================================================

phase2_mysql() {
    log_phase "Phase 2 : MariaDB"

    log_info "Démarrage de MariaDB..."
    run systemctl enable mariadb
    run systemctl start mariadb

    # Génération d'un mot de passe root aléatoire
    MYSQL_ROOT_PWD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)

    if [ "$DRY_RUN" = false ]; then
        log_info "Sécurisation de MariaDB..."

        # Configuration root
        mysql -u root <<-EOSQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PWD}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOSQL

        # Sauvegarde des credentials root
        cat > /root/.my.cnf <<-EOF
[client]
user=root
password=${MYSQL_ROOT_PWD}
EOF
        chmod 600 /root/.my.cnf
        log_ok "Credentials root sauvegardés dans /root/.my.cnf"

        log_info "Création de la base de données et de l'utilisateur..."
        mysql <<-EOSQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
    DEFAULT CHARACTER SET utf8mb4
    COLLATE ${MARIADB_COLLATION};
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOSQL
        log_ok "Base ${DB_NAME} et utilisateur ${DB_USER} créés"

        log_info "Correction du dump SQL (collation MySQL 8 -> MariaDB)..."
        local sql_file="${STAGING_DIR}/site-web/talaxiu48_mysql_db.sql"
        local sql_fixed="${STAGING_DIR}/site-web/talaxiu48_mysql_db_fixed.sql"
        sed "s/${MYSQL8_COLLATION}/${MARIADB_COLLATION}/g" "$sql_file" > "$sql_fixed"
        log_ok "Collation corrigée : ${MYSQL8_COLLATION} -> ${MARIADB_COLLATION}"

        log_info "Import du dump SQL..."
        mysql "$DB_NAME" < "$sql_fixed"
        log_ok "Dump importé dans ${DB_NAME}"

        log_info "Mise à jour des URL WordPress (http -> https)..."
        mysql "$DB_NAME" <<-EOSQL
UPDATE \`${TABLE_PREFIX}options\`
SET option_value = 'https://${DOMAIN}'
WHERE option_name IN ('siteurl', 'home')
AND option_value LIKE 'http://%';
EOSQL
        log_ok "URL mises à jour vers https://${DOMAIN}"

    else
        log_info "[DRY-RUN] Sécurisation MariaDB, création DB, import dump, correction collation"
    fi
}

# =============================================================================
# Phase 3 : WordPress (fichiers, config, Nginx, SSL)
# =============================================================================

phase3_wordpress() {
    log_phase "Phase 3 : WordPress"

    # Copie des fichiers
    log_info "Copie des fichiers WordPress vers ${WEB_ROOT}..."
    run mkdir -p "$WEB_ROOT"
    if [ "$DRY_RUN" = false ]; then
        rsync -a \
            --exclude='talaxiu48_mysql_db.sql' \
            --exclude='talaxiu48_mysql_db_fixed.sql' \
            --exclude='.ovhconfig' \
            "${STAGING_DIR}/site-web/" \
            "${WEB_ROOT}/"
        log_ok "Fichiers copiés"
    else
        log_info "[DRY-RUN] rsync ${STAGING_DIR}/site-web/ -> ${WEB_ROOT}/"
    fi

    # Mise à jour de wp-config.php
    log_info "Mise à jour de wp-config.php..."
    if [ "$DRY_RUN" = false ]; then
        local wpconfig="${WEB_ROOT}/wp-config.php"

        # DB_HOST : remplacer l'ancien host par localhost
        sed -i "s|define( *'DB_HOST'.* );|define( 'DB_HOST', 'localhost' );|" "$wpconfig"

        # Ajouter WP_HOME, WP_SITEURL, FORCE_SSL_ADMIN avant la ligne ABSPATH
        if ! grep -q "WP_HOME" "$wpconfig"; then
            sed -i "/if ( ! defined( 'ABSPATH' ) )/i\\
/** URL du site (migration VPS) */\\
define( 'WP_HOME', 'https://${DOMAIN}' );\\
define( 'WP_SITEURL', 'https://${DOMAIN}' );\\
define( 'FORCE_SSL_ADMIN', true );\\
" "$wpconfig"
        fi
        log_ok "wp-config.php mis à jour"
    else
        log_info "[DRY-RUN] Modification wp-config.php : DB_HOST, WP_HOME, WP_SITEURL, FORCE_SSL_ADMIN"
    fi

    # Permissions
    log_info "Application des permissions..."
    if [ "$DRY_RUN" = false ]; then
        chown -R www-data:www-data "$WEB_ROOT"
        find "$WEB_ROOT" -type d -exec chmod 755 {} \;
        find "$WEB_ROOT" -type f -exec chmod 644 {} \;
        chmod 600 "${WEB_ROOT}/wp-config.php"
        log_ok "Permissions appliquées (www-data, 755/644, wp-config 600)"
    else
        log_info "[DRY-RUN] chown www-data, chmod 755/644, wp-config 600"
    fi

    # Pool PHP-FPM dédié
    log_info "Génération du pool PHP-FPM..."
    local fpm_conf="/etc/php/${PHP_VERSION}/fpm/pool.d/talaxie.conf"
    if [ "$DRY_RUN" = false ]; then
        cat > "$fpm_conf" <<'FPMEOF'
[talaxie]
user = www-data
group = www-data
listen = /run/php/php-fpm-talaxie.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 10
pm.start_servers = 3
pm.min_spare_servers = 2
pm.max_spare_servers = 5
pm.max_requests = 500

; Limites PHP
php_admin_value[upload_max_filesize] = 64M
php_admin_value[post_max_size] = 64M
php_admin_value[memory_limit] = 256M
php_admin_value[max_execution_time] = 300
php_admin_value[max_input_vars] = 3000

; Sécurité
php_admin_flag[expose_php] = off
php_admin_value[open_basedir] = /var/www/talaxie.org/:/tmp/:/usr/share/php/
FPMEOF
        log_ok "Pool PHP-FPM créé : $fpm_conf"
        run systemctl restart "php${PHP_VERSION}-fpm"
    else
        log_info "[DRY-RUN] Création pool PHP-FPM : $fpm_conf"
    fi

    # Vhost Nginx
    log_info "Génération du vhost Nginx..."
    local nginx_conf="/etc/nginx/sites-available/${DOMAIN}"
    if [ "$DRY_RUN" = false ]; then
        cat > "$nginx_conf" <<'NGINXEOF'
server {
    listen 80;
    listen [::]:80;
    server_name talaxie.org www.talaxie.org;

    root /var/www/talaxie.org;
    index index.php index.html;

    # Logs
    access_log /var/log/nginx/talaxie.org.access.log;
    error_log  /var/log/nginx/talaxie.org.error.log;

    # Taille d'upload
    client_max_body_size 64M;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Bloquer xmlrpc.php (cible fréquente d'attaques)
    location = /xmlrpc.php {
        deny all;
        return 403;
    }

    # WordPress permalinks
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # PHP-FPM
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm-talaxie.sock;
        fastcgi_intercept_errors on;
    }

    # Cache fichiers statiques
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff2?|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Interdire l'accès aux fichiers cachés
    location ~ /\. {
        deny all;
    }

    # Interdire l'accès direct à wp-config.php
    location = /wp-config.php {
        deny all;
    }
}
NGINXEOF
        log_ok "Vhost Nginx créé : $nginx_conf"

        # Activer le site
        ln -sf "$nginx_conf" "/etc/nginx/sites-enabled/${DOMAIN}"
        # Désactiver le site par défaut s'il existe
        rm -f /etc/nginx/sites-enabled/default

        # Vérifier la configuration Nginx et recharger
        nginx -t
        run systemctl reload nginx
        log_ok "Nginx rechargé"
    else
        log_info "[DRY-RUN] Création vhost Nginx : $nginx_conf"
    fi

    # SSL Let's Encrypt — conditionnel (si DNS déjà pointé)
    log_info "Vérification DNS pour SSL..."
    if [ "$DRY_RUN" = false ]; then
        local dns_ip
        dns_ip=$(dig +short "$DOMAIN" A 2>/dev/null | head -1 || true)
        if [ "$dns_ip" = "$VPS_IP" ]; then
            log_info "DNS pointe vers ce VPS, obtention du certificat SSL..."
            certbot --nginx -d "$DOMAIN" -d "www.${DOMAIN}" --non-interactive --agree-tos --email "admin@${DOMAIN}" --redirect || {
                log_warn "Certbot a échoué. Vous pourrez relancer manuellement après propagation DNS."
            }
        else
            log_warn "DNS ne pointe pas encore vers ce VPS (résolu : ${dns_ip:-aucun}, attendu : ${VPS_IP})"
            log_warn "Lancez certbot après mise à jour DNS : certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}"
        fi
    fi
}

# =============================================================================
# Phase 4 : Bot Discord
# =============================================================================

phase4_bot() {
    log_phase "Phase 4 : Bot Discord"

    log_info "Copie des fichiers du bot vers ${BOT_DIR}..."
    run mkdir -p "$BOT_DIR"
    if [ "$DRY_RUN" = false ]; then
        cp "${STAGING_DIR}/discord/bot/bot.py" "$BOT_DIR/"
        cp "${STAGING_DIR}/discord/bot/config.py" "$BOT_DIR/"
        cp "${STAGING_DIR}/discord/bot/requirements.txt" "$BOT_DIR/"
        cp "${STAGING_DIR}/discord/bot/.env" "$BOT_DIR/"
        log_ok "Fichiers du bot copiés"
    else
        log_info "[DRY-RUN] Copie bot.py, config.py, requirements.txt, .env vers ${BOT_DIR}/"
    fi

    log_info "Création du virtualenv Python..."
    if [ "$DRY_RUN" = false ]; then
        python3 -m venv "${BOT_DIR}/venv"
        "${BOT_DIR}/venv/bin/pip" install --upgrade pip --quiet
        "${BOT_DIR}/venv/bin/pip" install -r "${BOT_DIR}/requirements.txt" --quiet
        log_ok "Dépendances Python installées"
    else
        log_info "[DRY-RUN] python3 -m venv + pip install"
    fi

    log_info "Permissions du répertoire bot..."
    if [ "$DRY_RUN" = false ]; then
        chown -R "${BOT_USER}:${BOT_USER}" "$BOT_DIR"
        chmod 600 "${BOT_DIR}/.env"
        log_ok "Permissions appliquées"
    fi

    log_info "Génération du service systemd..."
    local service_file="/etc/systemd/system/talaxie-bot.service"
    if [ "$DRY_RUN" = false ]; then
        cat > "$service_file" <<EOF
[Unit]
Description=Talaxie Discord Bot
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=simple
User=${BOT_USER}
Group=${BOT_USER}
WorkingDirectory=${BOT_DIR}
ExecStart=${BOT_DIR}/venv/bin/python bot.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
EnvironmentFile=${BOT_DIR}/.env

# Watchdog
WatchdogSec=60

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${BOT_DIR}
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
RestrictNamespaces=true
RestrictRealtime=true
LockPersonality=true
MemoryDenyWriteExecute=false
SystemCallFilter=@system-service
SystemCallArchitectures=native

[Install]
WantedBy=multi-user.target
EOF
        log_ok "Service systemd créé : $service_file"
    else
        log_info "[DRY-RUN] Création service systemd : $service_file"
    fi

    log_info "Activation et démarrage du bot..."
    run systemctl daemon-reload
    run systemctl enable talaxie-bot.service
    run systemctl start talaxie-bot.service

    # Vérification de la connexion Discord
    if [ "$DRY_RUN" = false ]; then
        log_info "Attente du démarrage du bot (10s)..."
        sleep 10
        if systemctl is-active --quiet talaxie-bot; then
            log_ok "Le service talaxie-bot est actif"
            if journalctl -u talaxie-bot --no-pager -n 20 2>/dev/null | grep -q "Connecté en tant que"; then
                log_ok "Bot connecté à Discord"
            else
                log_warn "Le service tourne mais la connexion Discord n'est pas confirmée dans les logs."
                log_warn "Vérifiez : journalctl -u talaxie-bot -f"
            fi
        else
            log_error "Le service talaxie-bot n'a pas démarré."
            log_error "Consultez : journalctl -u talaxie-bot --no-pager -n 50"
        fi
    fi
}

# =============================================================================
# Phase 5 : Vérification et résumé
# =============================================================================

phase5_verify() {
    log_phase "Phase 5 : Vérification"

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Les vérifications sont ignorées en mode dry-run."
        return 0
    fi

    # Test WordPress
    log_info "Test WordPress (curl localhost)..."
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ -H "Host: ${DOMAIN}" 2>/dev/null || echo "000")
    if [[ "$http_code" =~ ^(200|301|302)$ ]]; then
        log_ok "WordPress répond (HTTP ${http_code})"
    else
        log_warn "WordPress ne répond pas comme attendu (HTTP ${http_code})"
    fi

    # Test Bot
    log_info "Test du bot Discord..."
    if systemctl is-active --quiet talaxie-bot; then
        log_ok "Service talaxie-bot : actif"
    else
        log_warn "Service talaxie-bot : inactif"
    fi

    # Instructions DNS
    echo ""
    echo -e "${BOLD}=== Instructions post-migration ===${NC}"
    echo ""
    echo -e "${CYAN}1. Mise à jour DNS${NC}"
    echo "   Connectez-vous à votre gestionnaire DNS et mettez à jour :"
    echo ""
    echo "   Type   Nom               Valeur"
    echo "   ────   ────               ──────"
    echo "   A      ${DOMAIN}          ${VPS_IP}"
    echo "   A      www.${DOMAIN}      ${VPS_IP}"
    if [ -n "${VPS_IPV6:-}" ]; then
        echo "   AAAA   ${DOMAIN}          ${VPS_IPV6}"
        echo "   AAAA   www.${DOMAIN}      ${VPS_IPV6}"
    fi
    echo ""
    echo -e "${CYAN}2. SSL (après propagation DNS)${NC}"
    echo "   certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}"
    echo ""
    echo -e "${CYAN}3. Vérifications${NC}"
    echo "   curl -s -o /dev/null -w '%{http_code}' https://${DOMAIN}"
    echo "   systemctl status talaxie-bot"
    echo "   journalctl -u talaxie-bot -f"
    echo ""

    # Résumé final
    echo -e "${BOLD}=== Résumé de l'installation ===${NC}"
    echo ""
    echo "  WordPress"
    echo "    Web root       : ${WEB_ROOT}"
    echo "    Nginx vhost    : /etc/nginx/sites-available/${DOMAIN}"
    echo "    PHP-FPM pool   : /etc/php/${PHP_VERSION}/fpm/pool.d/talaxie.conf"
    echo "    wp-config.php  : ${WEB_ROOT}/wp-config.php"
    echo ""
    echo "  Bot Discord"
    echo "    Répertoire     : ${BOT_DIR}"
    echo "    Service        : talaxie-bot.service"
    echo "    Logs           : journalctl -u talaxie-bot -f"
    echo ""
    echo "  Base de données"
    echo "    Base           : ${DB_NAME}"
    echo "    Utilisateur    : ${DB_USER}"
    echo "    Root creds     : /root/.my.cnf"
    echo ""
    echo "  Commandes utiles"
    echo "    systemctl restart nginx"
    echo "    systemctl restart php${PHP_VERSION}-fpm"
    echo "    systemctl restart talaxie-bot"
    echo "    mysql ${DB_NAME}"
    echo ""
    echo -e "  Log migration    : ${LOG_FILE}"
    echo ""
    log_ok "Migration terminée."
}

# =============================================================================
# Exécution principale
# =============================================================================

# Créer le répertoire de log
mkdir -p "$(dirname "$LOG_FILE")"

echo -e "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   Talaxie — Migration OVH mutualisé → VPS   ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# Phase 0 est toujours exécutée (pre-flight)
phase0_preflight

should_skip 1 && log_warn "Phase 1 ignorée (--skip-phase=1)" || phase1_setup_vps
should_skip 2 && log_warn "Phase 2 ignorée (--skip-phase=2)" || phase2_mysql
should_skip 3 && log_warn "Phase 3 ignorée (--skip-phase=3)" || phase3_wordpress
should_skip 4 && log_warn "Phase 4 ignorée (--skip-phase=4)" || phase4_bot
should_skip 5 && log_warn "Phase 5 ignorée (--skip-phase=5)" || phase5_verify
