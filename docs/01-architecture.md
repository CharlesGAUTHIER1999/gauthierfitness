# 01 - Architecture & Technical Choices

> Reference document to understand **how** and **why** GauthierFitness is designed this way.
> Covers RNCP competencies **C2.2.1** (architecture and prototype), **C2.2.3** (security, accessibility) and **C2.4.1**
> (documentation of technical choices).

---

## 1. Product Vision

GauthierFitness is an e-commerce store specialized in fitness products (clothing, accessories, nutrition, equipments),
differentiated by **product personalization**:

- **3D** editor (Three.js + React-Three-Fiber) to configure a garment (t-shirt, jacket, hoodie), and preview the
  finished product.
- **AI-assisted design generation** (OpenAI Images) from a text prompt.
- **Lot-based stock** tracking with FIFO on perishable products (nutrition).

The main technical challenge is to consistently link together : a graphical editor (complex front-end state) → a
persisted customization session (back-end snapshot) → a Stripe order → logistics tracking.

---

## 2. System Overview and Architecture Diagram

```
                                ┌────────────────────────────────┐
                                │  User (browser)                 │
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
              │  - Storefront          │  │  - REST API /api/*       │
              │  - 3D editor (Three)  │  │  - AI generation         │
              │  - Admin panel        │  │  - Stock decrement        │
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
                         │ Asynchronous webhooks
                         ▼
              ┌──────────────────────────┐    ┌────────────────────┐
              │  Stripe (payment)        │    │  OpenAI Images API │
              │  PaymentIntents + WH     │    │  Design generation │
              └──────────────────────────┘    └────────────────────┘
```

### Critical flow - custom order

1. **Front** - The user builds their design in the 3D editor → `POST /api/customization/sessions` snapshots the
   configuration.
2. **Front** - Add to cart → `POST /api/cart/items` with `custom_product_session_id`.
3. **Front** - Checkout → `POST /api/payment/intent` creates the order, the `Payment` (pending), a structured
   `Shipment`, then calls Stripe to obtain a `client_secret`.
4. **Front** - Client-side confirmation via Stripe.js with the `client_secret`.
5. **Back** - Stripe webhook `payment_intent.succeeded` → marks order/payment as paid, **empties the cart**, **sends the
   confirmation email**, **decrements stock in FIFO order** (earliest-expiring lot first), all within a single DB
   transaction.
6. **Admin** - Tracks the order in the back-office and changes its status (`shipped`, `delivered`) → automatic emails to
   the customer.

---

## 3. Technical Stack - Choices and Rationale

### Backend - Laravel 13 / PHP 8.3

| Component         | Choice                          | Why                                                                                                                                    |
|-------------------|---------------------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| Framework         | **Laravel 13**                  | Maturity, Eloquent ORM, ecosystem (Sanctum, Notifications, Queue, Mail), excellent documentation, developer ergonomics for a solo dev. |
| API Auth          | **Sanctum** (Bearer token)      | Simpler than OAuth2 for a single-domain SPA. Tokens stored in DB, individually revocable. One session = one token named `react`.       |
| Database          | **MySQL 8**                     | Stable, native JSON column support (used for the `configuration` of customization sessions), easy to operate on OVH.                   |
| Payment           | **Stripe** (PaymentIntents)     | Industry standard, native 3D-Secure support, signed webhooks, PCI compliance delegated.                                                |
| AI images         | **OpenAI Images**               | Superior quality for textile designs, acceptable latency (~6-8s), pay-per-use billing.                                                 |
| API documentation | **Scramble** (`dedoc/scramble`) | Generates the OpenAPI 3.1 spec directly from controllers, FormRequests and Resources. No duplication between code and docs.            |
| Tests             | **PHPUnit 11**                  | Laravel standard, SQLite in-memory in CI for speed.                                                                                    |
| Code quality      | **Laravel Pint** (PSR-12)       | Official Laravel linter, checked in CI.                                                                                                |

### Frontend - React 19 / Vite 7

