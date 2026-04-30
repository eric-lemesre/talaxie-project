# 🚀 Prompts MCP — Configuration complète du serveur Discord Talaxie

> Copie-colle chaque section dans ton client MCP (Claude Desktop, Cursor, etc.) connecté à `mcp-discord`.
> Remplace `GUILD_ID` par l'ID de ton serveur Discord si nécessaire.

---

## PHASE 1 — Catégories

```
Sur mon serveur Discord, crée les 8 catégories suivantes dans cet ordre :

1. 🏠 ACCUEIL
2. 💬 COMMUNAUTÉ
3. 🛠️ SUPPORT TECHNIQUE
4. 🔧 CONTRIBUTION & DÉVELOPPEMENT
5. 📚 DOCUMENTATION & SAVOIR
6. 🏢 GOVERNANCE & PROJET
7. 🎙️ VOCAL & ÉVÉNEMENTS
8. 🤖 BOTS & LOGS
```

---

## PHASE 2 — Salons textuels (🏠 ACCUEIL)

```
Dans la catégorie "🏠 ACCUEIL", crée ces salons textuels :
- 📜-regles
- 📢-annonces
- 🚀-onboarding
- 🗳️-votes

Puis configure ces descriptions :
📜-regles : "Code de conduite et règles de sécurité. Lecture obligatoire avant participation."
📢-annonces : "Releases, alertes de sécurité (CVE) et événements communautaires. Ne pas parler ici."
🚀-onboarding : "Guide du nouveau membre : rôles, salons utiles, comment bien poser une question."
🗳️-votes : "Sondages communautaires : roadmap, choix de fonctionnalités, noms de releases."
```

---

## PHASE 3 — Salons textuels (💬 COMMUNAUTÉ)

```
Dans la catégorie "💬 COMMUNAUTÉ", crée ces salons textuels :
- 💡-general
- 🎓-debutants
- 🌍-i18n-general
- 🎉-victoires

Descriptions :
💡-general : "Discussions libres autour de Talaxie, de l'ETL/ELT et de la data en général."
🎓-debutants : "Espace sans jugement pour les questions d'installation, de premier job et de bases."
🌍-i18n-general : "English-speaking channel for the international Talaxie community."
🎉-victoires : "Partage tes succès : job en production, PR mergée, certification obtenue !"
```

---

## PHASE 4 — Salons textuels (🛠️ SUPPORT TECHNIQUE)

```
Dans la catégorie "🛠️ SUPPORT TECHNIQUE", crée ces salons textuels :
- ❓-aide-installation
- ❓-aide-jobs
- ❓-aide-migration
- 🔒-aide-securite
- 📎-partage-screenshots
- 🧵-threads-support

Descriptions :
❓-aide-installation : "Problèmes de build, Java, Maven, Eclipse RCP, plugins manquants. Donne ta version et ton OS."
❓-aide-jobs : "Questions sur les jobs, composants, connexions BDD, erreurs d'exécution."
❓-aide-migration : "Spécifique migration depuis Talend Open Studio : compatibilité .item, .properties, procédures."
🔒-aide-securite : "[Restreint @Contributeur+] Questions sur la sécurité de Talaxie, fixes, hardening."
📎-partage-screenshots : "Captures d'écran de logs et configurations. ANONYMISE les credentials avant envoi."
🧵-threads-support : "Format forum : un thread = un problème. Crée un nouveau thread pour chaque question."
```

---

## PHASE 5 — Salons textuels (🔧 CONTRIBUTION & DÉVELOPPEMENT)

```
Dans la catégorie "🔧 CONTRIBUTION & DÉVELOPPEMENT", crée ces salons textuels :
- 🤝-contribuer
- 💻-dev-core
- 🔌-dev-composants
- 🧪-ci-cd
- 📋-code-review
- 🔒-security-response

Descriptions :
🤝-contribuer : "Guide pour faire sa première PR, signer le CLA, trouver un 'good first issue'."
💻-dev-core : "Architecture Java, refactoring, choix technologiques, modernisation du code."
🔌-dev-composants : "Développement de nouveaux connecteurs et composants. Partage de templates et retours."
🧪-ci-cd : "Pipelines GitHub Actions, tests automatisés, builds cassés, infra de build."
📋-code-review : "Demande de relecture informelle avant PR. Discussion sur les patterns et conventions."
🔒-security-response : "[Restreint @Security Team] Coordination des fixes de sécurité et divulgation responsable."
```

---

## PHASE 6 — Salons textuels (📚 DOCUMENTATION & SAVOIR)

