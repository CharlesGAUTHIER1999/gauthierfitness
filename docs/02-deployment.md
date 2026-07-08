# 02 — Manuel de déploiement

> Procédures complètes pour faire tourner GauthierFitness en **local**, **staging** et **production**. Couvre les
> compétences RNCP **C2.1.1** (environnements de déploiement et de test), **C2.1.2** (intégration continue) et **C2.2.4
** (déploiement progressif).

---

## 1. Environnements

| Env            | URL                                                             | Branche source | Trigger déploiement                          | Usage                  |
|----------------|-----------------------------------------------------------------|----------------|----------------------------------------------|------------------------|
| **Local**      | `http://localhost:8000` (back), `http://localhost:5173` (front) | tous           | Manuel (`php artisan serve` + `npm run dev`) | Développement          |
| **Staging**    | `https://staging.gauthierfitness.fr`                            | `develop`      | Automatique après CI verte                   | Tests fonctionnels, QA |
| **Production** | `https://gauthierfitness.fr`                                    | `main`         | Manuel via GitHub Actions (gate)             | Utilisateurs réels     |

Les deux environnements distants tournent sur des **VPS OVH distincts** pour éviter qu'un incident sur l'un ne contamine
l'autre (cf. incident ransomware staging mai 2026).

---

## 2. Pré-requis

### Local

- **PHP 8.3+** avec extensions `pdo`, `pdo_mysql`, `mbstring`, `bcmath`, `gd`, `zip`, `pcntl`
- **Composer 2.8+**
- **Node 22+** et **npm 10+**
- **Docker Desktop** ou **MySQL 8** natif

### Production / Staging

- **Docker** ≥ 24 + **Docker Compose v2**
- Accès SSH par clé au VPS
- Variables d'environnement configurées dans GitHub Secrets

---

## 3. Démarrage local

### Option A - Sans Docker (recommandé pour le dev)

```bash
# Cloner les trois repos côte à côte
git clone https://github.com/CharlesGAUTHIER1999/gauthierfitness-backend.git backend
git clone https://github.com/CharlesGAUTHIER1999/gauthierfitness-frontend.git frontend
git clone https://github.com/CharlesGAUTHIER1999/gauthierfitness-infra.git infra

# Backend
cd backend
cp .env.example .env
composer install
php artisan key:generate
php artisan migrate --seed
php artisan storage:link   # requis pour que les images produits soient servies
composer dev      # lance simultanément: artisan serve, queue:listen, pail, vite

# Frontend (dans un autre terminal)
cd ../frontend
cp .env.example .env.local
npm install
npm run dev
```

Le script `composer dev` lance en parallèle :

- `php artisan serve` - serveur HTTP
- `php artisan queue:listen` - worker de queue
- `php artisan pail` - streamer (couleurs en temps réel)
- `npm run dev` (côté backend pour les assets Blade éventuels)

### Option B - Avec Docker

```bash
cd backend
cp .env.docker.example .env.docker   # DB_HOST=db (nom du service Docker, pas 127.0.0.1)
docker compose up -d
docker compose exec app php artisan migrate --seed
docker compose exec app php artisan storage:link
```

Accès :

- API → `http://localhost:8000/api`
- MySQL → `localhost:3308` (port mappé pour éviter conflit avec un MySQL local)

---

## 4. Variables d'environnement

### Backend - `.env`

```dotenv
# App
APP_NAME=GauthierFitness
APP_ENV=local# local | staging | production
APP_KEY=                 # généré par artisan key:generate
APP_DEBUG=true# FALSE en production !
APP_URL=http://localhost:8000

# DB
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=gauthier_fitness
DB_USERNAME=root
DB_PASSWORD=

# Sanctum
SANCTUM_STATEFUL_DOMAINS=localhost:5173
SESSION_DOMAIN=localhost

# Stripe
STRIPE_KEY=pk_test_xxxxx
STRIPE_SECRET=sk_test_xxxxx
STRIPE_WEBHOOK_SECRET=whsec_xxxxx

# OpenAI
OPENAI_API_KEY=sk-xxxxx

# Mail (SMTP OVH en prod, Mailpit en local)
MAIL_MAILER=smtp
MAIL_HOST=localhost
MAIL_PORT=1025
MAIL_FROM_ADDRESS=noreply@gauthierfitness.fr
MAIL_FROM_NAME=GauthierFitness
MAIL_SUPPORT_ADDRESS=hortense.gauthier2002@gmail.com

# Scramble (doc API)
API_VERSION=1.0.0
```

