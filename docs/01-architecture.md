# 01 - Architecture & choix techniques

> Document de référence pour comprendre **comment** et **pourquoi** GauthierFitness est conçue ainsi.
> Couvre les compétences RNCP **C2.2.1** (architecture et prototype), **C2.2.3** (sécurité, accessibilité) et **C2.4.1
** (documentation des choix techniques).

---

## 1. Vision Produit

GauthierFitness est une boutique e-commerce spécialisée dans les produits fitness (vêtements, accessoires, nutrition),
qui se différencie par **la personnalisation produit** :

- Éditeur **3D** (Three.js + React-Three-Fiber) pour configurer un vêtement (t-shirt, veste, sweat), et visualiser le
  produit fini.
- **Génération de design assistée par IA** (OpenAI Images) à partir d'un prompt texte.
- Suivi de **stock par lot** avec FIFO sur les produits périssables (nutrition).

L'enjeu technique principal est de relier de manière cohérente : un éditeur graphique (état complexe côté front) → une
session de personnalisation persistée (snapshot côté back) → une commande Stripe → un suivi logistique.

---

## 2. Vue d'ensemble - schéma d'architecture

```
                                ┌────────────────────────────────┐
                                │  Utilisateur (navigateur)       │
                                └──────────────┬──────────────────┘
                                               │ HTTPS
                                               ▼
                ┌──────────────────────────────────────────────────┐
                │  Nginx (TLS, gzip, static)                       │
                └──────────┬───────────────────────┬───────────────┘
                           │                       │
                           ▼                       ▼
              ┌──────────────────────┐  ┌────────────────────────┐
              │  Frontend React 19    │  │  Backend Laravel 13      │
              │  (Vite build, SPA)    │  │  (PHP-FPM 8.3, Sanctum)  │
              │  - Boutique           │  │  - API REST /api/*       │
              │  - Éditeur 3D Three   │  │  - Génération IA         │
              │  - Admin panel        │  │  - Décrémentation stocks │
              └──────────┬────────────┘  └─────────┬────────────────┘
                         │ axios + Bearer token    │
                         │                         ▼
                         │              ┌────────────────────────┐
                         │              │  MySQL 8 (OVH)          │
                         │              │  - products, orders     │
                         │              │  - stock_lots, movements│
                         │              │  - custom_sessions      │
                         │              │  - webhook_events       │
                         │              └────────────────────────┘
                         │
                         │ Webhooks asynchrones
                         ▼
              ┌──────────────────────────┐    ┌────────────────────┐
              │  Stripe (paiement)       │    │  OpenAI Images API │
              │  PaymentIntents + WH     │    │  Génération design │
              └──────────────────────────┘    └────────────────────┘
```

### Flux critique - commande personnalisée

1. **Front** - Utilisateur compose son design dans l'éditeur 3D → `POST /api/customization/sessions` snapshote la
   configuration.
2. **Front** - Ajout au panier → `POST /api/cart/items` avec `custom_product_session_id`.
3. **Front** - Checkout → `POST /api/payment/intent` crée la commande, le `Payment` (pending), un `Shipment` structuré,
   puis appelle Stripe pour obtenir un `client_secret`.
4. **Front** - Confirmation côté client via Stripe.js avec le `client_secret`.
5. **Back** - Webhook Stripe `payment_intent.succeeded` → marque commande/paiement comme payés, **vide le panier**, *
   *envoie l'email** de confirmation, **décrémente le stock en FIFO** (lot expirant le plus tôt en premier), tout dans
   une transaction DB.
6. **Admin** - Suit la commande dans le back-office et change le statut (`shipped`, `delivered`) → emails automatiques
   au client.

---

## 3. Stack technique - choix et justifications

### Backend - Laravel 13 / PHP 8.3

