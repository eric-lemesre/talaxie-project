#!/bin/bash
# =============================================================================
# Talaxie Discord Bot — Script de déploiement VPS
# =============================================================================
# Usage : sudo bash setup-vps.sh
# Prérequis : Ubuntu 22.04+ ou Debian 12+ sur VPS OVH
# =============================================================================

set -euo pipefail

BOT_DIR="/opt/talaxie-bot"
BOT_USER="talaxie"

echo "=== Talaxie Bot — Déploiement VPS ==="

# 1. Mise à jour système
echo "[1/7] Mise à jour du système..."
apt update && apt upgrade -y

# 2. Installation de Python 3.11+
echo "[2/7] Installation de Python..."
apt install -y python3 python3-venv python3-pip

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
echo "       Python installé : ${PYTHON_VERSION}"

# 3. Création de l'utilisateur système
echo "[3/7] Création de l'utilisateur ${BOT_USER}..."
if ! id "${BOT_USER}" &>/dev/null; then
    useradd --system --create-home --home-dir "${BOT_DIR}" --shell /bin/false "${BOT_USER}"
else
    echo "       L'utilisateur ${BOT_USER} existe déjà."
fi

# 4. Installation du bot
echo "[4/7] Installation du bot dans ${BOT_DIR}..."
mkdir -p "${BOT_DIR}"
cp bot.py config.py requirements.txt "${BOT_DIR}/"

# 5. Environnement virtuel et dépendances
echo "[5/7] Création de l'environnement virtuel..."
python3 -m venv "${BOT_DIR}/venv"
"${BOT_DIR}/venv/bin/pip" install --upgrade pip
"${BOT_DIR}/venv/bin/pip" install -r "${BOT_DIR}/requirements.txt"

# 6. Configuration
echo "[6/7] Configuration..."
if [ ! -f "${BOT_DIR}/.env" ]; then
    cp .env.example "${BOT_DIR}/.env"
    echo "       IMPORTANT : Édite ${BOT_DIR}/.env avec les vraies valeurs"
    echo "       sudo nano ${BOT_DIR}/.env"
else
    echo "       ${BOT_DIR}/.env existe déjà, pas de remplacement."
fi

chown -R "${BOT_USER}:${BOT_USER}" "${BOT_DIR}"
chmod 600 "${BOT_DIR}/.env"

# 7. Service systemd
echo "[7/7] Installation du service systemd..."
cp deploy/talaxie-bot.service /etc/systemd/system/talaxie-bot.service
systemctl daemon-reload
systemctl enable talaxie-bot.service

echo ""
echo "=== Installation terminée ==="
echo ""
echo "Prochaines étapes :"
echo "  1. Éditer la configuration :  sudo nano ${BOT_DIR}/.env"
echo "  2. Démarrer le bot :          sudo systemctl start talaxie-bot"
echo "  3. Vérifier le statut :        sudo systemctl status talaxie-bot"
echo "  4. Voir les logs :             sudo journalctl -u talaxie-bot -f"
echo ""
