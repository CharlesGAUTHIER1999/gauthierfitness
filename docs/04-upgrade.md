# 04 - Upgrade Manual

> Procedure for publishing a new version of GauthierFitness to production, managing DB migrations, updating
> dependencies, and running a rollback if needed. Covers RNCP competencies **C2.4.1** (documentation) and
> **C4.1.1** (dependency upgrade management).

---

## 1. Release Cycle

```
feature → develop          (staging auto)
develop → main             (production manual)
main    → tag vX.Y.Z       (semantic versioning)
```

### Version convention (SemVer)

- **MAJOR** (`vX.0.0`) - breaking change to the public API or DB schema without a backward-compatible migration.
- **MINOR** (`v1.X.0`) - new feature, without breaking existing behavior.
- **PATCH** (`v1.0.X`) - bugfix, perf, security.

The version is carried by:

- The Git tag (`git tag v1.2.0`)
- The Docker image tag (`ghcr.io/.../gauthierfitness-backend:v1.2.0`)
- The `API_VERSION` variable in `.env` (read by Scramble for the OpenAPI spec)

---

## 2. Preparing a Release

### Step 1 - Freeze develop

1. Check that `develop` is stable on staging (manual checks, tests, QA feedback).
2. Announce the freeze in the team channel (no new merges to `develop`).

### Step 2 - Bump versions

```bash
# Backend
cd backend
# Bump API_VERSION in .env.example (will serve as the default)
# Bump the version in composer.json if relevant

# Frontend
cd ../frontend
npm version 1.2.0 --no-git-tag-version
git add package.json package-lock.json
git commit -m "chore: bump version 1.2.0"
```

### Step 3 - Write the CHANGELOG

