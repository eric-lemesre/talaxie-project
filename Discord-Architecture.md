# Architecture du serveur Discord Talaxie

> **Objectif** : Créer un espace Discord structuré, accueillant et productif pour fédérer la communauté Talaxie — du simple utilisateur migré de Talend au contributeur core.

---

## 1. Vue d'ensemble

| Élément               | Description                                                                                   |
|-----------------------|-----------------------------------------------------------------------------------------------|
| **Nom**               | Talaxie Community                                                                             |
| **Public cible**      | Utilisateurs Talend/Open Studio, développeurs Java, data engineers, entreprises               |
| **Philosophie**       | Ouvert, bienveillant, technique. Pas de support commercial, mais de l'entraide communautaire. |
| **Langue principale** | Français + Anglais (canaux bilingues ou séparés)                                              |

---

## 2. Structure des catégories et salons

### 2.1 🏠 ACCUEIL (read-only pour @everyone)

| Salon           | Type  | Description                                                                                           |
|-----------------|-------|-------------------------------------------------------------------------------------------------------|
| `📜-regles`     | Texte | Code de conduite, règles de sécurité (pas de credentials), licence CC-BY-SA pour les captures d'écran |
| `📢-annonces`   | Texte | Releases, sécurité (CVE), événements communautaires. Rôle @Announcements pingable.                    |
| `🚀-onboarding` | Texte | Guide "Day 1" : rôles, salons utiles, comment poser une question. Pin du message de bienvenue.        |
| `🗳️-votes`     | Texte | Sondages roadmap, choix de logos, noms de releases. Utilisation de reactions (👍/👎) ou bot.          |

### 2.2 💬 COMMUNAUTÉ (ouverts)

| Salon             | Type  | Description                                                                                             |
|-------------------|-------|---------------------------------------------------------------------------------------------------------|
| `💡-general`      | Texte | Discussions libres, présentations, veille techno ETL/ELT                                                |
| `🎓-debutants`    | Texte | Espace sans jugement pour les questions "basiques" (installation, premier job, migration TOS → Talaxie) |
| `🌍-i18n-general` | Texte | Canal anglais principal pour la communauté internationale                                               |
| `🎉-victoires`    | Texte | Partage de succès : job en prod, contribution mergée, certification. Moral boost.                       |

### 2.3 🛠️ SUPPORT TECHNIQUE (aide entre pairs)

| Salon                    | Type  | Description                                                                                                               |
|--------------------------|-------|---------------------------------------------------------------------------------------------------------------------------|
| `❓-aide-installation`    | Texte | Problèmes de build, Java, Maven, Eclipse RCP, plugins manquants                                                           |
| `❓-aide-jobs`            | Texte | Questions sur les jobs, composants, connexions bases de données, erreurs d'exécution                                      |
| `❓-aide-migration`       | Texte | Spécifique migration depuis Talend Open Studio (compatibilité .item, .properties)                                         |
| `🔒-aide-securite`       | Texte | **Restreint @Contributeur+** — discussions sur les rapports d'audit, fixes, CVE. Pas de divulgation publique avant patch. |
| `📎-partage-screenshots` | Texte | Captures d'écran de logs/configurations (anonymisées obligatoires)                                                        |
| `🧵-threads-support`     | Forum | Format forum pour les tickets d'aide longs. Un thread = un problème. Archivage auto après 30j inactivité.                 |

### 2.4 🔧 CONTRIBUTION & DÉVELOPPEMENT

| Salon                  | Type  | Description                                                                              |
|------------------------|-------|------------------------------------------------------------------------------------------|
| `🤝-contribuer`        | Texte | Guide pour faire sa première PR, signer le CLA, choisir une "good first issue"           |
| `💻-dev-core`          | Texte | Discussion architecture Java, refactoring, choix technologiques (ex: Java 17 vs 21)      |
| `🔌-dev-composants`    | Texte | Développement de nouveaux connecteurs/composants. Partage de templates.                  |
| `🧪-ci-cd`             | Texte | Pipelines GitHub Actions, tests automatisés, builds cassés                               |
| `📋-code-review`       | Texte | Demande de relecture informelle avant PR, discussion sur les patterns                    |
| `🔒-security-response` | Texte | **Restreint @Security Team** — coordination des fix de sécurité, divulgation responsable |

### 2.5 📚 DOCUMENTATION & SAVOIR

| Salon              | Type  | Description                                                             |
|--------------------|-------|-------------------------------------------------------------------------|
| `📖-docs-feedback` | Texte | Retours sur la documentation Docusaurus, signalement de pages obsolètes |
| `📝-tutoriels`     | Texte | Partage de tutoriels communautaires (vidéos, articles, notebooks)       |
| `🔗-veille`        | Texte | Veille ETL/ELT : articles, nouveaux outils, benchmarks, conférences     |

### 2.6 🏢 GOVERNANCE & PROJET

