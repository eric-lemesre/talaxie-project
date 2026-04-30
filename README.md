# Talaxie-Project — Community Building

> Rassembler les idées et initiatives pour construire une communauté Talaxie solide, active et pérenne.

*[English version below](#english)*

---

## Qu'est-ce que Talaxie ?

**Talaxie** est le fork communautaire open source de [Talend Open Studio](https://en.wikipedia.org/wiki/Talend), né après que Qlik a décidé d'arrêter la version gratuite de Talend. Le projet vise à offrir un outil d'intégration de données (ETL/ELT) libre, maintenu par et pour sa communauté.

- Organisation GitHub : [github.com/Talaxie](https://github.com/Talaxie)
- Site web : [talaxie.github.io](https://talaxie.github.io)
- Documentation : [docs.talaxie.org](https://docs.talaxie.org)

## Objectif de ce dépôt

Ce dépôt **ne contient pas le code source de Talaxie**. Il centralise tout le travail de **construction communautaire** :

- Réflexion stratégique sur la gouvernance et la pérennité du projet
- Conception et automatisation du serveur Discord communautaire
- Bot Discord de modération, onboarding et intégration GitHub
- Analyse des contributeurs et de l'écosystème

## Structure du dépôt

```
Talaxie-Project/
├── VISION.md                  # Document fondateur : vision, gouvernance, stratégie communautaire
├── Discord-Architecture.md    # Architecture complète du serveur Discord
│
└── discord/                       # Outils communautaires Discord (futur repo dédié)
    ├── bot/                       # Bot Discord Python (en développement)
    │   ├── bot.py                 # Code principal (5 modules : onboarding, sécurité,
    │   │                          #   modération, utilitaires, webhooks)
    │   ├── config.py              # Configuration et patterns de détection
    │   ├── requirements.txt       # Dépendances Python
    │   └── .env.example           # Template de variables d'environnement
    │
    └── setup/                     # Guides de configuration du serveur
        ├── mcp-prompts.md         # Automatisation MCP en 14 phases
        ├── descriptions-salons.md # Descriptions de tous les salons
        ├── onboarding.md          # Message d'accueil épinglé
        ├── reglement.md           # Code de conduite communautaire
        └── sondage-satisfaction.md # Sondage mensuel de satisfaction
```

## Vision communautaire

Le succès de Talaxie repose sur trois piliers :

### 1. Gouvernance ouverte
- Un **Technical Steering Committee (TSC)** où siègent des contributeurs de différentes entreprises
- Une **roadmap publique** sur GitHub Projects
- Des décisions transparentes, documentées et accessibles

### 2. Valorisation des experts
- **Programme de Maintainers** : des experts reconnus deviennent responsables de modules spécifiques
- **Répertoire de plugins** : un espace centralisé pour partager des composants personnalisés
- Reconnaissance des contributions via des rôles communautaires

### 3. Onboarding simplifié
- Compatibilité documentée avec les anciens jobs Talend (`.item`, `.properties`)
- Documentation collaborative enrichie par la communauté
- Parcours guidé du nouveau membre sur Discord

## Serveur Discord

Le serveur [Talaxie Community](https://discord.gg/talaxie) est le point de rencontre de la communauté. Il est organisé en **8 catégories** et **30+ salons** couvrant :

| Catégorie | Contenu |
|---|---|
| Accueil | Règles, annonces, onboarding, votes |
| Communauté | Discussions générales, débutants, international, victoires |
| Support technique | Aide installation, jobs, migration, sécurité |
| Contribution & Dev | Guide PR, dev core, composants, CI/CD, code review |
| Documentation | Feedback docs, tutoriels, veille technologique |
| Governance | Roadmap, TSC, partenariats |
| Vocal & Événements | Discussions vocales, meetups, live coding |
| Bots & Logs | Feeds GitHub/CI, logs modération, alertes sécurité |

## Bot Discord

Le bot Python est en cours de développement. Il intègre :

- **Onboarding automatique** : accueil des nouveaux membres, attribution de rôles via réactions
- **Détection de credentials** : 13 patterns regex (tokens, mots de passe, clés SSH, AWS...)
- **Modération graduée** : système d'avertissements avec escalade automatique
- **Intégration GitHub** : recherche d'issues, liens documentation, enrichissement des webhooks
- **Commandes slash** : `/help`, `/doc`, `/issue`, `/roadmap`

### Lancer le bot (développement)

```bash
cd discord/bot
cp .env.example .env
# Remplir .env avec les valeurs réelles
pip install -r requirements.txt
python bot.py
```

## Pile technique

| Outil | Usage |
|---|---|
| **Python 3 + discord.py** | Bot Discord |
| **GitHub** | Code, issues, webhooks, CI/CD |
| **Discord** | Communication synchrone |
| **Docusaurus** | Documentation (dépôt séparé) |
| **GitHub Projects** | Gestion de la roadmap |
| **GitHub Actions** | Pipelines CI/CD |

## Contribuer

Ce dépôt est ouvert aux contributions. Vous pouvez :

- Améliorer la documentation communautaire
- Proposer de nouvelles fonctionnalités pour le bot
- Enrichir les guides d'onboarding et de migration
- Participer aux discussions sur la gouvernance

Pour contribuer au **code source de Talaxie** lui-même, rendez-vous sur l'organisation [github.com/Talaxie](https://github.com/Talaxie).

## Liens utiles

| Ressource | URL |
|---|---|
| Organisation GitHub Talaxie | https://github.com/Talaxie |
| Site web | https://talaxie.github.io |
| Documentation | https://docs.talaxie.org |
| Serveur Discord | *(lien d'invitation à venir)* |

---

## Licence

Ce dépôt est sous licence [MIT](LICENSE).

---

<a name="english"></a>

# Talaxie-Project — Community Building (English)

> Gathering ideas and initiatives to build a strong, active, and sustainable Talaxie community.

## What is Talaxie?

**Talaxie** is the community-driven open source fork of [Talend Open Studio](https://en.wikipedia.org/wiki/Talend), created after Qlik discontinued the free version of Talend. The project aims to provide a free data integration tool (ETL/ELT), maintained by and for its community.

- GitHub organization: [github.com/Talaxie](https://github.com/Talaxie)
- Website: [talaxie.github.io](https://talaxie.github.io)
- Documentation: [docs.talaxie.org](https://docs.talaxie.org)

## Purpose of this repository

This repository **does not contain Talaxie source code**. It centralizes all **community building** efforts:

- Strategic thinking on governance and project sustainability
- Discord community server design and automation
- Discord bot for moderation, onboarding, and GitHub integration
- Contributor and ecosystem analysis

## Community vision

Talaxie's success relies on three pillars:

1. **Open governance** — A Technical Steering Committee (TSC) with contributors from multiple organizations, a public roadmap, and transparent decisions.
2. **Expert recognition** — A maintainer program for domain experts, a centralized plugin repository, and community roles to acknowledge contributions.
3. **Simplified onboarding** — Documented compatibility with legacy Talend jobs, collaborative documentation, and a guided newcomer journey on Discord.

## Discord bot

The Python bot (under development) features:

- **Automatic onboarding**: welcoming new members, reaction-based role assignment
- **Credential detection**: 13 regex patterns (tokens, passwords, SSH keys, AWS credentials...)
- **Graduated moderation**: warning system with automatic escalation
- **GitHub integration**: issue search, documentation links, webhook enrichment
- **Slash commands**: `/help`, `/doc`, `/issue`, `/roadmap`

### Run the bot (development)

```bash
cd discord/bot
cp .env.example .env
# Fill .env with actual values
pip install -r requirements.txt
python bot.py
```

## Contributing

This repository is open to contributions. You can:

- Improve community documentation
- Propose new bot features
- Enrich onboarding and migration guides
- Participate in governance discussions

To contribute to **Talaxie source code** itself, head to [github.com/Talaxie](https://github.com/Talaxie).

## License

This repository is licensed under [MIT](LICENSE).
