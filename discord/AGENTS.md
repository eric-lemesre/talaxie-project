# AGENTS.md — discord/

> Onboarding pour agents IA travaillant sur les outils Discord de Talaxie.

## Nature du dossier

Ce dossier regroupe **tous les outils liés au serveur Discord communautaire Talaxie**. Il est destiné à devenir, à terme, un **repo GitHub indépendant** (`talaxie-discord`) — d'où la séparation logique en sous-dossiers cohérents.

Garder cette perspective en tête : tout ce qui est ajouté ici doit pouvoir vivre **de façon autonome**, sans dépendance vers la racine `Talaxie-Project/`.

## Structure

```
discord/
├── AGENTS.md          ← ce fichier
├── bot/               ← bot Python (code exécutable)
└── setup/             ← guides de configuration du serveur (markdown)
```

## Convention de séparation

| Dossier | Contenu autorisé | Contenu interdit |
|---|---|---|
| `bot/` | Code Python, requirements, config, deploy/systemd | Documentation utilisateur, prompts MCP |
| `setup/` | Documentation, guides, prompts MCP, descriptions de salons | Code exécutable |

## Avant de scinder en repo dédié

Quand le moment viendra de créer `talaxie-discord` :

1. Le dossier doit avoir son propre `README.md`, `LICENSE`, `.gitignore`, `.env.example`.
2. Toutes les références externes (chemins absolus, imports relatifs hors `discord/`) doivent avoir été éliminées.
3. La CI GitHub Actions doit être **dans** `discord/.github/` pour faciliter le `git filter-repo` lors de l'extraction.

## Règle générale héritée du repo

- **Aucune référence à l'agent IA** dans commits, PRs, code ou documentation publique (sauf les `AGENTS.md` eux-mêmes). Voir la règle complète dans `../AGENTS.md` (section dédiée à la racine).

## Skills recommandés

Pour ce périmètre, les skills suivants sont pertinents :

| Skill | Utilité |
|---|---|
| `security-review` (slash command) | Audit sécurité avant merge (bot a accès à des secrets) |
| `find-skills` | Trouver un skill dédié si besoin spécifique apparaît |

## Pour le détail

- Bot Python : voir `bot/AGENTS.md`
- Guides serveur : voir `setup/AGENTS.md`
- Architecture du serveur Discord : voir `../Discord-Architecture.md`
