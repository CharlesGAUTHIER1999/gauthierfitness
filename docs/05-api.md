# 05 - REST API Documentation

> OpenAPI 3.1 documentation generated automatically from the backend code via **Scramble** (`dedoc/scramble`).
> Covers RNCP competency **C2.4.1**.

---

## 1. Accessing the Interactive Documentation

### Locally

```bash
cd backend
php artisan serve
```

Open <http://localhost:8000/docs/api> in the browser. Stoplight Elements displays all endpoints grouped by
functional domain, with a **"Try it"** button to test each call.

### In production

Access is restricted by default (Scramble's `RestrictedDocsAccess` middleware) - the docs aren't publicly
exposed. To view them in prod:

1. Either temporarily enable the local env on the VPS for a session (not recommended).
2. Or fetch the static `backend/swagger/openapi.json` file and open it in an external viewer (Swagger
   UI, Stoplight Elements, Postman, Insomnia).

---

## 2. OpenAPI Specification

The versioned spec file lives in the backend repo:
[`gauthierfitness-backend/swagger/openapi.json`](https://github.com/CharlesGAUTHIER1999/gauthierfitness-backend/blob/develop/swagger/openapi.json).

It's regenerated on demand:

```bash
cd backend
php artisan scramble:export
# → writes swagger/openapi.json
```

Characteristics:

- **Format** - OpenAPI 3.1
- **Documented endpoints** - 39 operations across 32 paths
- **Global security** - Bearer Sanctum
- **Tags** - Authentication, Catalog, Cart, Customization, AI, Orders, Payment, Contact, Admin - Products,
  Admin - Orders, Admin - Stock, Public

---

## 3. Authentication

All routes except the public ones (`/register`, `/login`, `/products`, `/products/{slug}`, `/contact`, `/health`,
`/stripe/webhook`) require a **Sanctum token**:

```http
Authorization: Bearer <token>
```

### Getting a token

```bash
curl -X POST https://api.gauthierfitness.fr/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","password":"secret"}'
```

Response:

```json
{
  "token": "1|XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "user": {
    "id": 1,
    "firstname": "Alice",
    "lastname": "Dupont",
    "email": "alice@example.com",
    "is_admin": false
  }
}
```

### Using the token

```bash
curl https://api.gauthierfitness.fr/api/me \
  -H "Authorization: Bearer 1|XXXXXXXXXXXXXX..."
```

### Revoking a token

```bash
curl -X POST https://api.gauthierfitness.fr/api/logout \
  -H "Authorization: Bearer <token>"
```

---

## 4. Response Format

### Success

JSON, content-type `application/json`, structure depends on the endpoint:

- **Single resource** - object serialized via an API Resource
- **Paginated collection** - `{ data: [...], links: {...}, meta: {...} }` wrapper (Laravel's default format)
- **Creation** - code 201, created resource

### Errors

| Code | Meaning                                          | Body                                                   |
|------|--------------------------------------------------|--------------------------------------------------------|
| 400  | Malformed request (e.g.: empty cart at checkout) | `{ "message": "..." }`                                 |
| 401  | Missing or invalid token                         | `{ "message": "Unauthenticated" }`                     |
| 403  | Resource belongs to another user                 | `{}` (empty body)                                      |
| 404  | Resource not found                               | `{ "message": "..." }`                                 |
| 422  | Validation failed                                | `{ "message": "...", "errors": { "field": ["..."] } }` |
| 429  | Throttling (`/contact` limited to 5/min)         | `{ "message": "Too Many Attempts." }`                  |
| 500  | Server error                                     | `{ "error": "..." }` (debug=false in prod)             |

---

## 5. Integration Examples

### Listing products with axios (JS)

```js
import axios from 'axios';

const api = axios.create({
    // In dev, VITE_API_URL is empty → axios hits /api relatively, the Vite proxy redirects to Laravel.
    // In staging/prod, VITE_API_URL = "https://api.gauthierfitness.fr/api".
    baseURL: import.meta.env.VITE_API_URL || '/api',
    headers: {Accept: 'application/json'},
});

const {data} = await api.get('/products', {
    params: {per_page: 24, gender: 'homme', tag: 'new'}
});
console.log(data.data);    // array of products
console.log(data.meta);    // pagination
```

### Creating a PaymentIntent (checkout flow)

```js
const {data} = await api.post('/payment/intent', {
    shipping: {
        firstname: 'Alice',
        lastname: 'Dupont',
        address: '12 rue de la Paix',
        zip: '75002',
        city: 'Paris',
        country: 'FR',
        phone: '+33 6 12 34 56 78',
    }
}, {
    headers: {Authorization: `Bearer ${token}`},
});

// data.client_secret is passed to stripe.confirmCardPayment()
```

### Receiving a Stripe webhook (backend side, PHP)

The API exposes `POST /api/stripe/webhook` - not documented here since it's a server-to-server endpoint called by
Stripe with an HMAC signature. See
[`StripeController::webhook`](https://github.com/CharlesGAUTHIER1999/gauthierfitness-backend/blob/develop/app/Http/Controllers/Payments/StripeController.php)
for the verification details (`Webhook::constructEvent`).

---

## 6. API Evolution

### Versioning

The API isn't version-prefixed (`/api/v1/...`) for now. The version is carried by `API_VERSION` in the OpenAPI
spec. If a major overhaul becomes necessary, the migration will move to `/api/v2/...` with v1 coexisting for
6 months.

### Deprecation policy

- A deprecated endpoint is marked `@deprecated` in its docblock — it appears struck through in the Swagger docs.
- Minimum **3-month** delay between deprecation and removal.
- Announced in the CHANGELOG (cf. [04-upgrade.md](./04-upgrade.md)) with a target date.

### Breaking changes

- Any breaking change bumps the **MAJOR** version of the spec (`v1.X.X` → `v2.0.0`).
- An email is sent to known integrators before publishing.

---

## 7. When to Update the Docs

The docs are **generated from the code** - there's nothing to maintain by hand for endpoint structure. However,
the **PHPDoc annotations** on controllers must be updated whenever:

- An endpoint is added / removed
- A new error response is handled
- An endpoint's contract changes (parameter added, response format changed)

And then **regenerate**:

```bash
cd backend
php artisan scramble:export
git add swagger/openapi.json
git commit -m "docs(api): regen openapi spec"
```

Ideally, wire up a CI check that regenerates and verifies there's no uncommitted diff:

```yaml
# .github/workflows/ci-cd.yml
- name: Verify OpenAPI is up-to-date
  run: |
    php artisan scramble:export
    git diff --exit-code swagger/openapi.json
```