Add a section at the top of `CHANGELOG.md` (create it if it doesn't exist):

```markdown
## v1.2.0 - 2026-06-17

### Added

- AI design generation via OpenAI (GF18)
- Accessible form mode in the 2D editor (GF19)

### Changed

- Laravel 12 → 13 migration
- Composer / npm dependency updates

### Fixed

- Rounding bug on totals incl. tax with multiple options (GF20)

### Security

- MySQL passwords removed from docker-compose.yml (GF23)
```

### Step 4 - PR develop → main

1. Open a `develop → main` PR with the CHANGELOG as the description.
2. Review is mandatory (even solo: 24h of cold re-read).
3. Check that CI is green.
4. Merge as a **"Merge commit"** (not squash, to preserve history).

### Step 5 - Tag

```bash
git checkout main
git pull
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

---

## 3. Deploying to Production

See also [02-deployment.md § Production Deployment](./02-deployment.md#production-deployment--manual-with-gate).

### Standard procedure

1. On GitHub Actions, manually trigger `deploy-prod` with the tag (`v1.2.0`) or the sha of main.
2. The runner connects to the prod VPS and runs `infra/scripts/deploy-prod.sh`.
3. The script:
    - Pulls the code (`git pull origin main`)
    - Pulls the new Docker images
    - Enables maintenance mode (`artisan down`)
    - Runs the migrations (`artisan migrate --force`)
    - Restarts the containers
    - Re-caches config / routes / views / events
    - Disables maintenance mode (`artisan up`)
    - Health check (`curl /api/health`)

### Post-deployment monitoring

During the 30 minutes that follow:

- Check the Laravel logs: `docker compose logs -f gf_backend | grep -i error`
- Check the Stripe webhooks dashboard (no mass failures).
- Test a full purchase journey end to end (test account → test order).
- Watch the 5xx response rate via the Nginx logs.

---

## 4. Database Migrations

### Golden rules

- **Always backward-compatible across N versions** - a progressive deployment must be able to coexist with the
  previous version of the code during the migration.
- **No DROP COLUMN in the same release as the deprecation** - deprecate in V1, remove in V2.
- **Indexes on FKs always created with the migration** - for performance & consistency.
- **Test on a copy of production** before any risky migration.

### Procedure for a risky migration

```bash
# 1. Backup first
mysqldump -u root -p gauthier_fitness > backup-pre-v1.2.0.sql
gpg --encrypt --recipient charles@... backup-pre-v1.2.0.sql

# 2. Extended maintenance mode
php artisan down --retry=300

# 3. Dry-run migration
mysql -u root -p < migration-test.sql

# 4. Actual migration
php artisan migrate --force

# 5. Verify that critical queries still work
php artisan tinker
>>> Order::count();
>>> Product::active()->count();

# 6. Exit maintenance mode
php artisan up
```

### Long migrations - avoiding maintenance mode

For migrations that take more than a few seconds:

- Use `pt-online-schema-change` (Percona Toolkit) for ALTER TABLE on large tables.
- Split the migration into several `batch`es (e.g.: backfill in batches of 10,000 rows via `chunk()`).
- Run the migration **before** deploying the code that requires it (two-step deploy).

---

## 5. Dependency Updates

### Backend (Composer)

#### Regular audit

```bash
composer audit                  # known vulnerabilities
composer outdated --direct      # what can be bumped
```

To be done **weekly** on `develop`, then validated locally + in CI.

#### Minor / patch bump

```bash
composer update --with-dependencies
php artisan test                # verify nothing broke
./vendor/bin/pint               # fix style
git commit -am "chore(deps): bump composer dependencies"
```

#### Major bump (e.g.: Laravel 12 → 13)

- **Read the official Laravel upgrade guide**.
- Do the migration on a dedicated branch (`GF-laravel-13`).
- Run the full test suite + Pail locally to observe warnings.
- Test on staging for **at least 48h** before targeting prod.
- Watch for breaking changes in third-party packages (Sanctum, Scramble, etc.).

### Frontend (npm)

#### Regular audit

```bash
npm audit                       # vulnerabilities
npm outdated                    # what can be bumped
```

#### Bump

```bash
npm update                      # respects package.json semver ranges
npm run lint                    # ESLint
npm run build                   # verify the build passes
```

For major bumps (React 18 → 19, etc.), do it on a dedicated branch + thorough manual testing.

### System & Docker images

- `php:8.3-fpm-alpine` image → follow **PHP releases** (usually a monthly patch).
- `nginx:alpine` image → rebuild at least once a quarter.
- `mysql:8.0` image → minor upgrade on every LTS.

The rebuild is triggered automatically on every push to `main` (cf. CI/CD).

### Dependabot

Enable Dependabot on both GitHub repos to receive automatic PRs:

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

### Application rollback (without touching the DB)

If a new version breaks prod **without having migrated the DB**:

```bash
# On the prod VPS
cd /var/www/gauthierfitness
export IMAGE_TAG=<previous-stable-sha>
docker compose pull
docker compose up -d
sleep 8
curl https://gauthierfitness.fr/api/health
```

The previous sha is in the GHCR history or in `git log --oneline -10 main`.

### Rollback with a DB migration

If a migration has run and is the cause:

```bash
# 1. Maintenance mode
docker compose exec -T backend php artisan down --retry=60

# 2. Rollback the migration
docker compose exec -T backend php artisan migrate:rollback --step=1

# 3. Rollback the image
export IMAGE_TAG=<previous-sha>
docker compose up -d
sleep 8

# 4. Exit maintenance mode
docker compose exec -T backend php artisan up

# 5. Verification
curl https://gauthierfitness.fr/api/health
```

**⚠️ If the migration ran a `DROP COLUMN` or another destructive change**, rolling back the migration will
**not** recover the data. This is why destructive migrations are avoided within a single release (cf. golden
rules § 4).

### Full DB rollback (backup restore)

Emergency case if the DB is corrupted:

```bash
# On the VPS
docker compose exec -T backend php artisan down --retry=600
gpg --decrypt backup-pre-v1.2.0.sql.gpg | mysql -u root -p gauthier_fitness
export IMAGE_TAG=<previous-sha>
docker compose up -d
docker compose exec -T backend php artisan up
```

Plan for an **announced maintenance window**, as restoring can take 10-30 minutes on a multi-GB database.

---

## 7. Version Log

Maintain `CHANGELOG.md` at the root of the repo, updated on **every release**,
following the [Keep a Changelog](https://keepachangelog.com/) format:

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

The CHANGELOG is also copied into the corresponding **GitHub release** (Releases page) to serve as a reference
for external integrators.

---

## 8. Release Checklist

To check before every prod deployment:

- [ ] All tests pass on `develop`
- [ ] Staging stable for ≥ 24h
- [ ] CHANGELOG updated
- [ ] Version bumped (composer, package.json, .env.example)
- [ ] `develop → main` PR reviewed and merged
- [ ] Git tag created and pushed
- [ ] Pre-deploy DB backup done
- [ ] Downtime notice sent if a heavy migration is involved
- [ ] Deployment triggered and health check green
- [ ] Post-deploy smoke test (test account + test order)
- [ ] Logs monitored for 30 min
- [ ] GitHub release published with the CHANGELOG
