# Mission — Architecture d'un mécanisme « sudo » pour un serveur MCP WordPress

> Prompt autonome destiné à un LLM (ou à un humain expert) chargé de
> proposer une architecture pour piloter WordPress depuis un agent IA
> avec des droits limités par défaut et une élévation temporaire.
>
> Self-contained : ne suppose pas la connaissance du projet Talaxie.

---

Tu es développeur PHP senior et expert WordPress. Aide-moi à concevoir
une architecture **reproductible**, **sécurisée** et **simple à mettre
en œuvre** pour un serveur MCP (Model Context Protocol) qui expose les
capacités d'un site WordPress à un agent IA (Claude Code, autre client
MCP), inspirée du modèle Unix `sudo`.

## Contexte technique

- **Stack** : WordPress 6.9 (PHP 8.1+, MariaDB), avec l'Abilities API
  intégrée nativement à `wp-includes/abilities-api/` (fonctions
  `wp_register_ability`, classes `WP_Ability`, `WP_Abilities_Registry`).
- **Bridge MCP** : plugin `WordPress/mcp-adapter` qui transforme les
  abilities en outils MCP exposés sur `/wp-json/mcp/<server>` via une
  authentification HTTP Basic (Application Password WP).
- **Notre code** : un plugin compagnon `talaxie-wp-core` (PSR-4,
  namespace `Talaxie\Core\`) qui définit nos abilities métier et les
  enregistre auprès du serveur MCP.
- **Périmètre fonctionnel visé** : permettre à l'agent IA de faire
  « quasiment tout ce qu'un utilisateur humain peut faire » dans
  WordPress — CRUD posts/pages/médias, gestion utilisateurs, gestion
  options, gestion plugins, etc.

## Spécificité WordPress à intégrer absolument

WordPress a un système de **rôles** (collections de capabilities) déjà
hiérarchisé : `subscriber` → `contributor` → `author` → `editor` →
`administrator` → `super_admin` (multisite). Chaque action backoffice
exige une capability précise (`edit_posts`, `manage_options`,
`activate_plugins`, `unfiltered_html`, etc.).

L'architecture doit **réutiliser ce système** plutôt que le dédoubler.

## Inspiration Unix

Comme `sudo` :

- Un **utilisateur courant** avec droits limités (analogue à un user
  non-root sans `wheel`).
- Une **élévation temporaire** ciblée, scopée, à durée de vie courte,
  révocable, auditée.
- L'élévation est **demandée par l'humain**, pas par le bot lui-même.

## Question à résoudre

Propose une architecture détaillée couvrant :

1. **Modèle conceptuel** — rôle WP par défaut pour l'agent, mécanisme
   d'élévation, cycle de vie d'une élévation.
2. **Structure du code** — arborescence `src/Mcp/`, classes clés,
   hooks WordPress impliqués (`init`, `register_activation_hook`,
   `mcp_adapter_init`…).
3. **Format des « sudo tokens »** — génération (qui, comment, où),
   stockage (transients, options, table dédiée ?), validation,
   expiration, révocation, hashing.
4. **Mapping aux niveaux WordPress** — comment une ability déclare la
   capability qu'elle exige, et comment le check fait :
   `current_user_can()` OR `valid_sudo_token($cap)`.
5. **UX humain** — comment l'humain génère/transmet un token (page
   wp-admin, commande WP-CLI, endpoint REST). Format du token
   (opaque vs lisible).
6. **Asymétrie test/prod** — en production, certaines abilities ne
   doivent jamais être exposées même avec sudo. Comment exprimer
   cette restriction de façon déclarative ?
7. **Audit** — schéma de log, rétention, restitution.
8. **Sécurité** — pièges à éviter (replay, élévation persistante par
   erreur, leak via logs, bypass en dev), rate-limit, vérification
   d'origine.
9. **Multisite** — comment gérer `super_admin` qui n'est pas une
   capability classique.

## Format de réponse attendu

- Vue d'ensemble en 5-10 lignes.
- Schéma ASCII ou table montrant le flow d'une action **non-sudo** et
  d'une action **sudo**.
- Arborescence des fichiers à créer (avec rôle de chaque classe en
  une ligne).
- Snippet PHP **minimal mais réaliste** d'une ability « exemple » qui
  illustre le check `require_capability_or_sudo()`.
- Table des compromis : 2-3 alternatives écartées avec leur raison.
- Liste des **3 risques majeurs** que cette architecture **n'élimine
  pas** et nécessitent une vigilance opérationnelle.

## Contraintes non négociables

- Le code doit passer **WordPress Coding Standards** (WPCS 3.x).
- Compatible **single-site et multisite** sans branche conditionnelle
  partout.
- **Aucun bypass implicite** : si une dev-mode constante désactive le
  check sudo, elle doit être explicite, visible dans wp-admin, et
  jamais activée par défaut.
- Le code doit être **désinstallable proprement** (rôles supprimés,
  tokens cramés, transients vidés via `uninstall.php`).
- La doc doit être **suffisante pour qu'un autre projet WordPress
  reprenne le pattern**.

## Hors scope (ne pas traiter)

- L'implémentation des abilities métier elles-mêmes (CRUD posts, etc.) —
  on suppose qu'elles existent et déclarent leur capability requise.
- Le déploiement de WordPress, du plugin mcp-adapter, ou de Claude Code.
- Les considérations de coût LLM ou de latence MCP.

Va droit au but. Pas d'introduction de courtoisie. Si une décision
demande un arbitrage que tu ne peux pas trancher seul, formule-la
explicitement comme question à l'utilisateur en fin de réponse.
