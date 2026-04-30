# AGENTS.md — Talaxie-Project (umbrella)

> Onboarding pour agents IA travaillant sur ce repo. Lecture obligatoire avant toute modification.

## Nature du projet

Talaxie est un **fork communautaire open source de Talend Open Studio** (ETL Java), né après la fermeture du code par Qlik. Public cible : data engineers, intégrateurs, communauté open source.

Ce repo (`Talaxie-Project`) est le **repo umbrella** : il orchestre l'écosystème, héberge la documentation, le bot Discord, les scripts d'infra, et l'environnement de dev local. Il **ne contient pas** le code source de l'ETL Talaxie lui-même.

## Architecture multi-repos (à terme)

```
github.com/eric-lemesre/Talaxie-Project   ← ce repo (umbrella)
github.com/eric-lemesre/talaxie-theme     ← Block Theme WordPress (publié WP.org)
github.com/eric-lemesre/talaxie-core      ← Plugin compagnon (publié WP.org)
github.com/eric-lemesre/talaxie-discord   ← (futur) outils Discord
```

Aucun submodule. Les repos sont reliés au niveau applicatif uniquement (script de bootstrap qui clone les autres repos dans `site-web/wp-content/themes` et `site-web/wp-content/plugins`).

## Structure du repo

```
Talaxie-Project/
├── README.md, VISION.md, LICENSE       ← documentation projet
├── AGENTS.md                            ← ce fichier
├── docs/                                ← (à créer) docs techniques
├── discord/                             ← outils Discord (futur repo dédié)
│   ├── bot/                             ← bot Python
│   └── setup/                           ← guides serveur Discord
├── infra/                               ← (à créer) scripts VPS, Ansible, etc.
│   └── migrate-to-vps.sh                ← (à déplacer ici)
├── bin/                                 ← scripts dev local
│   ├── bootstrap.sh                     ← init env de dev (orchestrateur)
│   └── reset-db.sh                      ← drop tables + reinstall WP (destructif, confirmation requise)
├── composer.json                        ← installe WP via roots/wordpress + scripts d'orchestration
├── .env.example                         ← template variables d'env
├── .env                                 ← gitignored — secrets locaux
└── site-web/                            ← gitignored — généré par bootstrap.sh
```

## Conventions non négociables

- **`site-web/` n'est jamais committé.** C'est un environnement de travail local généré par `bin/bootstrap.sh`. Aucun code livrable n'y vit.
- **`.env`** contient des secrets (DB, Discord token, GitHub PAT). **Jamais** le committer ni l'afficher dans des logs. Toujours utiliser `.env.example` comme référence.
- **Tous les outils Discord** vont dans `discord/` (bot + setup + futurs scripts). Préparation à un repo `talaxie-discord` indépendant.
- **Pas de code de production WordPress** dans ce repo : il va dans `talaxie-theme` ou `talaxie-core`.
- **Préserver l'historique git** lors des renommages : toujours `git mv`, jamais `mv` + `git add -A` sauf cas particulier.

## Aucune référence à l'agent IA dans les artefacts du projet

**Règle générale :** aucune mention d'un agent IA (Claude, assistant, « generated with », `Co-Authored-By: Claude`, etc.) ne doit apparaître dans les artefacts publics du projet :

- Messages de commit (pas de `Co-Authored-By: Claude`, pas de `🤖 Generated with...`)
- Pull requests (titre, description, commentaires)
- Code, commentaires de code, docstrings
- Documentation publique (`README.md`, `docs/`, `VISION.md`, etc.)

**Exception légitime :** les fichiers `AGENTS.md` et `CLAUDE.md` peuvent évidemment mentionner les agents — c'est leur raison d'être (onboarding agents).

**Pourquoi :** les artefacts publiés représentent le projet et ses contributeurs humains, pas l'outil utilisé pour les produire. Un message de commit doit décrire le **changement**, pas qui ou quoi l'a produit.

## Stack technique de l'écosystème

| Composant | Stack |
|---|---|
| Site WordPress | PHP 8.1+ / WP 6.5+ / Block Theme + plugin PSR-4 |
| Bot Discord | Python 3.13+ / discord.py / systemd |
| Infrastructure | Debian 12+ / Nginx / PHP-FPM / MariaDB |
| Documentation | Docusaurus (repo séparé) |
| CI | GitHub Actions |

## Commandes utiles

```bash
# État du repo
git status

# Voir l'historique recent
git log --oneline -20

# Lancer le bot en local (après config .env)
cd discord/bot && pip install -r requirements.txt && python bot.py

# Migration vers VPS (à exécuter sur le VPS cible, pas en local)
sudo bash migrate-to-vps.sh --help
```

## Skills Claude Code recommandés

Pour ce repo umbrella, les skills suivants sont particulièrement utiles :

| Skill | Utilité |
|---|---|
| `github-actions-templates` | Mise en place CI sur les 3 repos |
| `changelog-automation` | Automatisation des releases |
| `security-review` (slash command) | Audit sécurité avant merge |
| `owasp-security-check` | Audit web/API |
| `find-skills` | Découvrir d'autres skills si besoin |

Pour les sous-dossiers, voir leurs `AGENTS.md` respectifs (`discord/AGENTS.md`, `discord/bot/AGENTS.md`).

## Pièges à éviter

- **Ne jamais committer `site-web/`** même si ça semble pratique pour partager une config de test.
- **Ne jamais désactiver les hooks git** (`--no-verify`) — investigate plutôt l'erreur.
- **Ne pas re-indenter `migrate-to-vps.sh`** : c'est un script bash production-ready avec idempotence soigneuse.
- **Ne pas remplacer le `set -euo pipefail`** dans les scripts bash — c'est intentionnel.
- **Avant d'ajouter une dépendance**, vérifier compatibilité GPLv2+ (cohérent avec l'esprit fork libre).

## Pour aller plus loin

- Décisions structurantes : voir `VISION.md`
- Discord en détail : voir `Discord-Architecture.md` + `discord/AGENTS.md`
- Standards qualité visés : WPCS, PHPUnit, WCAG 2.1 AA, i18n complet