```
Dans la catégorie "📚 DOCUMENTATION & SAVOIR", crée ces salons textuels :
- 📖-docs-feedback
- 📝-tutoriels
- 🔗-veille

Descriptions :
📖-docs-feedback : "Retours sur la documentation Docusaurus : pages obsolètes, erreurs, suggestions."
📝-tutoriels : "Partage de tutoriels communautaires : vidéos, articles, notebooks, walkthroughs."
🔗-veille : "Veille ETL/ELT : articles, nouveaux outils, benchmarks, conférences, appels à speakers."
```

---

## PHASE 7 — Salons textuels (🏢 GOVERNANCE & PROJET)

```
Dans la catégorie "🏢 GOVERNANCE & PROJET", crée ces salons textuels :
- 📊-roadmap
- 🏛️-tsc-public
- 🤝-partenariats

Descriptions :
📊-roadmap : "Discussion publique de la roadmap. Les décisions se prennent sur GitHub Projects, pas ici."
🏛️-tsc-public : "Compte-rendus des réunions du Technical Steering Committee. Transparence totale."
🤝-partenariats : "Discussions avec entreprises souhaitant sponsoriser ou contribuer au projet. Modéré."
```

---

## PHASE 8 — Salons vocaux (🎙️ VOCAL & ÉVÉNEMENTS)

```
Dans la catégorie "🎙️ VOCAL & ÉVÉNEMENTS", crée ces salons vocaux :
- 🎙️-salon-general
- 🎙️-help-desk
- 🎙️-meetup
- 🔴-live-coding

Descriptions :
🎙️-salon-general : "Discussions vocales informelles. Pas besoin de micro pour écouter."
🎙️-help-desk : "Support vocal en direct selon les horaires des volontaires. Planning dans #📢-annonces."
🎙️-meetup : "Présentations communautaires mensuelles. Enregistrement avec opt-in uniquement."
🔴-live-coding : "Sessions de live coding sur le refactoring de Talaxie. Planning dans #📢-annonces."
```

---

## PHASE 9 — Salons BOTS & LOGS

```
Dans la catégorie "🤖 BOTS & LOGS", crée ces salons textuels et configure les permissions pour que seuls les admins et modérateurs puissent écrire :
- 🤖-bot-commands
- 🔔-github-feed
- 🔔-ci-feed
- 📋-mod-logs
- 🚨-security-alerts

Descriptions :
🤖-bot-commands : "Commandes publiques des bots : /help, /doc, /issue. Pas de discussion ici."
🔔-github-feed : "Flux automatique des événements GitHub : PR, issues, releases, commits."
🔔-ci-feed : "Flux automatique des builds CI : succès, échecs, résultats de tests."
📋-mod-logs : "Logs des actions de modération. Accès restreint à l'équipe de modération."
🚨-security-alerts : "Alertes automatiques de vulnérabilités : Dependabot, Snyk, rapports d'audit."
```

---

## PHASE 10 — Rôles

```
Crée les rôles suivants sur le serveur avec les couleurs indiquées :

Hiérarchiques :
- @Nouveau (Gris #95a5a6)
- @Utilisateur (Bleu #3498db)
- @Contributeur (Vert #2ecc71)
- @Maintainer (Orange #e67e22)
- @Security Team (Rouge #e74c3c)
- @TSC (Violet #9b59b6)
- @Admin (Noir #2c3e50)

Thématiques (cumulables) :
- @Java Dev (Bleu ciel #5dade2)
- @Data Engineer (Vert clair #58d68d)
- @Admin Sys (Rouge clair #ec7063)
- @Traducteur (Jaune #f4d03f)
- @Bug Hunter (Violet clair #af7ac5)
- @Mentor (Blanc #ecf0f1)

Notification (pingables) :
- @Announcements (Or #f1c40f)
- @Help Needed (Rouge vif #ff0000)
- @Release Ping (Bleu foncé #1a5276)
```

---

## PHASE 11 — Permissions sensibles

```
Configure les permissions suivantes :

1. Dans le salon 🔒-aide-securite :
   - Interdire @everyone de voir le salon
   - Autoriser @Contributeur, @Security Team, @TSC, @Admin

2. Dans le salon 🔒-security-response :
   - Interdire @everyone de voir le salon
   - Autoriser uniquement @Security Team, @TSC, @Admin

3. Dans le salon 📋-mod-logs :
   - Interdire @everyone de voir le salon
   - Autoriser @Maintainer, @Admin

4. Dans le salon 🚨-security-alerts :
   - Interdire @everyone d'écrire
   - Autoriser uniquement les bots à écrire

5. Dans les salons 🔔-github-feed et 🔔-ci-feed :
   - Interdire @everyone d'écrire
   - Autoriser uniquement les webhooks/bots à écrire

6. Dans le salon 📢-annonces :
   - Interdire @everyone d'écrire
   - Autoriser @Admin, @TSC à écrire

7. Dans le salon 🤖-bot-commands :
   - Interdire @everyone d'écrire
   - Autoriser les bots et @Admin
```