### Frontend - `.env.local`

```dotenv
# Laisser vide en dev : le proxy Vite (vite.config.js) redirige /api vers localhost:8000.
# En staging/prod, mettre l'URL complète : VITE_API_URL=https://api.gauthierfitness.fr/api
VITE_API_URL=

# Clé publique Stripe (pk_test_... en dev, pk_live_... en prod)
VITE_STRIPE_PUBLIC_KEY=pk_test_xxxxx
```

---

## 5. CI/CD

### Workflow GitHub Actions - `backend/.github/workflows/ci-cd.yml`

```
┌────────────┐    ┌──────────┐    ┌──────────────┐    ┌──────────────┐
│  PHPUnit   │───▶│   Pint   │───▶│  Build image │───▶│ Trigger      │
│  (tests)   │    │  (lint)  │    │     GHCR     │    │ deploy infra │
└────────────┘    └──────────┘    └──────────────┘    └──────────────┘
                                     (push only)        (develop only)
```

| Job              | Quand                         | Quoi                                                                               | Échec → bloque      |
|------------------|-------------------------------|------------------------------------------------------------------------------------|---------------------|
| `phpunit`        | push + PR                     | `php artisan test --stop-on-failure` avec SQLite in-memory                         | toute la chaîne     |
| `lint`           | après phpunit                 | `pint --test` (style PSR-12)                                                       | toute la chaîne     |
| `build`          | push uniquement               | Docker buildx multi-stage → push sur GHCR avec tag `sha-court` + `latest` sur main | déploiement         |
| `trigger-deploy` | push sur `develop` uniquement | `repository_dispatch` vers `gauthierfitness-infra` → déploie staging               | déploiement staging |

### Pipeline frontend

Le frontend a son propre workflow (similaire) : build Vite + ESLint + push de l'image nginx servant le `dist/`.

### Déploiement staging - automatique

À chaque push sur `develop` qui passe CI verte :

1. Image Docker buildée et pushée sur GHCR avec le tag `develop-<sha>`.
2. Le job `trigger-deploy` envoie un `repository_dispatch` au repo `gauthierfitness-infra`.
3. Le workflow `gauthierfitness-infra` se connecte en SSH au VPS staging et exécute `infra/scripts/deploy-staging.sh`
   avec l'image tag.

### Déploiement production - manuel avec gate

Pour déployer en prod :

1. Merger `develop` → `main` (via Pull Request avec review).
2. Le push sur `main` build l'image taggée `latest` + le sha.
3. **Déclencher manuellement** le workflow `deploy-prod` dans l'onglet Actions GitHub.
4. Le runner exécute `infra/scripts/deploy-prod.sh` en SSH sur le VPS production.

Le script `deploy-prod.sh` enchaîne :

```bash
git pull origin main           # code à jour
docker compose pull            # nouvelles images
php artisan down --retry=5     # mode maintenance
php artisan migrate --force    # migrations DB
docker compose up -d           # redémarrage
sleep 8                        # attente PHP-FPM
php artisan config:cache       # caches Laravel
php artisan route:cache
php artisan view:cache
php artisan event:cache
php artisan up                 # retour en ligne
docker image prune -f          # nettoyage
curl /api/health               # health check (200 attendu)
```

---

## 6. Reverse proxy Nginx

### Sous-domaines production

