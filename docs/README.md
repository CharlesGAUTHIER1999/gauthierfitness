# GauthierFitness Documentation

> Fitness e-commerce store, with clothing customizable via a 3D configurator and automatic AI design generation.
> V2 will add sports nutrition products and customizable fitness equipment.

This documentation is the main entry point of the project. It describes the application's architecture,
deployment, usage, and maintenance.

---

## Summary

| Document                                                      | For whom?                   | Content                                                                 |
|---------------------------------------------------------------|-----------------------------|-------------------------------------------------------------------------|
| [01 - Architecture & Technical Choices](./01-architecture.md) | Tech lead, jury, future dev | Stack, diagram, tech choice rationale, security, accessibility          |
| [02 - Deployment Manual](./02-deployment.md)                  | DevOps, maintainer          | CI/CD, Docker, OVH, staging & production deployment                     |
| [03 - User Guide](./03-user-guide.md)                         | End user, store admin       | Customer journey (purchase, customization, payment) + admin back-office |
| [04 - Upgrade Manual](./04-upgrade.md)                        | Maintainer                  | Release procedure, DB migrations, rollback, dependencies                |
| [05 - REST API](./05-api.md)                                  | Integrator, front-end dev   | Swagger / OpenAPI 3.1, endpoints, authentication, examples              |

---

## Quick Start

```bash
# Backend (Laravel 13 + PHP 8.3)
cd backend
cp .env.example .env
composer install
php artisan key:generate
php artisan migrate --seed
php artisan serve

# Frontend (React 19 + Vite 7)
cd frontend
npm install
npm run dev
```

The API runs on `http://localhost:8000`, the front on `http://localhost:5173`, the Swagger docs on
`http://localhost:8000/docs/api`.

---

## Repository Structure

```
gauthierfitness/
├── backend/      Laravel 13 - REST API, Sanctum, Stripe, OpenAI
├── frontend/     React 19 + Vite - storefront + 2D/3D editor
├── infra/        Prod/staging compose, nginx, deployment scripts
└── docs/         This documentation (what you're reading)
```

Backend and frontend are separate Git repos (logical mono-repo, physical multi-repo on GitHub).

---

## Useful links

- **Production**: <https://gauthierfitness.fr>
- **GitHub repos**: `CharlesGAUTHIER1999/gauthierfitness-{backend,frontend,infra}`
- **OpenAPI specification**: [
  `gauthierfitness-backend/swagger/openapi.json`](https://github.com/CharlesGAUTHIER1999/gauthierfitness-backend/blob/develop/swagger/openapi.json)
- **RNCP 39583 framework**: Expert in Software Development - France Compétences

---

## RNCP Framework Coverage

This documentation covers the competencies of Bloc 2 "Design and Develop Software Applications":

- **C2.1.1** Deployment and test environments → [02-deployment.md](./02-deployment.md)
- **C2.1.2** Continuous integration → [02-deployment.md § CI/CD](./02-deployment.md#5-cicd)
- **C2.2.1** Prototype & architecture → [01-architecture.md](./01-architecture.md)
- **C2.2.3** Security,
  accessibility → [01-architecture.md § Security](./01-architecture.md#6-security--owasp-top-10-coverage)
- **C2.2.4** Progressive deployment &
  versioning → [02-deployment.md](./02-deployment.md), [04-upgrade.md](./04-upgrade.md)
- **C2.4.1** Technical operations documentation → this `docs/` folder