| Brique            | Choix                           | Pourquoi                                                                                                                                         |
|-------------------|---------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| Framework         | **Laravel 13**                  | Maturité, ORM Eloquent, écosystème (Sanctum, Notifications, Queue, Mail), documentation excellente, ergonomie de développement pour un dev solo. |
| Auth API          | **Sanctum** (token Bearer)      | Plus simple qu'OAuth2 pour une SPA mono-domaine. Tokens stockés en DB, révocables individuellement. Une session = un token nommé `react`.        |
| Base de données   | **MySQL 8**                     | Stable, support natif des JSON columns (utilisé pour `configuration` des sessions de customisation), facile à exploiter chez OVH.                |
| Paiement          | **Stripe** (PaymentIntents)     | Standard de l'industrie, support 3D-Secure natif, webhooks signés, conformité PCI déléguée.                                                      |
| IA images         | **OpenAI Images**               | Qualité supérieure pour les designs textile, latence acceptable (~6-8s), facturation à l'usage.                                                  |
| Documentation API | **Scramble** (`dedoc/scramble`) | Génère l'OpenAPI 3.1 directement depuis les controllers, FormRequests et Resources. Pas de duplication entre code et doc.                        |
| Tests             | **PHPUnit 11**                  | Standard Laravel, SQLite in-memory en CI pour la rapidité.                                                                                       |
| Qualité code      | **Laravel Pint** (PSR-12)       | Linter officiel Laravel, vérifié en CI.                                                                                                          |

### Frontend - React 19 / Vite 7

| Brique       | Choix                                        | Pourquoi                                                                                                |
|--------------|----------------------------------------------|---------------------------------------------------------------------------------------------------------|
| Framework UI | **React 19**                                 | Écosystème mature pour SPA, hooks pour la composition, Suspense pour le data fetching.                  |
| Build        | **Vite 7**                                   | HMR ultra-rapide, ESM natif, bien plus rapide que Webpack pour un projet de cette taille.               |
| Routing      | **React-router-dom 7**                       | Standard de fait, file-based routing possible si on monte en complexité.                                |
| State global | **Zustand 5**                                | Plus léger et moins verbeux que Redux. Suffit pour panier, auth, customisation.                         |
| HTTP         | **Axios**                                    | Intercepteurs (auth, refresh), gestion d'erreurs centralisée, plus ergonomique que `fetch` pour ce cas. |
| Éditeur 2D   | **Konva** + `react-konva`                    | Performance canvas, API drag/transform/snapping prête à l'emploi, export PNG natif pour les previews.   |
| Éditeur 3D   | **Three.js** + `@react-three/fiber` + `drei` | Standard 3D web, intégration React idiomatique, helpers `drei` (OrbitControls, Environment, etc.).      |
| Paiement     | **@stripe/react-stripe-js** + Elements       | Composants officiels, conformité PCI, gestion 3D-Secure automatique.                                    |
| Icônes       | **React-icons**                              | Une seule lib, importation par module pour optimiser le bundle.                                         |

### Infra - Docker + OVH

| Brique           | Choix                                                  | Pourquoi                                                                         |
|------------------|--------------------------------------------------------|----------------------------------------------------------------------------------|
| Conteneurisation | **Docker** multi-stage (vendor → production / testing) | Image PHP-FPM Alpine légère (~80 Mo), reproductibilité dev/staging/prod.         |
| Reverse proxy    | **Nginx** Alpine                                       | TLS, compression gzip, gestion des fichiers statiques, cache.                    |
| Hébergement      | **2 VPS OVH** (staging + production)                   | Bon rapport perf/prix, datacenter France (RGPD), maîtrise totale de l'hôte.      |
| Registry         | **GHCR** (GitHub Container Registry)                   | Intégré au workflow GitHub Actions, gratuit pour le repo public/privé.           |
| CI/CD            | **GitHub Actions**                                     | PHPUnit + Pint + build d'image + déclenchement deploy via `repository-dispatch`. |
| DNS              | **OVH**                                                | Géré dans le même panel que les VPS, sous-domaines API et front séparés.         |
| TLS              | **Let's Encrypt** (Certbot)                            | Renouvellement automatique, gratuit, accepté universellement.                    |

