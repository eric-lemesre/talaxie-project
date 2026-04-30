# AGENTS.md — discord/setup/

> Onboarding pour agents IA travaillant sur les guides de configuration du serveur Discord Talaxie.

## Nature du dossier

Ce dossier contient **uniquement de la documentation markdown** liée à la configuration et à l'animation du serveur Discord communautaire. Aucun code exécutable ici.

## Contenu

| Fichier | Rôle |
|---|---|
| `mcp-prompts.md` | Prompts MCP en 14 phases pour automatiser la création/maintenance du serveur |
| `descriptions-salons.md` | Descriptions officielles de tous les salons Discord |
| `onboarding.md` | Message d'accueil épinglé pour les nouveaux membres |
| `reglement.md` | Code de conduite communautaire |
| `sondage-satisfaction.md` | Modèle de sondage mensuel de satisfaction |

## Conventions de rédaction

- **Langue** : français en priorité (communauté FR), versions EN possibles en sections séparées (jamais de fichier dupliqué `_en`).
- **Ton** : chaleureux, inclusif, professionnel. Communauté open source, pas corporate.
- **Markdown** : compatible Discord (Discord ne rend pas tout le markdown — éviter tableaux complexes dans les messages destinés à être copiés-collés vers Discord).
- **Émojis** : autorisés et encouragés dans les contenus destinés à Discord (cohérent avec l'usage de la plateforme). Mais éviter dans les sections techniques ou réglementaires.
- **Aucune référence à l'agent IA** dans le contenu des fichiers (ni signature, ni mention « généré avec... »). Les guides s'adressent à la communauté humaine — voir `../../AGENTS.md` (racine) pour la règle complète.

## Commandes utiles

```bash
# Vérifier les liens cassés (à mettre en place)
markdown-link-check *.md

# Linter markdown (à mettre en place)
markdownlint *.md
```

## Skills recommandés

| Skill | Utilité |
|---|---|
| Aucun skill spécifique requis | Documentation rédactionnelle classique |

## Pièges à éviter

- **Ne pas mettre de tokens/IDs Discord** dans ces fichiers (channel IDs, role IDs, webhook URLs). Si un identifiant doit être référencé, utiliser un placeholder `<CHANNEL_ID>` documenté.
- **Ne pas modifier `reglement.md` sans accord explicite** : c'est un document à valeur quasi-juridique pour la communauté. Toute modification doit faire l'objet d'une discussion communautaire.
- **Cohérence inter-fichiers** : si un nom de salon change dans `descriptions-salons.md`, vérifier qu'il n'apparaît pas ailleurs (`onboarding.md`, `mcp-prompts.md`, `../../Discord-Architecture.md`).

## Référentiel

- Architecture globale du serveur : `../../Discord-Architecture.md`
- Bot qui anime le serveur : `../bot/AGENTS.md`
