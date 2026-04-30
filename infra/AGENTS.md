# AGENTS.md — infra/

> Onboarding pour agents IA travaillant sur l'infrastructure et le déploiement de Talaxie.

## Nature du dossier

Tout ce qui concerne le **déploiement, l'infrastructure et l'opérationnel** de l'écosystème Talaxie : scripts de migration, configuration de production, secrets de déploiement.

```
infra/
├── AGENTS.md             ← ce fichier
├── migrate-to-vps.sh     ← script de migration OVH mutualisé → VPS
├── .env                  ← gitignored — secrets de production (OVH, FTP, DB, SSH)
└── .env.example          ← template documentant les variables attendues
```

## Conventions

- **`infra/.env`** est **strictement secret** : credentials OVH, accès SSH/FTP production, password DB production. Il est gitignoré (`.env*` à la racine). **Jamais** logger son contenu, **jamais** le pousser quelque part de public.
- **`infra/migrate-to-vps.sh`** s'exécute **sur le VPS cible**, pas en local. Le workflow standard :
  ```bash
  rsync -avz --exclude='.venv' --exclude='__pycache__' \
      Talaxie-Project/ root@NEW_VPS_IP:/tmp/talaxie-migration/
  ssh root@NEW_VPS_IP 'sudo bash /tmp/talaxie-migration/infra/migrate-to-vps.sh'
  ```
- **Idempotence** : le script de migration est **production-ready**, avec phases isolables (`--skip-phase=N`), mode `--dry-run`, et logging détaillé. **Ne pas réindenter** ni casser ce contrat sans bonne raison.
- **Pas de credentials en dur** dans les scripts : tout passe par `infra/.env`.

## Commandes utiles

```bash
# Aide du script
sudo bash infra/migrate-to-vps.sh --help

# Dry-run (n'exécute rien, affiche ce qui serait fait)
sudo bash infra/migrate-to-vps.sh --dry-run

# Lancer en sautant des phases (utile en réessai)
sudo bash infra/migrate-to-vps.sh --skip-phase=2 --skip-phase=4
```

## Skills recommandés

| Skill | Utilité |
|---|---|
| `security-review` (slash command) | Audit avant toute modification d'un script qui manipule des secrets ou des comptes système |
| `owasp-security-check` | Audit sécurité de la config Nginx générée |

## Pièges à éviter

- **Ne jamais committer `infra/.env`** ni de logs contenant des credentials OVH ou des passwords production.
- **Ne pas désactiver `set -euo pipefail`** dans les scripts bash : c'est une protection essentielle pour les opérations de production.
- **Ne pas remplacer `--skip-phase` par une refonte** : le mécanisme permet de réessayer une migration partiellement échouée sans tout reprendre. Très précieux en prod.
- **Toujours tester en `--dry-run` avant un vrai run** sur un VPS.
- **Ne pas modifier les permissions UFW / firewall** sans plan de retour arrière documenté.

## Règle générale héritée du repo

- **Aucune référence à l'agent IA** dans commits, PRs, code ou documentation publique (sauf les `AGENTS.md` eux-mêmes). Voir la règle complète dans `../AGENTS.md` (racine).