---

## 4. Modèle de données - entités clés

```
users ─┬──< designs ──< design_assets
       ├──< custom_product_sessions ──< cart_items, order_items
       ├──< carts ──< cart_items
       └──< orders ──< order_items, payments, shipments

products ─┬──< product_options
          ├──< product_images
          ├──< stock_lots ──< stock_movements
          └──< categories  (many-to-many via category_product)

webhook_events ──< webhook_event_failures
```

### Points d'attention

- **Snapshot des prix** - `cart_items` et `order_items` portent le prix au moment de l'ajout / commande pour éviter
  qu'un changement de prix produit ne réécrive l'historique. Les `custom_product_sessions` portent aussi un
  `unit_price_snapshot`.
- **Stock par lot** - Chaque entrée en stock crée un `stock_lot` (numéro de lot, quantité initiale, date d'expiration).
  Les sorties (ventes) sont tracées dans `stock_movements` avec un FIFO sur l'expiration la plus proche.
- **Idempotence des webhooks** - `webhook_events` indexe `(provider, provider_event_id)` en unique pour rejouer sans
  dupliquer le traitement. En cas d'erreur, le retry compte est tracé via `webhook_event_failures`.
- **Soft state des sessions** - Les `custom_product_sessions` transitent par `draft → ready → added_to_cart → ordered`,
  ce qui permet à l'utilisateur de continuer une customisation en cours.

---

## 5. Conventions et bonnes pratiques

### Code

- **PSR-12** côté PHP, enforced par Pint (`./vendor/bin/pint --test` en CI).
- **ESLint 9** côté JS, config flat dans `eslint.config.js`.
- **Type hints PHP** systématiques (params, retours) — c'est ce qui permet à Scramble de générer la doc OpenAPI.
- **FormRequest** pour la validation côté API quand la logique de validation dépasse 3 règles ou demande une
  vérification croisée (cf. `AddToCartRequest::withValidator` qui vérifie l'appartenance d'une session de
  customisation).
- **API Resources** (`ProductResource`, `CartResource`, etc.) pour découpler la réponse JSON de la structure interne des
  modèles.

### Git

Convention de branchage : `GF{n}-{NomCourt}` où `{n}` est un numéro de feature et `{NomCourt}` une description en
CamelCase.

Exemples : `GF21-SwaggerDoc`, `GF15-TestsE2E`.

Workflow :

- `feature` → `develop` (déploie sur staging automatiquement après CI verte)
- `develop` → `main` (déploie sur production après gate manuelle)

Backend et frontend ont des dépôts distincts sur GitHub mais sont versionnés avec la même nomenclature de branches pour
rester cohérents.

### Tests

- **Tests Feature** (PHPUnit) pour chaque endpoint API critique (auth, panier, paiement, customisation).
- **SQLite in-memory** en CI pour un cycle test rapide (~30 s).
- **Tests E2E Playwright** branchés dans le pipeline `infra/.github/workflows/deploy.yml` (job `e2e`, joué contre
  staging après chaque déploiement automatique). Specs dans `infra/e2e/tests/`.

---

## 6. Sécurité - couverture OWASP Top 10

| Risque                                   | Mesures en place                                                                                                                                                                                                         |
|------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **A01 - Broken Access Control**          | Sanctum + middleware `auth:sanctum` sur toutes les routes protégées. Middleware `admin` custom pour le back-office. Vérifications d'appartenance explicites (`abort_unless($order->user_id === ...)`).                   |
| **A02 - Cryptographic Failures**         | TLS Let's Encrypt sur tous les sous-domaines. `bcrypt` pour les passwords (`Hash::make`). Secrets dans `.env` non commité.                                                                                               |
| **A03 - Injection**                      | Eloquent (PDO préparé) systématique. Pas de `DB::raw()` avec input utilisateur. Validation FormRequest avec règles `exists` pour les FK.                                                                                 |
| **A04 - Insecure Design**                | Snapshot des prix à l'ajout au panier (impossible de modifier un prix après commande). Idempotence stricte des webhooks Stripe (table `webhook_events`). Transactions DB sur les opérations critiques (paiement, stock). |
| **A05 - Security Misconfiguration**      | `APP_DEBUG=false` en prod. CORS configuré pour le domaine front uniquement. Headers de sécurité Nginx (HSTS, X-Frame-Options, X-Content-Type-Options).                                                                   |
| **A06 - Vulnerable Components**          | `composer audit` et `npm audit` en CI. Dependabot activé sur les deux repos. Laravel 13 et React 19 sur les dernières versions stables.                                                                                  |
| **A07 - Identification & Auth Failures** | Throttling sur les routes sensibles (`throttle:5,1` sur `/contact`). Rotation du token Sanctum à chaque login (un seul token actif par user).                                                                            |
| **A08 - Software & Data Integrity**      | Signature Stripe (`Webhook::constructEvent`) avec `STRIPE_WEBHOOK_SECRET`. Images Docker signées via GHCR.                                                                                                               |
| **A09 - Security Logging & Monitoring**  | Logs Laravel (`storage/logs/`) + `Log::info('STRIPE_WEBHOOK_RECEIVED', ...)` sur les événements critiques. À renforcer avec Sentry (cf. [04-upgrade.md](./04-upgrade.md)).                                               |
| **A10 - SSRF**                           | Pas d'entrée utilisateur dans des URLs serveur-side hors OpenAI (URL fixée en config).                                                                                                                                   |

### Durcissement VPS (suite à incident ransomware staging — mai 2026)

- **Port MySQL (3306) fermé** depuis l'extérieur — accessible uniquement via le réseau Docker interne.
- **SSH** : authentification par clé uniquement (PasswordAuthentication no), root login désactivé, port non standard.
- **UFW** activé : seuls 22 (SSH), 80 (HTTP→redirect HTTPS) et 443 (HTTPS) ouverts.
- **Backups** : dump MySQL chiffré quotidien stocké hors VPS.

---

## 7. Accessibilité — référentiel OPQUAST

Le projet vise le **niveau OPQUAST « Qualité Web »** (240 critères) plutôt que le RGAA, plus adapté à un e-commerce qu'à
un site public.

Mesures appliquées :

- **Contraste** - Palette validée contre WCAG AA (ratio ≥ 4.5:1 pour les textes).
- **Navigation clavier** - Tous les éléments interactifs sont `tabindex`-able, focus visible (outline préservé).
- **Sémantique HTML** - `<button>` pour les actions, `<a>` pour la navigation, `<form>` avec `<label>` associés.
- **Images** - `alt` systématique sur les produits, `alt=""` sur les images purement décoratives.
- **Responsive** - Mobile-first, breakpoints à 640 / 1024 / 1280 px.
- **Erreurs de formulaire** - Messages affichés sous le champ concerné, jamais en alerte modale.
- **Édition de design** - L'éditeur propose un mode « formulaire » alternatif (champs texte + sélecteurs) pour les
  personnes ne pouvant pas utiliser la manipulation drag-and-drop ou la navigation 3D.

---

## 8. Limites connues et axes d'évolution

- **Pas de monitoring applicatif** en production - un Sentry ou équivalent est planifié (
  cf. [04-upgrade.md](./04-upgrade.md)).
- **Pas de queue worker dédié** - les notifications partent en sync, OK pour le volume actuel mais à externaliser quand
  le volume augmentera.
- **Pas de CDN** sur les assets - Nginx gère les statiques, suffisant tant que le trafic reste régional.
- **Couverture E2E partielle** - auth + admin couverts, parcours d'achat complet à enrichir (cf. `infra/e2e/tests/`).