---

## PHASE 12 — Message d'onboarding

```
Envoie ce message dans #🚀-onboarding et épingle-le :

👋 Bienvenue sur Talaxie Community !

Tu viens de rejoindre le serveur Discord du projet Talaxie — le fork communautaire open source de Talend Open Studio.

🎯 C'est quoi Talaxie ?
Talaxie est un outil d'intégration de données (ETL/ELT) qui reprend le flambeau de Talend Open Studio après l'arrêt de sa version gratuite par Qlik.

🏗️ Structure du serveur
• Poser une question technique → #❓-aide-installation
• Aide sur un job ou un composant → #❓-aide-jobs
• Tu migrés depuis Talend → #❓-aide-migration
• Discuter développement Java → #💻-dev-core
• Proposer un nouveau connecteur → #🔌-dev-composants
• Discuter de la roadmap → #📊-roadmap

🎭 Choisis tes rôles
Réagis avec l'emoji correspondant pour t'attribuer les rôles adaptés :
🟦 @Java Dev | 🟩 @Data Engineer | 🟥 @Admin Sys
🟨 @Traducteur | 🟪 @Bug Hunter | ⬜ @Mentor

📚 Ressources essentielles
• Documentation : https://docs.talaxie.org
• Organisation GitHub : https://github.com/Talaxie
• Site web : https://talaxie.github.io
• Tutoriels vidéo : (à venir)

⚠️ Avant de poser une question
1. Utilise la fonction recherche
2. Donne du contexte : version Talaxie, Java, OS, message d'erreur
3. Anonymise : masque les mots de passe et tokens dans les screenshots

🤝 Tu veux contribuer ?
Va dans #🤝-contribuer et consulte le guide "Good First Issue" !
```

Puis ajoute les réactions 🟦 🟩 🟥 🟨 🟪 ⬜ au message.
```

---

## PHASE 13 — Règlement

```
Envoie ce message dans #📜-regles et épingle-le :

📜 Règlement — Talaxie Community

1. Respect et bienveillance
→ Pas d'insultes, de harcèlement, de discriminations. Zéro tolérance.

2. Contenu technique
→ Ce serveur est dédié à Talaxie, l'ETL/ELT et la data.

3. Sécurité — RÈGLE D'OR 🔒
→ JAMAIS de credentials, tokens, mots de passe ou clés SSH dans les salons.
→ Utilise des exemples fictifs dans les captures d'écran.

4. Confidentialité
→ Ne poste jamais de fichiers contenant des données personnelles (RGPD).

5. Pas de publicité déguisée
→ Le consulting est toléré s'il est transparent. Pas de spam en MP.

6. Divulgation responsable
→ Découverte d'une vulnérabilité ? Contacte un @Admin en MP. Jamais de détails publics avant patch.

Sanctions :
• Spam → Warn → Mute
• Toxicité → Warn → Mute 24h → Kick → Ban
• Fuite de credentials → Suppression + Ban temporaire
• Piratage (crack licence) → Ban permanent

En restant sur ce serveur, tu acceptes ce règlement.
```

Puis configure le règlement comme modal d'accueil obligatoire (Paramètres du serveur → Communauté → Règlement).
```

---

## PHASE 14 — Webhooks

```
Crée ces webhooks dans les salons correspondants :

1. Dans #🔔-github-feed :
   Nom : "github-talaxie"

2. Dans #🔔-ci-feed :
   Nom : "ci-talaxie"

3. Dans #🚨-security-alerts :
   Nom : "security-alerts"

Note : Les URLs des webhooks seront à configurer côté GitHub (Settings > Webhooks) ou via GitHub Actions.
```

---

## ✅ Checklist post-configuration

Après avoir exécuté toutes les phases, vérifie manuellement :

- [x] Les 8 catégories sont créées et dans le bon ordre
- [x] Tous les salons textuels et vocaux sont créés avec les bons emojis
- [x] Les descriptions sont configurées
- [x] Les permissions sensibles (#security-response, #mod-logs) sont bien restreintes
- [x] Les rôles sont créés avec les bonnes couleurs
- [x] Le message d'onboarding est épinglé avec les 6 réactions
- [x] Le règlement est configuré comme modal d'accueil
- [x] Les webhooks sont créés sur Discord
- [ ] Les webhooks sont configurés côté GitHub (https://github.com/organizations/Talaxie/settings/hooks)
- [x] Le bot a les bonnes permissions mais pas ADMINISTRATOR en permanence

---

*Généré pour Talaxie Community — April 2026*
