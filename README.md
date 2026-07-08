# GauthierFitness

> Boutique e-commerce de produits fitness, avec vêtements personnalisables via configurateur 3D et génération automatique de designs par IA.
> La V2 prévoit l'ajout de produits de nutrition sportive et d'équipements fitness personnalisables.
>
> **Production** → <https://gauthierfitness.fr>
> **Pre-Production** → <https://staging.gauthierfitness.fr/>

---

## Composants du projet

Le projet est séparé en plusieurs répertoires : chaque brique est versionnée dans son propre dépôt GitHub pour cycliser indépendamment ses releases, CI/CD et permissions :

| Composant       | Repo                                                                                        | Stack                                                         | Rôle                                                               |
|-----------------|---------------------------------------------------------------------------------------------|---------------------------------------------------------------|--------------------------------------------------------------------|
| 🧠 **Backend**  | [gauthierfitness-backend](https://github.com/CharlesGAUTHIER1999/gauthierfitness-backend)   | Laravel 13 · PHP 8.3 · MySQL 8 · Sanctum · Stripe · OpenAI    | API REST, paiement, customisation, stock, génération IA            |
| 🎨 **Frontend** | [gauthierfitness-frontend](https://github.com/CharlesGAUTHIER1999/gauthierfitness-frontend) | React 19 · Vite 7 · Konva 2D · Three.js · Zustand · Stripe.js | Boutique, configurateur 3D, back-office admin                      |
| 🚀 **Infra**    | [gauthierfitness-infra](https://github.com/CharlesGAUTHIER1999/gauthierfitness-infra)       | Docker · Nginx · OVH (2 VPS) · GitHub Actions · Let's Encrypt | Reverse proxy, déploiement staging & production                    |
| 📖 **Docs**     | [gauthierfitness]                                                                           | Markdown                                                      | Documentation projet transverse, point d'entrée jury / nouveau dev |

---

## Vue d'ensemble

```
                                ┌────────────────────────────────┐
                                │  Utilisateur (navigateur)       │
                                └──────────────┬──────────────────┘
                                               │ HTTPS
                                               ▼
                ┌──────────────────────────────────────────────────┐
                │  Nginx (TLS Let's Encrypt, gzip, static)         │
                └──────────┬───────────────────────┬───────────────┘
                           ▼                       ▼
              ┌──────────────────────┐  ┌────────────────────────┐
              │  Frontend React 19    │  │  Backend Laravel 13     │
              │  (Vite build SPA)     │  │  (PHP-FPM 8.3, Sanctum) │
              └──────────┬────────────┘  └─────────┬────────────────┘
                         │  axios + Bearer token   │
                         │                         ▼
                         │              ┌────────────────────────┐
                         │              │  MySQL 8 (OVH)          │
                         │              └────────────────────────┘
                         │
                         ▼
              ┌──────────────────────────┐    ┌────────────────────┐
              │  Stripe (paiement)       │    │  OpenAI Images API │
              └──────────────────────────┘    └────────────────────┘
```

Pour le schéma détaillé avec les flux critiques (commande personnalisée, webhook Stripe, décrémentation FIFO du stock) → [docs/01-architecture.md](./docs/01-architecture.md#2-vue-densemble--schéma-darchitecture).

---

## Documentation

Cinq documents qui couvrent l'ensemble du cycle de vie du projet :

| Doc                                                               | Pour qui ?                   | Sujet                                                          |
|-------------------------------------------------------------------|------------------------------|----------------------------------------------------------------|
| [01 - Architecture & choix techniques](./docs/01-architecture.md) | Tech lead, jury, futur·e dev | Stack, schéma, OWASP Top 10, accessibilité, durcissement VPS   |
| [02 - Manuel de déploiement](./docs/02-deployment.md)             | DevOps, mainteneur·euse      | CI/CD GitHub Actions, Docker, OVH, déploiement staging & prod  |
| [03 - Manuel d'utilisation](./docs/03-user-guide.md)              | Utilisateur final, admin     | Parcours client (achat, customisation, paiement) + back-office |
| [04 - Manuel de mise à jour](./docs/04-upgrade.md)                | Mainteneur·euse              | Procédure de release, migrations DB, rollback, gestion deps    |
| [05 - API REST](./docs/05-api.md)                                 | Intégrateur·rice, dev front  | Swagger OpenAPI 3.1, authentification Sanctum, exemples        |

### Spécification OpenAPI

La spec complète est générée par Scramble dans le repo backend :

➡️ [`gauthierfitness-backend/swagger/openapi.json`](https://github.com/CharlesGAUTHIER1999/gauthierfitness-backend/blob/develop/swagger/openapi.json)

Visualisable en ligne avec un viewer comme [editor.swagger.io](https://editor.swagger.io/) (importer le fichier `openapi.json`).
En local (sur le backend) : `http://localhost:8000/docs/api` après `php artisan serve`.

---

## Démarrage rapide

Les 4 repos sont **publics** : pas besoin de clé SSH ni de compte GitHub pour les cloner.

Pour faire tourner l'ensemble du projet en local, cloner les **3 repos applicatifs** côte à côte :

```bash
mkdir gauthierfitness && cd gauthierfitness

git clone https://github.com/CharlesGAUTHIER1999/gauthierfitness-backend.git backend
git clone https://github.com/CharlesGAUTHIER1999/gauthierfitness-frontend.git frontend
git clone https://github.com/CharlesGAUTHIER1999/gauthierfitness-infra.git infra
git clone https://github.com/CharlesGAUTHIER1999/gauthierfitness.git docs

# Backend (terminal 1)
cd backend
cp .env.example .env
composer install
php artisan key:generate
php artisan migrate --seed
php artisan storage:link   # requis pour que les images produits soient servies
composer dev      # serveur + queue + pail + vite simultanés

# Frontend (terminal 2)
cd ../frontend
cp .env.example .env.local      # remplir VITE_STRIPE_PUBLIC_KEY
npm install
npm run dev
```

L'API tourne sur `http://localhost:8000`, le frontend sur `http://localhost:5173`, la documentation Swagger sur `http://localhost:8000/docs/api`.
Détail complet des pré-requis et options Docker → [docs/02-deployment.md § 3](./docs/02-deployment.md#3-démarrage-local).

---

## Remise du projet (zip)

Le code étant réparti sur 4 repos, la remise se fait sous forme d'un **zip unique** régénéré à neuf depuis GitHub
(garantit que le contenu remis correspond exactement à ce qui est publié, sans fichier local oublié) :

```powershell
./scripts/build-release-zip.ps1 -Ref main      # ou -Ref v1.0.0 si les repos sont tagués
```

Produit `../gauthierfitness-release/gauthierfitness-<ref>.zip`, contenant les 4 repos assemblés (sans historique
Git). Détail du script → [scripts/build-release-zip.ps1](./scripts/build-release-zip.ps1).

---

## Convention de branchage

**Repos applicatifs** (`backend`, `frontend`) :

- `feature` : `GF{n}-{NomCourt}` (ex : `GF21-SwaggerDoc`, `GF22-Documentation`)
- `develop` : intégration continue, push → image GHCR `:develop` → staging déployé automatiquement
- `main` : push → image GHCR `:latest` → déploiement prod **déclenché manuellement** via le workflow `Deploy Pipeline` du repo infra

**Repo infra** : pas de branches feature, juste `develop` → `main` (PR). Les workflows `deploy.yml` lisent les configs du repo et les poussent en SSH sur les VPS.

---

## Couverture du référentiel RNCP 39583

Ce projet a été conçu comme **support de la certification RNCP 39583 « Expert en Développement Logiciel »**. 
Cette documentation couvre principalement les compétences du **Bloc 2 « Concevoir et développer des applications logicielles »** :

| Compétence                                          | Livrable                                        | Document                                                                                       |
|-----------------------------------------------------|-------------------------------------------------|------------------------------------------------------------------------------------------------|
| **C2.1.1** Environnements de déploiement et de test | Protocole de déploiement continu                | [02-deployment.md](./docs/02-deployment.md)                                                    |
| **C2.1.2** Intégration continue                     | Workflow GitHub Actions                         | [02-deployment.md § CI/CD](./docs/02-deployment.md#5-cicd)                                     |
| **C2.2.1** Prototype & architecture                 | Architecture structurée, frameworks             | [01-architecture.md](./docs/01-architecture.md)                                                |
| **C2.2.3** Sécurité & accessibilité                 | OWASP Top 10, OPQUAST, audits Lighthouse        | [01-architecture.md § Sécurité](./docs/01-architecture.md#6-sécurité--couverture-owasp-top-10), rapports [avant](lighthouse/1-avant-correctifs.report.html) / [après](lighthouse/2-apres-correctifs.report.html) correctifs (Home, dev), et rapports [prod](lighthouse/3-prod-home.report.html) sur [Home](lighthouse/3-prod-home.report.html), [configurateur](lighthouse/4-prod-configurateur-apres-fix-csp.report.html) et [checkout](lighthouse/5-prod-checkout.report.html) |
| **C2.2.4** Déploiement progressif & versioning      | Versioning Git, SemVer                          | [02-deployment.md](./docs/02-deployment.md), [04-upgrade.md](./docs/04-upgrade.md)             |
| **C2.4.1** Documentation technique d'exploitation   | Manuels déploiement / utilisation / mise à jour | Tout le dossier [`docs/`](./docs/)                                                             |

---

## Auteur

**Charles Gauthier** - Développeur Fullstack
📧 charles.gauthier99@gmail.com