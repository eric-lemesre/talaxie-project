# Roadmap — du squelette au produit

> Document de cadrage : ce qui distingue le travail d'**infrastructure** déjà
> réalisé du travail de **produit** qui reste à faire pour que le site
> Talaxie.org soit utile à sa communauté.

## Infrastructure (déjà en place)

| Domaine          | Livré                                                                              |
|------------------|------------------------------------------------------------------------------------|
| Repos GitHub     | `Talaxie-Project` (umbrella) + `talaxie-wp-theme` + `talaxie-wp-core`              |
| Conventions      | Layout multi-repos, AGENTS.md à chaque niveau, GPL-2.0-or-later, no AI attribution |
| Outillage dev    | Composer + roots/wordpress, wp-cli pinné, WPCS 3.x, PHPCompatibility-WP            |
| Bootstrap local  | `bin/bootstrap.sh` reproductible (PHP / DB / WP / theme / plugin / activation)     |
| Reset DB local   | `bin/reset-db.sh`                                                                  |
| Déploiement prod | `infra/migrate-to-vps.sh`                                                          |
| Block Theme      | `theme.json`, 6 templates, 2 parts, 4 patterns, polices self-hosted                |
| Plugin compagnon | 2 CPT, 1 taxonomy, REST endpoints, scaffolding pour intégrations                   |
| CI               | Lint + smoke test verts sur les 2 repos publiables                                 |

Tout cela **prépare** le travail. Mais à ce stade, le site n'a encore aucune
fonctionnalité visible pour un visiteur extérieur.

## Produit (ce qui reste à faire)

Trois axes distincts à faire avancer en parallèle :

### 1. Contenu fonctionnel — du code qui fait quelque chose

À ce jour, `talaxie-wp-core` expose 2 CPT et 1 taxonomy **vides** : les
endpoints REST existent mais retournent toujours `[]`. Le thème affiche
donc des cartes vides dans son pattern `news-list`.

À implémenter par ordre de priorité :

- **`Integrations/GitHub/ReleaseSyncer`** : appel cron de l'API GitHub
  `https://api.github.com/repos/Talaxie/.../releases` via `wp_remote_get`,
  parse JSON, crée ou met à jour les posts `talaxie_release`. Gestion du
  rate-limit, des releases marquées draft, du tagging par composant.
- **`Integrations/Discord/StatsFetcher`** : compteur de membres en ligne,
  derniers messages d'annonce. Cache 5 min pour respecter le rate-limit
  Discord.
- **`Integrations/Discourse/ThreadEmbed`** : récupération des derniers
  threads ouverts pour affichage en page d'accueil.
- **`Integrations/Docusaurus/LinkResolver`** : résolution de liens
  `talaxie://docs/<page>` vers l'instance Docusaurus officielle.
- **Blocs serveur côté thème** : un bloc Gutenberg `talaxie/release-card`
  qui consomme `wp_remote_get('/wp-json/wp/v2/releases')` et rend une
  carte stylée. Idem pour `talaxie/contributor-grid`.

### 2. Contenu rédactionnel — du texte pour les humains

Aucune ligne de code requise pour cet axe. Tout passe par
`wp-admin > Pages` et `wp-admin > Articles`, idéalement en utilisant les
patterns du thème comme briques de mise en page :

- **Pages institutionnelles** : « À propos de Talaxie »,
  « Gouvernance », « Roadmap », « FAQ », « Charte de contribution »,
  « Mentions légales ».
- **Pages techniques** : « Téléchargements » (structurée par composant),
  « Migration depuis Talend Open Studio », « Premier job avec Talaxie »,
  « Architecture des composants ».
- **Premières actualités** : annonces des releases, billets sur la
  gouvernance, retours communautaires.

Ces contenus peuvent être rédigés au fil de l'eau par n'importe quel
contributeur disposant d'un compte éditeur.

### 3. Contenu visuel — l'identité finalisée

- **Vrai logo Talaxie** au format SVG (placeholder pour l'instant).
- **Vrai screenshot.png** du thème (1200×900) pour la fiche WordPress.org —
  capture du rendu réel avec contenu de démo, pas l'image générée par
  ImageMagick actuellement embarquée.
- **Illustrations de hero** ou icônes pour les cartes "Why Talaxie?" qui
  n'ont aujourd'hui que du texte.
- **Avatars contributeurs** si on choisit de les afficher (sinon Gravatar
  par défaut suffit).

## Recommandation senior — par où commencer

Si on hiérarchise :

1. **Axe 1 — un seul connecteur** : implémenter `GitHub/ReleaseSyncer`
   pour vraiment alimenter les `talaxie_release` depuis le repo GitHub
   Talaxie. C'est l'épine dorsale du site (un site sans données fraîches =
   un site mort). Une fois fait, le pattern `news-list` du thème montrera
   de vrais contenus et la valeur du site devient visible.
2. **Axe 3 — l'identité** : un vrai logo SVG et un vrai screenshot. Sans
   ça, le thème publié sur WordPress.org aura l'air bricolé et la
   review WP.org sera plus difficile.
3. **Axe 2 — le rédactionnel** : à faire en continu, par des contributeurs
   communautaires sans dépendance à du dev. Peut démarrer dès qu'une
   maquette de site est navigable.

Cette priorisation peut être révisée selon les contraintes (par exemple
si une release Talaxie majeure est prévue — alors l'axe 1 devient
strictement prioritaire pour qu'elle apparaisse sur le site).