| Sous-domaine                     | Service                               | Conteneur                           |
|----------------------------------|---------------------------------------|-------------------------------------|
| `gauthierfitness.fr`             | Frontend React (SPA servie en static) | `gf_nginx` → `gf_frontend`          |
| `api.gauthierfitness.fr`         | API Laravel                           | `gf_nginx` → `gf_backend` (PHP-FPM) |
| `staging.gauthierfitness.fr`     | Frontend staging                      | VPS distinct                        |
| `api-staging.gauthierfitness.fr` | API staging                           | VPS distinct                        |

### Configuration TLS

Tous les sous-domaines utilisent **Let's Encrypt** avec renouvellement automatique par Certbot :

```bash
sudo certbot --nginx -d gauthierfitness.fr -d www.gauthierfitness.fr
sudo certbot --nginx -d api.gauthierfitness.fr
# Renouvellement auto via systemd timer (vérifier: systemctl list-timers | grep certbot)
```

### Headers de sécurité

```nginx
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
add_header X-Frame-Options "SAMEORIGIN";
add_header X-Content-Type-Options "nosniff";
add_header Referrer-Policy "strict-origin-when-cross-origin";
add_header Content-Security-Policy "default-src 'self'; script-src 'self' https://js.stripe.com; ...";
```

---

## 7. Supervision

### Health check

- Endpoint public `GET /api/health` → `{"status": "ok", "env": "production"}`
- Sondé par `deploy-prod.sh` après chaque déploiement.
- À brancher sur un service externe (UptimeRobot, BetterStack) pour alerter en cas d'indisponibilité.

### Logs

| Source          | Localisation                                                                      |
|-----------------|-----------------------------------------------------------------------------------|
| Laravel         | `backend/storage/logs/laravel.log` (rotation quotidienne en prod via `LOG_DAILY`) |
| Nginx           | `/var/log/nginx/access.log`, `/var/log/nginx/error.log`                           |
| Docker          | `docker compose logs -f <service>`                                                |
| Stripe webhooks | Persistés en DB (`webhook_events`) en plus du log Laravel                         |

### Monitoring (à mettre en place)

- **Sentry** pour le tracking d'exceptions (planifié).
- **Grafana / Prometheus** pour les métriques système - pas prioritaire pour l'instant.

---

## 8. Sécurité serveur (durcissement)

Suite à l'incident ransomware staging de mai 2026, les deux VPS OVH ont été durcis :

### SSH

```bash
# /etc/ssh/sshd_config
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
Port 22222
AllowUsers deployer
```

Seule la clé publique du runner GitHub Actions et la clé personnelle dev ont accès.

### UFW (firewall)

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22222/tcp        # SSH
ufw allow 80/tcp           # HTTP (redirect 443)
ufw allow 443/tcp          # HTTPS
ufw enable
```

Le port **MySQL 3306 est fermé** vers l'extérieur - accessible uniquement via le réseau Docker interne (le service `db`
du compose, conteneur `gf_db`, est exposé sur le réseau `gf_network`, **pas en host port**).

### Backups

- Dump MySQL chiffré (`mysqldump | gpg --encrypt`) quotidien à 03:00 via cron.
- Copie hors VPS sur stockage objet OVH (région différente).
- Test de restauration mensuel manuel.

---

## 9. Procédure de rollback en urgence

Si un déploiement casse la production :

```bash
# Sur le VPS
cd /var/www/gauthierfitness
export IMAGE_TAG=<sha-précédent-stable>   # ex: 3e5a9f1
docker compose pull
docker compose up -d
php artisan migrate:rollback --step=1       # si la migration est en cause
php artisan up
curl https://gauthierfitness.fr/api/health  # vérifier 200
```

Le sha précédent est disponible dans l'historique GHCR :
`https://github.com/CharlesGAUTHIER1999/gauthierfitness-backend/pkgs/container/gauthierfitness-backend`.

Voir aussi [04-upgrade.md § rollback](./04-upgrade.md#rollback) pour les rollbacks planifiés et la gestion des
migrations.
