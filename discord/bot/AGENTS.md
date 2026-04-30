# AGENTS.md — discord/bot/

> Onboarding pour agents IA travaillant sur le bot Discord Python.

## Nature du module

Bot Discord Python pour la communauté Talaxie. Cinq fonctions principales :

1. **Onboarding** : accueil des nouveaux membres, attribution de rôles via réactions.
2. **Sécurité** : détection de credentials leakés (13 patterns regex : tokens, mots de passe, clés SSH, AWS, etc.).
3. **Modération** : système d'avertissements gradué avec escalade automatique.
4. **Intégration GitHub** : recherche d'issues, liens documentation, enrichissement webhooks.
5. **Commandes slash** : `/help`, `/doc`, `/issue`, `/roadmap`.

## Stack

| Composant | Choix |
|---|---|
| Langage | Python 3.13+ |
| Lib Discord | `discord.py` |
| Déploiement | systemd sur VPS Debian 12+ (utilisateur dédié `talaxie`, virtualenv, watchdog) |
| Audio | `audioop-lts` (compat Python 3.13+) |
| Orchestration locale | `python -m venv .venv && pip install -r requirements.txt` |

## Structure du dossier

```
discord/bot/
├── bot.py                 ← entrée + 5 modules principaux
├── config.py              ← configuration et patterns de détection
├── requirements.txt       ← dépendances Python
├── .env.example           ← template des variables d'env
├── .env                   ← gitignored — secrets réels
├── deploy/
│   ├── setup-vps.sh       ← provisioning VPS
│   └── talaxie-bot.service ← unit systemd
└── AGENTS.md              ← ce fichier
```

## Conventions

- **Aucun secret en dur** : tout passe par `.env` (loader via `os.environ` ou `python-dotenv`).
- **Logs explicites** : utiliser le logger Python standard, pas `print()`. Le bot tourne sous systemd → tout va dans `journalctl`.
- **Patterns regex sensibles** dans `config.py` : ne **jamais** logger le contenu matché (juste la catégorie). Risque d'exposition de secret dans les logs.
- **discord.py async** : tous les handlers doivent être `async def`. Pas de blocage sync (utiliser `asyncio.to_thread` au besoin).
- **Style** : PEP 8, type hints encouragés sur les nouvelles fonctions.
- **Aucune référence à l'agent IA** dans commits, PRs, code, docstrings (sauf `AGENTS.md` eux-mêmes). Voir `../../AGENTS.md` (racine) pour la règle complète.

## Commandes utiles

```bash
# Setup local
cd discord/bot
cp .env.example .env
# Remplir .env (DISCORD_TOKEN, GITHUB_TOKEN, etc.)
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python bot.py

# Lint (à mettre en place)
ruff check .
ruff format --check .

# Sur VPS — admin du service
sudo systemctl status talaxie-bot
sudo systemctl restart talaxie-bot
sudo journalctl -u talaxie-bot -f
```

## Skills recommandés

| Skill | Utilité |
|---|---|
| `security-review` (slash command) | Audit critique : le bot manipule des secrets et détecte des credentials leakés |
| `owasp-security-check` | Audit sécurité du module credential-detection |
| `find-skills` | Trouver un skill Python si besoin spécifique |

## Pièges à éviter

- **Ne jamais committer `.env`** ni de logs contenant des tokens.
- **Ne pas modifier les patterns regex de détection sans tests** : un faux négatif laisse passer un secret réel.
- **Ne pas mettre de `print()` ou debug verbose** dans des handlers qui voient des messages utilisateurs (risque de fuite de données privées).
- **Tester en environnement Discord de staging** avant de déployer sur le serveur communautaire (bot trop verbeux ou bugué = expérience utilisateur dégradée pour toute la communauté).
- Compat Python 3.13 : `audioop-lts` est nécessaire car `audioop` a été retiré du stdlib.

## Roadmap technique (TODO)

- [ ] Tests automatisés (pytest + mocks discord.py)
- [ ] Linter en CI (ruff)
- [ ] Coverage minimal sur les patterns de credential detection
- [ ] Healthcheck endpoint pour monitoring externe