| Component    | Choice                                       | Why                                                                                                         |
|--------------|----------------------------------------------|-------------------------------------------------------------------------------------------------------------|
| UI framework | **React 19**                                 | Mature ecosystem for SPAs, hooks for composition, Suspense for data fetching.                               |
| Build        | **Vite 7**                                   | Ultra-fast HMR, native ESM, much faster than Webpack for a project this size.                               |
| Routing      | **React-router-dom 7**                       | De facto standard, file-based routing possible if complexity grows.                                         |
| Global state | **Zustand 5**                                | Lighter and less verbose than Redux. Sufficient for cart, auth, customization.                              |
| HTTP         | **Axios**                                    | Interceptors (auth, refresh), centralized error handling, more ergonomic than `fetch` for this use case.    |
| 2D editor    | **Konva** + `react-konva`                    | Canvas performance, ready-to-use drag/transform/snapping API, native PNG export for previews.               |
| 3D editor    | **Three.js** + `@react-three/fiber` + `drei` | Standard for 3D on the web, idiomatic React integration, `drei` helpers (OrbitControls, Environment, etc.). |
| Payment      | **@stripe/react-stripe-js** + Elements       | Official components, PCI compliance, automatic 3D-Secure handling.                                          |
| Icons        | **React-icons**                              | A single library, per-module import to optimize the bundle.                                                 |

### Infra - Docker + OVH

| Component        | Choice                                                 | Why                                                                                 |
|------------------|--------------------------------------------------------|-------------------------------------------------------------------------------------|
| Containerization | **Docker** multi-stage (vendor → production / testing) | Lightweight Alpine PHP-FPM image (~80 MB), reproducibility across dev/staging/prod. |
| Reverse proxy    | **Nginx** Alpine                                       | TLS, gzip compression, static file serving, caching.                                |
| Hosting          | **2 OVH VPS** (staging + production)                   | Good perf/price ratio, France datacenter (GDPR), full control over the host.        |
| Registry         | **GHCR** (GitHub Container Registry)                   | Integrated with the GitHub Actions workflow, free for public/private repos.         |
| CI/CD            | **GitHub Actions**                                     | PHPUnit + Pint + image build + deploy trigger via `repository-dispatch`.            |
| DNS              | **OVH**                                                | Managed in the same panel as the VPS, separate API and front subdomains.            |
| TLS              | **Let's Encrypt** (Certbot)                            | Automatic renewal, free, universally accepted.                                      |

---

## 4. Data Model - Key Entities

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

### Points of attention

- **Price snapshotting** - `cart_items` and `order_items` carry the price at the time of adding / ordering to avoid a
  product price change rewriting history. `custom_product_sessions` also carry a `unit_price_snapshot`.
- **Lot-based stock** - Each stock intake creates a `stock_lot` (lot number, initial quantity, expiration date).
  Outgoing movements (sales) are tracked in `stock_movements` with FIFO on the nearest expiration date.
- **Webhook idempotency** - `webhook_events` uniquely indexes `(provider, provider_event_id)` to replay without
  duplicating processing. On error, the retry count is tracked via `webhook_event_failures`.
- **Session soft state** - `custom_product_sessions` transition through `draft → ready → added_to_cart → ordered`, which
  lets the user resume an in-progress customization.

---

## 5. Conventions and Best Practices

### Code

- **PSR-12** on the PHP side, enforced by Pint (`./vendor/bin/pint --test` in CI).
- **ESLint 9** on the JS side, flat config in `eslint.config.js`.
- **Systematic PHP type hints** (params, returns) - this is what lets Scramble generate the OpenAPI docs.
- **FormRequest** for API-side validation whenever the validation logic exceeds 3 rules or requires cross-field checks (
  cf. `AddToCartRequest::withValidator`, which verifies ownership of a customization session).
- **API Resources** (`ProductResource`, `CartResource`, etc.) to decouple the JSON response from the internal model
  structure.

### Git

Branching convention: `GF{n}-{ShortName}` where `{n}` is a feature number and `{ShortName}` a CamelCase description.

Examples: `GF21-SwaggerDoc`, `GF15-TestsE2E`.

Workflow:

- `feature` → `develop` (auto-deploys to staging after green CI)
- `develop` → `main` (deploys to production after a manual gate)

Backend and frontend have separate GitHub repos but are versioned with the same branch naming convention to stay
consistent.

### Tests

- **Feature tests** (PHPUnit) for every critical API endpoint (auth, cart, payment, customization).
- **SQLite in-memory** in CI for a fast test cycle (~30s).
- **Playwright E2E tests** wired into the `infra/.github/workflows/deploy.yml` pipeline (`e2e` job, run against
  staging after every automatic deployment). Specs in `infra/e2e/tests/`.

---

## 6. Security - OWASP Top 10 Coverage