| Salon             | Type  | Description                                                                     |
|-------------------|-------|---------------------------------------------------------------------------------|
| `📊-roadmap`      | Texte | Discussion publique de la roadmap GitHub Projects. Pas de décision unilatérale. |
| `🏛️-tsc-public`  | Texte | Compte-rendus des réunions du Technical Steering Committee (transparents)       |
| `🤝-partenariats` | Texte | Discussions avec entreprises souhaitant sponsoriser ou contribuer. Modéré.      |

### 2.7 🎙️ VOCAL & ÉVÉNEMENTS

| Salon               | Type           | Description                                                                            |
|---------------------|----------------|----------------------------------------------------------------------------------------|
| `🎙️-salon-general` | Vocal          | Discussions vocales informelles                                                        |
| `🎙️-help-desk`     | Vocal          | Support vocal en direct (horaires définis, volontaires)                                |
| `🎙️-meetup`        | Vocal / Stage  | Présentations communautaires mensuelles. Enregistrement possible (opt-in).             |
| `🔴-live-coding`    | Vocal / Stream | Sessions de live coding sur le refactoring du projet. Planning annoncé dans #annonces. |

### 2.8 🤖 BOTS & LOGS (cachés / restreints)

| Salon                | Type  | Description                                                                 |
|----------------------|-------|-----------------------------------------------------------------------------|
| `🤖-bot-commands`    | Texte | Commandes publiques des bots (`/help`, `/issue`, `/doc`)                    |
| `🔔-github-feed`     | Texte | Webhooks GitHub : nouvelles PR, issues, releases, commits sur master        |
| `🔔-ci-feed`         | Texte | Webhooks CI : builds passés/échoués, résultats de tests                     |
| `📋-mod-logs`        | Texte | Logs des actions de modération (bot Carl-bot ou Dyno)                       |
| `🚨-security-alerts` | Texte | Alertes automatiques de vulnérabilités (Dependabot, Snyk, rapports d'audit) |

---

## 3. Système de rôles

### 3.1 Rôles hiérarchiques (permissions croissantes)

| Rôle                                  | Couleur | Permissions clés                                       | Attribution                        |
|---------------------------------------|---------|--------------------------------------------------------|------------------------------------|
| `@everyone`                           | —       | Lire #accueil, parler dans #general, créer des threads | Automatique                        |
| `@Nouveau`                            | Gris    | Même chose, mais salon #debutants privilégié           | Auto après règlement accepté       |
| `@Utilisateur`                        | Bleu    | Accès complet salons ouverts, réactions, fichiers      | Auto après 10 min + rôle choisi    |
| `@Contributeur`                       | Vert    | Accès salons dev, #aide-securite                       | Manuelle après 1ère PR mergée      |
| `@Maintainer`                         | Orange  | Modération partielle, organisation des événements      | Élection TSC                       |
| `@Security Team`                      | Rouge   | Accès #security-response, gestion des CVE              | Invitation restreinte              |
| `@TSC` (Technical Steering Committee) | Violet  | Gouvernance, décisions finales                         | Vote communautaire                 |
| `@Admin`                              | Noir    | Tout                                                   | Fondateurs + hébergeurs techniques |

### 3.2 Rôles thématiques (non hiérarchiques, cumulables)

| Rôle             | Description                        | Auto-attribution via bot            |
|------------------|------------------------------------|-------------------------------------|
| `@Java Dev`      | Développeur Java/Eclipse RCP       | ✅ Oui (réaction rôles)              |
| `@Data Engineer` | Utilisateur ETL/ELT                | ✅ Oui                               |
| `@Admin Sys`     | Déploiement, CI/CD, infra          | ✅ Oui                               |
| `@Traducteur`    | Contribue aux traductions docs     | ✅ Oui                               |
| `@Bug Hunter`    | Chercheur de vulnérabilités        | ✅ Oui                               |
| `@Mentor`        | Bénévole pour guider les débutants | ✅ Oui (après validation modérateur) |

### 3.3 Rôles de notification (pingables)

| Rôle             | Usage                                      |
|------------------|--------------------------------------------|
| `@Announcements` | Annonces officielles (rare, important)     |
| `@Help Needed`   | Demande d'aide urgente sur un bug bloquant |
| `@Release Ping`  | Notifications de nouvelles releases        |

---

## 4. Bots recommandés et configuration

### 4.1 Bot principal : **Carl-bot** ou **Dyno**

**Rôles par réaction** (`/reactionrole`) :
- Message épinglé dans `#onboarding` avec des réactions pour s'attribuer les rôles thématiques
- Exemple : 🟦 = Java Dev, 🟩 = Data Engineer, 🟥 = Admin Sys

**Modération automatique** :
- Filtre anti-spam (5 messages / 5s)
- Filtre anti-scam (liens suspects, @everyone abusif)
- Auto-mute 1h après 3 warns

### 4.2 Intégration GitHub : **GitHub bot officiel**

Configuration des webhooks :
```
#github-feed
- Nouvelle issue → 🐛
- Nouvelle PR → 🔀
- PR mergée → ✅
- Release publiée → 🚀
- Commit sur master → 📝 (limite 5/jour pour éviter le spam)
```

### 4.3 Bot sécurité : **Snyk** ou webhook custom

- Publication automatique des alertes Dependabot dans `#security-alerts`
- Rappel hebdomadaire des issues de sécurité ouvertes sur GitHub

### 4.4 Bot utilitaire : **Disboard** (croissance)

- Bump automatique toutes les 2h pour la visibilité sur les listes de serveurs
- Description du serveur optimisée SEO : "Talaxie — Open Source ETL fork of Talend Open Studio"

### 4.5 Bot documentation : **custom** ou **GitBook bot**

- Commande `/doc <sujet>` → lien vers la page Docusaurus correspondante
- Commande `/issue <mot-clé>` → recherche dans les issues GitHub ouvertes

---

## 5. Flux d'onboarding (parcours nouveau membre)

```
1. Rejoint le serveur
   → Règlement affiché (modal Discord obligatoire avant accès)
   
2. Accepte le règlement
   → Attribution auto @Nouveau
   → DM du bot avec guide "Day 1"
   
3. Lit #onboarding
   → Choisit ses rôles thématiques via réactions
   → Découvre les salons adaptés à son profil
   
4. Première interaction
   → Si question technique → orienté vers #debutants ou #aide-installation
   → Si envie de contribuer → orienté vers #contribuer
   
5. Progression
   → 1ère PR mergée → promotion manuelle @Contributeur
   → Participation régulière → nomination possible @Mentor
```

---

## 6. Règles de modération et sécurité

### 6.1 Interdictions strictes

- **Aucun credential** : pas de mots de passe, tokens API, clés SSH dans les chats (même en MP)
- **Aucun dump de données** : pas de fichiers CSV contenant des données personnelles
- **Pas de support commercial déguisé** : pas de vente de services de consulting non transparente
- **Pas de piratage** : pas de demande de cracking de licences Talend propriétaires

### 6.2 Escalade des sanctions

| Infraction                | 1ère fois                           | Répétition                          |
|---------------------------|-------------------------------------|-------------------------------------|
| Spam / off-topic          | Warn + suppression                  | Mute 1h                             |
| Credentials leakés        | Suppression immédiate + MP sécurité | Ban temporaire + rotation des creds |
| Comportement toxique      | Warn                                | Mute 24h → Kick → Ban               |
| Troll / FUD sur le projet | Warn + clarification                | Mute → Ban                          |

### 6.3 Divulgation responsable (sécurité)

- **Jamais** de détails publics sur une CVE non patchée
- Canal `#security-response` uniquement pour la coordination
- Processus : reporter → confirmation → fix → release patch → annonce publique (90 jours max)

---

## 7. Intégration avec l'écosystème externe

| Outil externe              | Intégration Discord                                     | Salon lié          |
|----------------------------|---------------------------------------------------------|--------------------|
| **GitHub**                 | Webhooks + bot officiel                                 | `#github-feed`     |
| **GitHub Projects**        | Aperçu roadmap dans topic du salon `#roadmap`           | `#roadmap`         |
| **Discourse**              | Bridge (optionnel) : les topics importants sont relayés | `#veille`          |
| **Docusaurus**             | Commande `/doc` + liens dans les réponses d'aide        | `#docs-feedback`   |
| **CI/CD (GitHub Actions)** | Webhooks build status                                   | `#ci-feed`         |
| **Snyk/Dependabot**        | Alertes vulnérabilités                                  | `#security-alerts` |

---

## 8. Métriques de santé communautaire (à suivre)

| Métrique                                  | Objectif 6 mois | Outil                        |
|-------------------------------------------|-----------------|------------------------------|
| Membres actifs (messages/semaine)         | 50+             | Discord Analytics ou Statbot |
| Temps de réponse médian aux questions     | < 4h            | Suivi manuel ou bot          |
| Taux de conversion Nouveau → Contributeur | 5%              | Suivi GitHub + rôles         |
| Satisfaction (sondage mensuel)            | > 4/5           | Bot sondage                  |
| Incidents de sécurité (fuite de creds)    | 0               | Logs modération              |

---

## 9. Checklist de mise en place

- [ ] Créer les catégories et salons selon la structure §2
- [ ] Configurer les permissions par rôle (§3)
- [ ] Inviter Carl-bot / Dyno et configurer les rôles par réaction
- [ ] Connecter le webhook GitHub au salon `#github-feed`
- [ ] Rédiger et épingler le règlement avec modal obligatoire
- [ ] Rédiger le message d'onboarding épinglé dans `#onboarding`
- [ ] Configurer le bot de modération (filtres spam/scam)
- [ ] Créer le template de sondage mensuel de satisfaction
- [ ] Documenter le processus de divulgation responsable
- [ ] Former 2+ modérateurs hors fondateurs

---

*Document rédigé pour le projet Talaxie — April 2026*
