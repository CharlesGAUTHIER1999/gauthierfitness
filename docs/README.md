# Documentation GauthierFitness

> Boutique e-commerce de produits fitness, avec vêtements personnalisables via configurateur 3D et génération automatique de designs par IA.
> La V2 prévoit l'ajout de produits de nutrition sportive et d'équipements fitness personnalisables.

Cette documentation est l'entrée principale du projet. Elle décrit l'architecture, le déploiement, l'utilisation et la maintenance de l'application.

---

## Sommaire

| Document                                                     | Pour qui ?                        | Contenu                                                                |
|--------------------------------------------------------------|-----------------------------------|------------------------------------------------------------------------|
| [01 — Architecture & choix techniques](./01-architecture.md) | Tech lead, jury, futur·e dev      | Stack, schéma, justification des choix techno, sécurité, accessibilité |
| [02 — Manuel de déploiement](./02-deployment.md)             | DevOps, mainteneur·euse           | CI/CD, Docker, OVH, déploiement staging & production                   |
| [03 — Manuel d'utilisation](./03-user-guide.md)              | Utilisateur final, admin boutique | Parcours client (achat, customisation, paiement) + back-office admin   |
| [04 — Manuel de mise à jour](./04-upgrade.md)                | Mainteneur·euse                   | Procédure de release, migrations DB, rollback, dépendances             |
| [05 — API REST](./05-api.md)                                 | Intégrateur·rice, dev front       | Swagger / OpenAPI 3.1, endpoints, authentification, exemples           |

---

## Démarrage rapide

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

L'API tourne sur `http://localhost:8000`, le front sur `http://localhost:5173`, la doc Swagger sur `http://localhost:8000/docs/api`.

---

## Structure du dépôt

```
gauthierfitness/
├── backend/      Laravel 13 — API REST, Sanctum, Stripe, OpenAI
├── frontend/     React 19 + Vite — boutique + éditeur 2D/3D
├── infra/        Compose prod/staging, nginx, scripts de déploiement
└── docs/         Cette documentation (lue par toi)
```

Backend et frontend sont des dépôts Git séparés (mono-repo logique, multi-repo physique sur GitHub).

---

## 🔗 Liens utiles

- **Production** : <https://gauthierfitness.fr>
- **Repos GitHub** : `CharlesGAUTHIER1999/gauthierfitness-{backend,frontend,infra}`
- **Spécification OpenAPI** : [`gauthierfitness-backend/swagger/openapi.json`](https://github.com/CharlesGAUTHIER1999/gauthierfitness-backend/blob/develop/swagger/openapi.json)
- **Référentiel RNCP 39583** : Expert en Développement Logiciel — France compétences

---

## Couverture du référentiel RNCP

Cette documentation couvre les compétences du Bloc 2 « Concevoir et développer des applications logicielles » :

- **C2.1.1** Environnements de déploiement et test → [02-deployment.md](./02-deployment.md)
- **C2.1.2** Intégration continue → [02-deployment.md § CI/CD](./02-deployment.md#cicd)
- **C2.2.1** Prototype & architecture → [01-architecture.md](./01-architecture.md)
- **C2.2.3** Sécurité, accessibilité → [01-architecture.md § Sécurité & accessibilité](./01-architecture.md#sécurité--accessibilité)
- **C2.2.4** Déploiement progressif & versioning → [02-deployment.md](./02-deployment.md), [04-upgrade.md](./04-upgrade.md)
- **C2.4.1** Documentation technique d'exploitation → ce dossier `docs/`
