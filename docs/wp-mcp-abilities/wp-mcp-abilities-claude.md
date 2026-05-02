# Architecture MCP « sudo-style » pour Talaxie WordPress

> Réponse de cadrage à la mission décrite dans
> [`prompts/mcp-sudo-architecture.md`](../prompts/mcp-sudo-architecture.md).
> Ce document détaille la proposition d'architecture pour exposer le
> site WordPress aux agents IA avec un mécanisme d'élévation
> de privilèges inspiré d'Unix `sudo`.

## 1. Vue d'ensemble

Trois piliers qui s'emboîtent :

1. **Un rôle WordPress dédié `ai_bot`** avec des capabilities limitées
   (analogue à un user Unix non-root). Le compte applicatif utilisé
   par l'agent IA appartient à ce rôle.
2. **Un mécanisme de sudo tokens** : un humain admin génère depuis
   wp-admin (ou WP-CLI) un token scopé à une capability et expirant
   après un TTL court. L'agent IA passe ce token comme paramètre
   `_sudo` dans les appels d'abilities qui exigent une capability
   au-delà du rôle `ai_bot`.
3. **Un `AbilityRegistry`** où chaque ability déclare *de manière
   déclarative* la capability qu'elle exige. Une seule méthode dans
   la classe de base, `require_capability_or_sudo()`, centralise le
   contrôle d'accès. Pas de check disséminé.

L'audit est systématique. Les actions destructives en prod sont
supplémentairement gardées par une whitelist.

## 2. Flow d'exécution

### Action non-impactante (cas nominal — 95 % du trafic)

```
[Claude Code]                       [WordPress]
   │                                   │
   │ POST /wp-json/mcp/...             │
   │ tool: talaxie/releases/list       │
   │ auth: Basic <ai_bot>              │
   │ ─────────────────────────────────►│
   │                                   │ AbstractAbility::dispatch()
   │                                   │   required_cap = edit_talaxie_releases
   │                                   │   current_user_can() ? ✓
   │                                   │   AuditLogger::log(action, sudo_used=false)
   │                                   │   execute()
   │ ◄─────────────────────────────────│
   │ JSON-RPC result                   │
```

### Action impactante (élévation requise)

```
[Humain]            [Claude Code]                  [WordPress]
   │                    │                             │
   │                    │ tool: wp/options/update     │
   │                    │ ─────────────────────────► │
   │                    │                             │ required_cap = manage_options
   │                    │                             │ current_user_can() ? ✗
   │                    │                             │ _sudo missing → 401 permission_denied
   │                    │ ◄────────────────────────── │
   │ « j'ai besoin d'un │                             │
   │   sudo manage_     │                             │
   │   options »        │                             │
   │ ◄──────────────────│                             │
   │                    │                             │
   │ wp-admin > MCP Sudo                              │
   │ (génère token,                                   │
   │  scope=manage_options, ttl=15min)                │
   │                                                  │ TokenManager::create()
   │                                                  │   stocke hash en DB
   │                    affiche tlx_sudo_a3F8...      │
   │                                                  │
   │ « voici tlx_sudo_a3F8...kL0Q »                   │
   │ ─────────────────► │                             │
   │                    │ retry tool: wp/options/update│
   │                    │ + _sudo: tlx_sudo_a3F8...   │
   │                    │ ─────────────────────────► │
   │                    │                             │ TokenManager::validate(token, cap)
   │                    │                             │ ✓
   │                    │                             │ AuditLogger::log(sudo_used=true)
   │                    │                             │ execute()
   │                    │ ◄────────────────────────── │
```

## 3. Pilier 1 — Le rôle `ai_bot`

Créé à l'activation du plugin (`register_activation_hook`), supprimé à
la désinstallation (`uninstall.php`).

