# 04 — Manuel de mise à jour

> Procédure pour publier une nouvelle version de GauthierFitness en production, gérer les migrations DB, mettre à jour
> les dépendances et exécuter un rollback si nécessaire. Couvre les compétences RNCP **C2.4.1** (documentation) et *
*C4.1.1** (gestion des mises à jour de dépendances).

---

## 1. Cycle de release

```
feature → develop          (staging auto)
develop → main             (production manuel)
main    → tag vX.Y.Z       (versioning sémantique)
```

### Convention de version (SemVer)

- **MAJOR** (`vX.0.0`) - changement cassant d'API publique ou de schéma DB sans migration backward-compatible.
- **MINOR** (`v1.X.0`) - nouvelle fonctionnalité, sans casser l'existant.
- **PATCH** (`v1.0.X`) - bugfix, perf, sécurité.

La version est portée par :

- Le tag Git (`git tag v1.2.0`)
- Le tag Docker image (`ghcr.io/.../gauthierfitness-backend:v1.2.0`)
- La variable `API_VERSION` dans `.env` (lue par Scramble pour l'OpenAPI)

---

## 2. Préparer une release

### Étape 1 - Geler develop

1. Vérifier que `develop` est stable sur staging (manuels, tests, retours QA).
2. Annoncer le freeze dans le canal d'équipe (pas de nouveau merge sur `develop`).

### Étape 2 - Mettre à jour les versions

```bash
# Backend
cd backend
# Bumper API_VERSION dans .env.example (servira de défaut)
# Bumper la version dans composer.json si pertinent

# Frontend
cd ../frontend
npm version 1.2.0 --no-git-tag-version
git add package.json package-lock.json
git commit -m "chore: bump version 1.2.0"
```

### Étape 3 - Rédiger le CHANGELOG

Ajouter une section en haut de `CHANGELOG.md` (à créer s'il n'existe pas) :

```markdown
## v1.2.0 - 2026-06-17

### Added

- Génération de design IA via OpenAI (GF18)
- Mode formulaire accessible dans l'éditeur 2D (GF19)

### Changed

- Migration Laravel 12 → 13
- Mise à jour des dépendances composer / npm

### Fixed

- Bug d'arrondi sur les totaux TTC avec options multiples (GF20)

### Security

- Mots de passe MySQL sortis du docker-compose.yml (GF23)
```

### Étape 4 — PR develop → main

1. Ouvrir une PR `develop → main` avec le CHANGELOG comme description.
2. Review obligatoire (même en solo : 24 h de relecture à froid).
3. Vérifier que la CI est verte.
4. Merger en **« Merge commit »** (pas squash, pour préserver l'historique).

### Étape 5 — Tagger

```bash
git checkout main
git pull
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

---

## 3. Déployer en production

Voir aussi [02-deployment.md § Déploiement production](./02-deployment.md#déploiement-production--manuel-avec-gate).

### Procédure standard

1. Sur GitHub Actions, déclencher manuellement `deploy-prod` avec le tag (`v1.2.0`) ou le sha de main.
2. Le runner se connecte au VPS prod et exécute `infra/scripts/deploy-prod.sh`.
3. Le script :
    - Pull le code (`git pull origin main`)
    - Pull les nouvelles images Docker
    - Active le mode maintenance (`artisan down`)
    - Exécute les migrations (`artisan migrate --force`)
    - Redémarre les conteneurs
    - Re-cache config / routes / views / events
    - Désactive le mode maintenance (`artisan up`)
    - Health check (`curl /api/health`)

### Surveillance post-déploiement

Pendant les 30 minutes qui suivent :

- Vérifier les logs Laravel : `docker compose logs -f gf_backend_app | grep -i error`
- Vérifier les webhooks Stripe Dashboard (pas de failure massive).
- Tester un parcours d'achat de bout en bout (compte test → commande test).
- Surveiller le taux de réponse 5xx via les logs Nginx.

---

## 4. Migrations de base de données

### Règles d'or

- **Toujours backward-compatible sur N versions** — un déploiement progressif doit pouvoir coexister avec l'ancienne
  version du code pendant la migration.
- **Pas de DROP COLUMN dans la même release que la dépréciation** — déprécier en V1, supprimer en V2.
- **Index sur les FK toujours créés avec la migration** — performance & cohérence.
- **Tester sur une copie de la prod** avant chaque migration risquée.

### Procédure pour une migration risquée

```bash
# 1. Backup avant tout
mysqldump -u root -p gauthier_fitness > backup-pre-v1.2.0.sql
gpg --encrypt --recipient charles@... backup-pre-v1.2.0.sql

# 2. Mode maintenance prolongé si migration lourde
php artisan down --retry=300

# 3. Migration sèche (dry-run sur dump)
mysql -u root -p < migration-test.sql

# 4. Migration réelle
php artisan migrate --force

# 5. Vérifier que les requêtes critiques tournent
php artisan tinker
>>> Order::count();
>>> Product::active()->count();

# 6. Sortir de maintenance
php artisan up
```

### Migrations longues — éviter le mode maintenance

Pour les migrations qui prennent plus de quelques secondes :

- Utiliser `pt-online-schema-change` (Percona Toolkit) pour les ALTER TABLE sur grosses tables.
- Découper la migration en plusieurs `batch` (ex : backfill par lot de 10 000 lignes via `chunk()`).
- Faire la migration **avant** le déploiement du code qui l'exige (deploy en 2 étapes).

---

## 5. Mise à jour des dépendances

### Backend (Composer)

#### Audit régulier

```bash
composer audit                  # vulnérabilités connues
composer outdated --direct      # ce qui peut être bumpé
```

À faire **hebdomadairement** sur `develop` puis valider en local + CI.

#### Bump mineur / patch

```bash
composer update --with-dependencies
php artisan test                # vérifier que rien ne casse
./vendor/bin/pint               # corriger le style
git commit -am "chore(deps): bump composer dependencies"
```

#### Bump majeur (ex: Laravel 12 → 13)

- **Lire le upgrade guide officiel** de Laravel.
- Faire la migration sur une branche dédiée (`GF-laravel-13`).
- Lancer le test suite complet + Pail en local pour observer les warnings.
- Tester staging pendant **au moins 48 h** avant de viser la prod.
- Surveiller les breaking changes des packages tiers (Sanctum, Scramble, etc.).

### Frontend (npm)

#### Audit régulier

```bash
npm audit                       # vulnérabilités
npm outdated                    # ce qui peut être bumpé
```

#### Bump

```bash
npm update                      # respecte les ranges semver de package.json
npm run lint                    # ESLint
npm run build                   # vérifier que le build passe
```

Pour les bumps majeurs (React 18 → 19, etc.), faire sur une branche dédiée + test manuel approfondi.

### Système & images Docker

- Image `php:8.3-fpm-alpine` → suivre les **releases PHP** (patch mensuel généralement).
- Image `nginx:alpine` → rebuild au moins une fois par trimestre.
- Image `mysql:8.0` → upgrade mineur à chaque LTS.

Le rebuild se déclenche automatiquement à chaque push sur `main` (cf. CI/CD).

### Dependabot

Activer Dependabot sur les deux repos GitHub pour recevoir des PR automatiques :

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: composer
    directory: "/"
    schedule:
      interval: weekly
  - package-ecosystem: npm
    directory: "/"
    schedule:
      interval: weekly
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: monthly
```

---

## 6. Rollback

### Rollback applicatif (sans toucher à la DB)

Si une nouvelle version casse la prod **sans avoir migré la DB** :

```bash
# Sur le VPS prod
cd /var/www/gauthierfitness
export IMAGE_TAG=<sha-stable-précédent>
docker compose pull
docker compose up -d
sleep 8
curl https://gauthierfitness.fr/api/health
```

Le sha précédent est dans l'historique GHCR ou dans `git log --oneline -10 main`.

### Rollback avec migration DB

Si une migration a tourné et qu'elle est en cause :

```bash
# 1. Mode maintenance
docker compose exec -T backend php artisan down --retry=60

# 2. Rollback migration
docker compose exec -T backend php artisan migrate:rollback --step=1

# 3. Rollback image
export IMAGE_TAG=<sha-précédent>
docker compose up -d
sleep 8

# 4. Sortir de maintenance
docker compose exec -T backend php artisan up

# 5. Vérification
curl https://gauthierfitness.fr/api/health
```

**⚠️ Si la migration a fait un `DROP COLUMN` ou un changement destructif**, le rollback de migration ne récupèrera **pas
** les données. C'est pour ça qu'on évite les migrations destructives en une release (cf. règles d'or § 4).

### Rollback DB complet (restauration backup)

Cas d'urgence si la DB est corrompue :

```bash
# Sur le VPS
docker compose exec -T backend php artisan down --retry=600
gpg --decrypt backup-pre-v1.2.0.sql.gpg | mysql -u root -p gauthier_fitness
export IMAGE_TAG=<sha-précédent>
docker compose up -d
docker compose exec -T backend php artisan up
```

Prévoir une **fenêtre de maintenance annoncée** car la restauration peut prendre 10-30 minutes sur une DB de plusieurs
Go.

---

## 7. Journal des versions

Maintenir `CHANGELOG.md` à la racine du repo, mis à jour à **chaque release**,
format [Keep a Changelog](https://keepachangelog.com/) :

```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [v1.2.0] - 2026-06-17

### Added

- ...

### Changed

- ...

### Deprecated

- ...

### Removed

- ...

### Fixed

- ...

### Security

- ...
```

Le CHANGELOG est aussi recopié dans la **release GitHub** correspondante (page Releases) pour servir de référence aux
intégrateurs externes.

---

## 8. Checklist de release

À cocher avant chaque déploiement prod :

- [ ] Tous les tests passent sur `develop`
- [ ] Staging stable depuis ≥ 24 h
- [ ] CHANGELOG mis à jour
- [ ] Version bumpée (composer, package.json, .env.example)
- [ ] PR `develop → main` reviewée et mergée
- [ ] Tag Git posé et pushé
- [ ] Backup DB pré-deploy fait
- [ ] Annonce d'éventuelle interruption envoyée si migration lourde
- [ ] Déploiement déclenché et health check vert
- [ ] Smoke test post-deploy (compte test + commande test)
- [ ] Surveillance des logs pendant 30 min
- [ ] Release GitHub publiée avec le CHANGELOG