| Risk                                     | Measures in place                                                                                                                                                                                         |
|------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **A01 - Broken Access Control**          | Sanctum + `auth:sanctum` middleware on all protected routes. Custom `admin` middleware for the back-office. Explicit ownership checks (`abort_unless($order->user_id === ...)`).                          |
| **A02 - Cryptographic Failures**         | Let's Encrypt TLS on every subdomain. `bcrypt` for passwords (`Hash::make`). Secrets in an uncommitted `.env`.                                                                                            |
| **A03 - Injection**                      | Eloquent (prepared PDO) systematically. No `DB::raw()` with user input. FormRequest validation with `exists` rules for FKs.                                                                               |
| **A04 - Insecure Design**                | Price snapshotting when added to cart (a price can't be changed after ordering). Strict idempotency of Stripe webhooks (`webhook_events` table). DB transactions on critical operations (payment, stock). |
| **A05 - Security Misconfiguration**      | `APP_DEBUG=false` in prod. CORS configured for the front domain only. Nginx security headers (HSTS, X-Frame-Options, X-Content-Type-Options).                                                             |
| **A06 - Vulnerable Components**          | `composer audit` and `npm audit` in CI. Dependabot enabled on both repos. Laravel 13 and React 19 on the latest stable versions.                                                                          |
| **A07 - Identification & Auth Failures** | Throttling on sensitive routes (`throttle:5,1` on `/contact`). Sanctum token rotation on every login (a single active token per user).                                                                    |
| **A08 - Software & Data Integrity**      | Stripe signature (`Webhook::constructEvent`) with `STRIPE_WEBHOOK_SECRET`. Docker images signed via GHCR.                                                                                                 |
| **A09 - Security Logging & Monitoring**  | Laravel logs (`storage/logs/`) + `Log::info('STRIPE_WEBHOOK_RECEIVED', ...)` on critical events. To be strengthened with Sentry (cf. [04-upgrade.md](./04-upgrade.md)).                                   |
| **A10 - SSRF**                           | No user input in server-side URLs outside of OpenAI (URL fixed in config).                                                                                                                                |

### VPS hardening (following the staging ransomware incident - May 2026)

- **MySQL port (3306) closed** from the outside — accessible only via the internal Docker network.
- **SSH**: key-only authentication (PasswordAuthentication no), root login disabled, non-standard port.
- **UFW** enabled: only 22 (SSH), 80 (HTTP→redirect HTTPS) and 443 (HTTPS) open.
- **Backups**: daily encrypted MySQL dump stored off the VPS.

---

## 7. Accessibility - OPQUAST Framework

The project targets the **OPQUAST "Web Quality" level** (240 criteria) rather than RGAA, which is better suited to an
e-commerce site than a public-sector site.

Measures applied:

- **Contrast** - Palette validated against WCAG AA (ratio ≥ 4.5:1 for text).
- **Keyboard navigation** - All interactive elements are `tabindex`-able, focus visible (outline preserved).
- **HTML semantics** - `<button>` for actions, `<a>` for navigation, `<form>` with associated `<label>`s.
- **Images** - Systematic `alt` on products, `alt=""` on purely decorative images.
- **Responsive** - Mobile-first, breakpoints at 640 / 1024 / 1280 px.
- **Form errors** - Messages displayed under the relevant field, never as a modal alert.
- **Design editing** - The editor offers an alternative "form" mode (text fields + selectors) for people who
  cannot use drag-and-drop manipulation or 3D navigation.

---

## 8. Known Limitations and Evolution Areas

- **No application monitoring** in production - Sentry or an equivalent is planned (
  cf. [04-upgrade.md](./04-upgrade.md)).
- **No dedicated queue worker** - notifications are sent synchronously, fine for the current volume but to be
  externalized as volume grows.
- **No CDN** on assets - Nginx serves the static files, sufficient as long as traffic stays regional.
- **Partial E2E coverage** - auth + admin covered, full purchase journey to be expanded (cf. `infra/e2e/tests/`).
- **No manual resize for uploaded/AI-generated images in the 3D configurator** - logos, free images, and AI
  designs can be repositioned by drag (`CustomizationCanvas3D.jsx`), but their size is fixed
  (`size: {w, h}` in the layer configuration, currently 0.22 of the texture) with no handle to resize by hand as
  in a typical design tool. Planned for **V2**: a corner-drag resize handle updating `size.w`/`size.h` in real
  time, alongside the existing position drag.