| Capabilities accordées                                                       | Justification                              |
|------------------------------------------------------------------------------|--------------------------------------------|
| `read`                                                                       | Frontend public + dashboard de base        |
| `edit_posts`, `edit_published_posts`                                         | Le bot peut écrire/modifier des articles   |
| `edit_pages`, `edit_published_pages`                                         | Idem pages                                 |
| `upload_files`                                                               | Joindre des médias                         |
| `read_private_posts`                                                         | Voir les drafts pour pouvoir les compléter |
| `edit_talaxie_release`, `edit_talaxie_contributor`, `edit_talaxie_component` | CPT métier — c'est *le job* du bot         |
| `read_private_talaxie_*`                                                     | Idem mais pour les drafts métier           |

| Capabilities refusées explicitement                                  | Conséquence                          |
|----------------------------------------------------------------------|--------------------------------------|
| `manage_options`                                                     | Pas de modification des réglages     |
| `delete_posts`, `delete_pages`                                       | Pas de suppression sans sudo         |
| `manage_users`, `create_users`, `edit_users`, `delete_users`         | Pas de manipulation de comptes       |
| `activate_plugins`, `update_plugins`, `update_core`, `update_themes` | Pas d'altération de l'infrastructure |
| `unfiltered_html`, `unfiltered_upload`                               | Pas de scripts injectables           |
| `manage_categories`                                                  | Pas de réorganisation taxonomique    |

Toutes ces capabilities refusées au quotidien restent atteignables via
le mécanisme sudo.

## 4. Pilier 2 — Sudo tokens

### Génération

Trois canaux équivalents, qui invoquent tous le même `TokenManager` :

