# 05 - Documentation API REST

> Documentation OpenAPI 3.1 générée automatiquement depuis le code backend via **Scramble** (`dedoc/scramble`). Couvre
> la compétence RNCP **C2.4.1**.

---

## 1. Accès à la documentation interactive

### En local

```bash
cd backend
php artisan serve
```

Ouvrir <http://localhost:8000/docs/api> dans le navigateur. Stoplight Elements affiche tous les endpoints groupés par
domaine fonctionnel avec un **« Try it »** pour tester chaque appel.

### En production

L'accès est restreint par défaut (middleware `RestrictedDocsAccess` de Scramble) - la doc n'est pas exposée
publiquement. Pour la consulter en prod :

1. Soit en activant l'env local sur le VPS le temps d'une session (déconseillé).
2. Soit en récupérant le fichier statique `backend/swagger/openapi.json` et en l'ouvrant dans un viewer externe (Swagger
   UI, Stoplight Elements, Postman, Insomnia).

---

## 2. Spécification OpenAPI

Le fichier de spec versionné est dans le repo backend : [
`gauthierfitness-backend/swagger/openapi.json`](https://github.com/CharlesGAUTHIER1999/gauthierfitness-backend/blob/develop/swagger/openapi.json).

Il est régénéré à la demande :

```bash
cd backend
php artisan scramble:export
# → écrit swagger/openapi.json
```

Caractéristiques :

- **Format** - OpenAPI 3.1
- **Endpoints documentés** - 39 opérations sur 32 paths
- **Sécurité globale** - Bearer Sanctum
- **Tags** - Authentification, Catalogue, Panier, Customisation, IA, Commandes, Paiement, Contact, Admin - Produits,
  Admin - Commandes, Admin - Stock, Public

---

## 3. Authentification

Toutes les routes sauf les publiques (`/register`, `/login`, `/products`, `/products/{slug}`, `/contact`, `/health`,
`/stripe/webhook`) nécessitent un **token Sanctum** :

```http
Authorization: Bearer <token>
```

### Obtenir un token

```bash
curl -X POST https://api.gauthierfitness.fr/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","password":"secret"}'
```

Réponse :

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

### Utiliser le token

```bash
curl https://api.gauthierfitness.fr/api/me \
  -H "Authorization: Bearer 1|XXXXXXXXXXXXXX..."
```

### Révoquer un token

```bash
curl -X POST https://api.gauthierfitness.fr/api/logout \
  -H "Authorization: Bearer <token>"
```

---

## 4. Format des réponses

### Succès

JSON, content-type `application/json`, structure dépendant de l'endpoint :

- **Ressource simple** - objet sérialisé via API Resource
- **Collection paginée** - wrapper `{ data: [...], links: {...}, meta: {...} }` (format Laravel par défaut)
- **Création** - code 201, ressource créée

### Erreurs

| Code | Signification                                   | Body                                                   |
|------|-------------------------------------------------|--------------------------------------------------------|
| 400  | Requête malformée (ex: panier vide au checkout) | `{ "message": "..." }`                                 |
| 401  | Token manquant ou invalide                      | `{ "message": "Unauthenticated" }`                     |
| 403  | Ressource d'un autre utilisateur                | `{}` (corps vide)                                      |
| 404  | Ressource introuvable                           | `{ "message": "..." }`                                 |
| 422  | Validation échouée                              | `{ "message": "...", "errors": { "champ": ["..."] } }` |
| 429  | Throttling (`/contact` limité à 5/min)          | `{ "message": "Too Many Attempts." }`                  |
| 500  | Erreur serveur                                  | `{ "error": "..." }` (debug=false en prod)             |

---

## 5. Exemples d'intégration

### Lister les produits avec axios (JS)

```js
import axios from 'axios';

const api = axios.create({
    // En dev, VITE_API_URL est vide → axios tape /api en relatif, le proxy Vite redirige vers Laravel.
    // En staging/prod, VITE_API_URL = "https://api.gauthierfitness.fr/api".
    baseURL: import.meta.env.VITE_API_URL || '/api',
    headers: {Accept: 'application/json'},
});

const {data} = await api.get('/products', {
    params: {per_page: 24, gender: 'homme', tag: 'new'}
});
console.log(data.data);    // tableau de produits
console.log(data.meta);    // pagination
```

### Créer un PaymentIntent (parcours checkout)

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

// data.client_secret à passer à stripe.confirmCardPayment()
```

### Recevoir un webhook Stripe (côté backend, PHP)

L'API expose `POST /api/stripe/webhook` - non documenté ici car il s'agit d'un endpoint serveur-à-serveur appelé par
Stripe avec une signature HMAC. Voir [
`StripeController::webhook`](https://github.com/CharlesGAUTHIER1999/gauthierfitness-backend/blob/develop/app/Http/Controllers/StripeController.php)
pour le détail de la vérification (`Webhook::constructEvent`).

---

## 6. Évolutions de l'API

### Versioning

L'API n'est pas préfixée par version (`/api/v1/...`) pour l'instant. La version est portée par `API_VERSION` dans la
spec OpenAPI. Si une refonte majeure est nécessaire, la migration se fera vers `/api/v2/...` avec coexistence de la v1
pendant 6 mois.

### Politique de dépréciation

- Un endpoint déprécié est marqué `@deprecated` dans son docblock — il apparaît barré dans la doc Swagger.
- Délai minimum **3 mois** entre la dépréciation et le retrait.
- Annonce dans le CHANGELOG (cf. [04-upgrade.md](./04-upgrade.md)) avec date cible.

### Changements cassants

- Tout breaking change incrémente la **MAJOR** de la spec (`v1.X.X` → `v2.0.0`).
- Diffusion d'un email aux intégrateurs connus avant publication.

---

## 7. Quand mettre à jour la doc ?

La doc est **générée du code** - il n'y a rien à maintenir à la main pour la structure des endpoints. En revanche, il
faut **mettre à jour les annotations PHPDoc** des controllers à chaque fois que :

- Un endpoint est ajouté / supprimé
- Une nouvelle réponse d'erreur est gérée
- Le contrat d'un endpoint change (paramètre ajouté, format de réponse modifié)

Et **régénérer** :

```bash
cd backend
php artisan scramble:export
git add swagger/openapi.json
git commit -m "docs(api): regen openapi spec"
```

Idéalement, on branche un check CI qui régénère et vérifie l'absence de diff non commitée :

```yaml
# .github/workflows/ci-cd.yml
- name: Verify OpenAPI is up-to-date
  run: |
    php artisan scramble:export
    git diff --exit-code swagger/openapi.json
```