- **Page wp-admin** `Talaxie > MCP Sudo` (form + POST nonce-protégé)
- **WP-CLI** : `wp talaxie mcp sudo-token --scope=manage_options --ttl=15m`
- **Endpoint REST** `POST /wp-json/talaxie-core/v1/mcp/sudo-token`
  (capability `manage_options` requise sur l'appelant)

### Spec d'un token

| Champ               | Valeur                                                                                                                                         |
|---------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| Format              | `tlx_sudo_` + 32 caractères base62                                                                                                             |
| Stockage en DB      | `password_hash($token, PASSWORD_BCRYPT)` — jamais le token brut                                                                                |
| Stockage paramètres | Table custom `wp_talaxie_sudo_tokens` (id, token_hash, scope, created_at, expires_at, revoked_at, single_use, usage_count, created_by_user_id) |
| TTL                 | Configurable, défaut 15 min, max 60 min (constante `TALAXIE_MCP_SUDO_MAX_TTL`)                                                                 |
| Scope               | Liste de capabilities (ex: `["manage_options"]` ou `["edit_users", "delete_users"]`)                                                           |
| Single-use          | Optionnel, default false                                                                                                                       |
| Affichage           | Une seule fois à la création (comme un app password WP)                                                                                        |

### Validation

```
TokenManager::validate( string $token, string $required_cap ): bool
  - Hashe token et cherche en DB
  - Refuse si revoked_at != null OR expires_at < now()
  - Refuse si required_cap not in scope
  - Refuse si single_use && usage_count > 0
  - Incrémente usage_count, écrit l'event d'audit
  - Retourne true
```

### Révocation

- Bouton « revoke all » dans wp-admin (révoque tous les tokens vivants)
- Auto-révocation à expiration (cron quotidien qui purge la table)
- Révocation à la désinstallation du plugin (`uninstall.php`)

### Hashing : pourquoi pas un transient ?

Un transient avec le token brut serait en clair dans la table options.
Un attaquant qui lit `wp_options` (ex: backup non chiffré, log d'erreur
mal filtré) accède à toutes les élévations actives. Avec `password_hash`,
même un dump complet de la table custom ne suffit pas : il faudrait
brute-forcer.

## 5. Pilier 3 — `AbilityRegistry` et déclaration de capability

### Classe de base

```php
<?php
declare(strict_types=1);

namespace Talaxie\Core\Mcp\Abilities;

abstract class AbstractAbility {

    abstract public function get_name(): string;
    abstract public function get_description(): string;
    abstract public function get_input_schema(): array;
    abstract public function get_required_capability(): string;

    /**
     * Production-only abilities can override to return false.
     * Used to gate destructive abilities on the prod MCP server.
     */
    public function is_allowed_on_production(): bool {
        return true;
    }

    public function execute( array $input ) {
        $this->require_capability_or_sudo(
            $input['_sudo'] ?? null
        );
        return $this->do_execute( $input );
    }

    abstract protected function do_execute( array $input );

    final protected function require_capability_or_sudo( ?string $token ): void {
        $cap = $this->get_required_capability();

        if ( current_user_can( $cap ) ) {
            \Talaxie\Core\Mcp\Audit\AuditLogger::log( $this, false );
            return;
        }

        if ( $token && \Talaxie\Core\Mcp\Sudo\TokenManager::validate( $token, $cap ) ) {
            \Talaxie\Core\Mcp\Audit\AuditLogger::log( $this, true );
            return;
        }

        throw new \WP_Error(
            'permission_denied',
            sprintf(
                /* translators: %s: capability name */
                __( 'This ability requires the "%s" capability. Provide a sudo token in the "_sudo" parameter.', 'talaxie-core' ),
                $cap
            ),
            array( 'status' => 401, 'required_capability' => $cap )
        );
    }
}
```

### Exemple concret

```php
<?php
declare(strict_types=1);

namespace Talaxie\Core\Mcp\Abilities\Site;

use Talaxie\Core\Mcp\Abilities\AbstractAbility;

final class UpdateOption extends AbstractAbility {

    public function get_name(): string {
        return 'wp/options/update';
    }

    public function get_description(): string {
        return 'Update a WordPress option. Requires manage_options capability.';
    }

    public function get_required_capability(): string {
        return 'manage_options';
    }

    public function get_input_schema(): array {
        return array(
            'type'       => 'object',
            'properties' => array(
                'option_name'  => array( 'type' => 'string' ),
                'option_value' => array( 'type' => array( 'string', 'number', 'boolean', 'object' ) ),
                '_sudo'        => array(
                    'type'        => 'string',
                    'description' => 'Sudo token if user lacks manage_options.',
                ),
            ),
            'required'   => array( 'option_name', 'option_value' ),
        );
    }

    public function is_allowed_on_production(): bool {
        return false;   // never allow option updates over MCP in production
    }

    protected function do_execute( array $input ) {
        $allowed = array( 'blogname', 'blogdescription', 'permalink_structure', 'date_format', 'time_format' );
        if ( ! in_array( $input['option_name'], $allowed, true ) ) {
            throw new \WP_Error(
                'option_not_allowlisted',
                __( 'This option is not in the MCP-allowlist.', 'talaxie-core' ),
                array( 'status' => 403 )
            );
        }
        return update_option( $input['option_name'], $input['option_value'] );
    }
}
```

## 6. Arborescence proposée

```
src/Mcp/
├── Server.php                     ← bootstrap MCP server, registre les abilities sur l'init
├── AbilityRegistry.php            ← registre interne, résolution par nom
├── Abilities/
│   ├── AbstractAbility.php        ← base : require_capability_or_sudo, execute, audit
│   ├── Site/
│   │   ├── GetInfo.php            ← cap: read              (jamais sudo)
│   │   ├── GetOption.php          ← cap: manage_options    (sudo)
│   │   └── UpdateOption.php       ← cap: manage_options    (sudo, prod-blocked)
│   ├── Posts/
│   │   ├── ListPosts.php          ← cap: edit_posts        (ai_bot OK)
│   │   ├── GetPost.php            ← cap: edit_posts
│   │   ├── CreatePost.php         ← cap: edit_posts
│   │   ├── UpdatePost.php         ← cap: edit_posts
│   │   └── DeletePost.php         ← cap: delete_posts      (sudo)
│   ├── Pages/                     ← idem Posts/
│   ├── Media/
│   │   ├── ListMedia.php
│   │   ├── UploadMedia.php
│   │   └── DeleteMedia.php        ← cap: delete_posts (sudo)
│   ├── Users/
│   │   ├── ListUsers.php          ← cap: list_users        (sudo)
│   │   ├── GetUser.php
│   │   ├── CreateUser.php         ← cap: create_users      (sudo, prod-blocked)
│   │   └── UpdateUser.php         ← cap: edit_users        (sudo)
│   ├── Releases/                  ← CPT Talaxie, sans sudo (c'est le rôle du bot)
│   │   ├── ListReleases.php
│   │   ├── GetRelease.php
│   │   ├── CreateRelease.php
│   │   ├── UpdateRelease.php
│   │   └── DeleteRelease.php
│   ├── Contributors/              ← idem
│   ├── Components/                ← idem
│   ├── Plugins/
│   │   ├── ListPlugins.php
│   │   └── ActivatePlugin.php     ← cap: activate_plugins  (sudo, prod-blocked)
│   └── Generic/
│       └── RestCall.php           ← fallback : forwards à wp-json/wp/v2/* avec mapping cap par méthode HTTP
├── Sudo/
│   ├── TokenManager.php           ← create / validate / revoke / sweep
│   ├── TokenSchema.php            ← création de la table custom à l'activation
│   ├── AdminPage.php              ← écran wp-admin > Talaxie > MCP Sudo
│   ├── CliCommand.php             ← wp talaxie mcp sudo-token
│   └── RestController.php         ← POST /talaxie-core/v1/mcp/sudo-token
├── Roles/
│   └── AiBotRole.php              ← add_role / remove_role + helpers cap
└── Audit/
    ├── AuditLogger.php            ← écrit dans le CPT
    ├── AuditPostType.php          ← CPT non-public, listable en admin
    └── AuditRetention.php         ← cron quotidien : purge > 30 jours
```

## 7. Asymétrie test/prod

Le plugin enregistre **deux serveurs MCP** distincts :

| Serveur | Slug MCP                  | Set d'abilities                                                   | Sécurité   |
|---------|---------------------------|-------------------------------------------------------------------|------------|
| Test    | `talaxie-mcp-test-server` | Toutes (CRUD complet, options, plugins, users, generic rest-call) | Permissif  |
| Prod    | `talaxie-mcp-prod-server` | Filtrées par `is_allowed_on_production() === true`                | Restrictif |

L'enregistrement filtre **automatiquement** : à l'init, on parcourt
toutes les abilities et on ne pousse sur le serveur prod que celles
qui retournent `true` à `is_allowed_on_production()`.

Ainsi `Site/UpdateOption`, `Plugins/ActivatePlugin`, `Users/CreateUser`
ne sont **physiquement pas exposées** sur prod, même avec un sudo
token valide. Pour les exposer en cas de crise, il faut redéployer le
plugin avec un override (constante `TALAXIE_MCP_PROD_DESTRUCTIVE = true`).

## 8. Audit

CPT `talaxie_mcp_audit` non-public, listable depuis l'admin.

Chaque entrée stocke :

- Nom de l'ability
- Utilisateur authentifié (ID + login)
- Timestamp
- IP source (`REMOTE_ADDR`)
- `sudo_used` boolean
- Hash partiel du sudo token (8 premiers chars du hash bcrypt) — pour
  corréler avec un token donné sans exposer la totalité
- Snapshot des inputs (avec `_sudo` masqué : `***REDACTED***`)
- Statut (success / permission_denied / validation_error)
- Message d'erreur le cas échéant

Rétention 30 jours par cron quotidien (`talaxie_mcp_audit_purge`).

Lecture exposée via une ability `talaxie/audit/list` (cap : `manage_options`).

## 9. Compromis et alternatives écartées

| Alternative                                       | Raison du rejet                                                                                                                                                                                                                                                    |
|---------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **OAuth2 / JWT** au lieu de sudo tokens           | Overkill pour le cas d'usage. WordPress n'a pas de support OAuth2 natif, ajouter un OAuth provider triple le scope. JWT serait stateless (pas révocable côté serveur) et ferait perdre l'audit fin. Les sudo tokens stateful en DB sont plus simples et plus sûrs. |
| **Un user MCP par capability** (un user par rôle) | Multiplier les comptes complique l'audit. Avec un seul user `ai_bot` + élévation explicite, on a une trace unifiée.                                                                                                                                                |
| **Bypass via constante `WP_DEBUG`**               | `WP_DEBUG` est souvent à `true` en staging accessible publiquement. Dangereux. À la place, constante dédiée `TALAXIE_MCP_DEV_MODE` à activer explicitement.                                                                                                        |
| **Tokens en transient WP**                        | Lecture en clair dans `wp_options` si dump DB. Préférer une table dédiée avec hash.                                                                                                                                                                                |
| **1 seule ability générique `wp/rest-call`**      | Le LLM doit deviner les bons endpoints REST. Beaucoup d'erreurs en pratique. On garde `RestCall` comme **fallback** seulement, pas comme cas nominal.                                                                                                              |

## 10. Risques résiduels (non éliminés par cette architecture)

1. **Vol du `~/.claude.json`** — l'app password admin (test ou prod) y
   est stocké en base64 réversible. N'importe quel processus tournant
   en tant que cet utilisateur peut le lire. Mitigation : `chmod 600
   ~/.claude.json`, ne pas mounter le home dans des conteneurs douteux.
   **L'architecture sudo n'aide pas ici** : si le password de base est
   volé, l'attaquant peut au minimum agir avec les droits `ai_bot`,
   ce qui inclut publier des articles.

2. **Sudo tokens transmis en clair via le canal LLM** — quand l'humain
   donne le token au bot, ce token transite dans la conversation
   (vendor LLM, logs Claude Code, transcripts). Un attaquant qui obtient
   les transcripts récupère les tokens valides. Mitigation : TTL très
   court (15 min), single-use pour les actions critiques, révocation
   manuelle après usage si on a un doute, audit pour détecter.

3. **Drift entre `is_allowed_on_production()` et la réalité du serveur
   exécutant** — si quelqu'un déploie en prod un fichier de config qui
   override la liste, le filtre saute silencieusement. Mitigation :
   tester l'enregistrement effectif via un endpoint
   `/talaxie-core/v1/mcp/abilities-on-server` qui liste ce qui est
   *réellement* exposé, et alerter si une ability `is_allowed_on_production
   = false` apparaît.

## 11. Multisite

Sur multisite, certaines actions exigent `super_admin` qui n'est pas
une capability classique (c'est un statut user-level).

Stratégie :

- Le `TokenManager` accepte une « capability virtuelle » `super_admin`.
- À la validation, il vérifie `is_super_admin( get_current_user_id() )`
  en plus du check standard.
- Les abilities concernant le réseau (`Network/CreateSite`,
  `Network/DeleteSite`) déclarent `get_required_capability(): 'super_admin'`.
- Le rôle `ai_bot` n'a évidemment pas le statut super_admin.

## 12. Bypass dev — fait correctement

Constante `TALAXIE_MCP_DEV_MODE` à mettre dans `wp-config.php`.

- Quand active, `require_capability_or_sudo()` ne refuse rien.
- Une **bannière rouge permanente** s'affiche dans wp-admin tant que
  la constante est active.
- Audit logge tous les events avec `dev_mode_bypass=true` pour
  permettre l'analyse post-mortem.
- Refusée si `WP_ENVIRONMENT_TYPE !== 'local' && !== 'development'`
  (WP 6.5+ expose ces helpers nativement).

## 13. Phasage d'implémentation

| Phase | Livrable                                                                                                            | Lignes estimées | Completion |
|-------|---------------------------------------------------------------------------------------------------------------------|-----------------|------------|
| 1     | Rôle `ai_bot` + `TokenManager` + `AbstractAbility` + 5 abilities (`Site/GetInfo`, `Posts/{List,Get,Create,Update}`) | ~350            | 100 %      |
| 2     | `Pages/CRUD`, `Media/{List,Upload}`, `Releases/CRUD`, `Audit/{List,PostType,Logger}`                                | ~400            | 100 %      |
| 3     | Sudo : `AdminPage` + `CliCommand` + `RestController` + asymétrie test/prod                                          | ~300            | 100 %      |
| 4     | `Users/CRUD`, `Plugins/CRUD`, `Generic/RestCall`, `Network/*` (multisite)                                           | ~500            | 100 %      |
| 5     | Audit retention cron, dev-mode banner, drift detection endpoint                                                     | ~200            | 100 %      |

Total ~1750 lignes de PHP applicatif (hors tests). Réalisé.

> **Notes de completion** (implémentation terminée)
>
> - **Phase 1 — 100 %** : rôle `ai_bot`, `TokenManager` (bcrypt + scope JSON),
>   `CapabilityGate` (qui remplace `AbstractAbility` en s'appuyant sur
>   l'API native `wp_register_ability()` de WordPress 6.9), et 5
>   abilities `Site/GetInfo` + `Posts/{List,Get,Create,Update}`.
> - **Phase 2 — 100 %** : Pages CRUD, Media (list/upload/delete),
>   Releases CRUD (CPT spécialisé en `capability_type`
>   `talaxie_release` pour permettre la suppression sans sudo), audit
>   complet (CPT non-public + Logger hook + ability `audit-list`).
> - **Phase 3 — 100 %** : `Sudo/AdminPage` (Tools > MCP Sudo, form +
>   liste des tokens vivants + revoke), `Sudo/CliCommand`
>   (`wp talaxie mcp sudo-token|sudo-list|sudo-revoke`),
>   `Sudo/RestController` (`POST/GET/DELETE
>   /wp-json/talaxie-core/v1/mcp/sudo-token`). Asymétrie test/prod
>   gérée par `wp_get_environment_type()`.
> - **Phase 4 — 100 %** : Users CRUD, Plugins/{List,Activate},
>   Site/{Get,Update}Option (avec allowlist filterable),
>   Generic/RestCall (proxy `wp/v2/*` test-server-only),
>   Network/{Create,Delete}Site pour multisite. `CapabilityGate`
>   reconnaît la « capability virtuelle » `super_admin`.
> - **Phase 5 — 100 %** : `DevMode` (bannière rouge + refus sur
>   environnements non-locaux), endpoint drift detection
>   (`GET /wp-json/talaxie-core/v1/mcp/abilities-on-server`),
>   `AuditRetention` (cron daily, livré en avance dès la phase 2).
>
> **Couverture tests** : 70 tests d'intégration PHPUnit, suite verte.
> CI GitHub Actions sur matrix PHP 8.1/8.2/8.3 × WP 6.5/latest.
>
> **Surface MCP exposée** : 30 abilities au total ; 21 sur le serveur
> production (lecture + CRUD safe), 30 sur le serveur test (incluant
> les destructives gardées par `is_allowed_on_production() = false`).

## 14. Décisions ouvertes

- **Couverture WP-CLI** des abilities : la CLI peut-elle invoquer
  directement les abilities sans passer par MCP ? (Utile pour scripts
  d'admin.) Non bloquant pour la phase 1.
  - Réponse Oui
- **Politique de cache** sur les abilities en lecture (ex: `Site/GetInfo`) : object cache 5 min ? Non bloquant.
- **Internationalisation des messages d'erreur** : actuellement en
  anglais (text-domain `talaxie-core`). À discuter avec la communauté
  Talaxie une fois la traduction française prête.
