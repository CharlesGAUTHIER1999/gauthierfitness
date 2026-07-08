# Fiches d'incident — GauthierFitness

Prêtes à être intégrées dans le Bloc 2 (C2.3.2 — Plan de correction des bogues) et le Bloc 4 (C4.2.1 — Consignation des anomalies / C4.2.2 — Correctifs). Rédigées à partir du code et de l'historique git réels du projet.

---

## Fiche 1 — Scramble incompatible avec `php artisan config:cache`

**Contexte**
- Environnement : Production (déploiement)
- Repo / commits : `backend`, `95c595d` + `4a53741` (19/06/2026)
- Gravité : **S1 — Critique** (bloque le déploiement en production)

**Étapes de reproduction**
1. Définir le `SecurityScheme` Scramble directement dans `config/scramble.php`.
2. Exécuter `php artisan config:cache` (utilisé par le pipeline de déploiement prod).
3. Le cache de configuration échoue car Laravel tente de sérialiser la config avec `var_export()`.

**Comportement attendu**
Le déploiement s'exécute sans erreur ; `config:cache` réussit et sert une configuration mise en cache pour de meilleures performances.

**Comportement observé**
`php artisan config:cache` échoue : l'objet `SecurityScheme` de Scramble n'est pas sérialisable par `var_export()`. Le déploiement prod s'arrête en échec.

**Impact utilisateur**
Aucun impact utilisateur final direct (échec détecté avant la bascule de trafic), mais bloque toute mise en production tant que non résolu — risque de gel des livraisons.

**Analyse / cause racine**
La définition du schéma de sécurité vivait dans un fichier de config statique (`config/scramble.php`), alors qu'elle contient un objet PHP complexe non compatible avec la sérialisation `var_export()` utilisée par `config:cache`.

**Correctif appliqué**
Déplacement de la définition du `SecurityScheme` dans `AppServiceProvider` (code exécuté au boot de l'application plutôt que sérialisé en config statique). Deux commits : le déplacement initial (`95c595d`) puis un nettoyage (`4a53741`).

**Validation**
`config:cache` s'exécute sans erreur, redéploiement réussi, documentation Swagger/OpenAPI toujours générée correctement (`swagger/openapi.json` régénéré dans le même commit).

---

## Fiche 2 — Divergence de prix entre l'affichage et le montant réellement facturé (produits personnalisés)

**Contexte**
- Environnement : Détecté en relecture de code (contrôle qualité pré-V1), avant impact réel en production
- Repo / fichier : `backend/app/Http/Controllers/StripeController.php`
- Gravité : **S1 — Critique** (paiement / intégrité financière)

**Étapes de reproduction**
1. Ajouter au panier un produit personnalisé avec une session de personnalisation ayant un `unit_price_snapshot` différent du prix de base du produit/option.
2. Lancer le paiement (`createPaymentIntent`) : le montant facturé à Stripe utilise le snapshot de prix de la session.
3. Observer la ligne de commande (`OrderItem`) créée en parallèle.

**Comportement attendu**
Le montant facturé par Stripe et le prix enregistré sur la ligne de commande (`OrderItem.unit_price`) doivent être strictement identiques.

**Comportement observé**
Deux boucles distinctes recalculaient le prix unitaire différemment pour le même article : l'une pour le total envoyé à Stripe (avec snapshot), l'autre pour l'enregistrement de la ligne de commande (sans le même ordre de priorité) — risque de divergence entre le montant réellement débité et le montant enregistré.

**Impact utilisateur**
Risque de facturation incohérente avec l'historique de commande affiché au client (montant débité ≠ montant affiché sur la commande).

**Analyse / cause racine**
Duplication de la logique de calcul de prix dans deux blocs de code séparés de la même méthode, sans source unique de vérité.

**Correctif appliqué**
Fusion en une seule logique de calcul, désormais isolée dans `App\Services\Pricing\CartPricingCalculator` (`unitPrice()`, `lineTotal()`, `round()`) et réutilisée à la fois pour le total Stripe et pour la création de `OrderItem`.

**Validation**
Test de non-régression `StripeIntentTest::test_order_item_price_matches_the_amount_charged_for_customized_products` — rouge sur l'ancien code, vert après correctif (confirmé dans la suite actuelle : 164/164 tests backend verts). Complété par 6 tests unitaires purs sur `CartPricingCalculatorTest`.

---

## Fiche 3 — Redirection aléatoire après connexion (race condition frontend)

**Contexte**
- Environnement : Détecté en E2E (Cypress), reproduit manuellement
- Repo / fichier : `frontend/src/pages/Login.jsx`
- Statut : correctif prêt sur la branche en cours (à fusionner avec GF31)
- Gravité : **S2 — Majeure** (contournement possible : recharger/renaviguer manuellement)

**Étapes de reproduction**
1. Se connecter avec des identifiants valides.
2. Observer la redirection immédiatement après la résolution de la promesse `login()`.
3. Répéter plusieurs fois : l'atterrissage varie aléatoirement entre la page de destination attendue et `/login`.

**Comportement attendu**
Après une connexion réussie, l'utilisateur est systématiquement redirigé vers la destination prévue (page demandée via `?redirect=`, ou `/admin`/`/` selon le rôle).

**Comportement observé**
La navigation était déclenchée juste après la résolution de `login()`, avant que le contexte d'authentification React (`token`/`user`) n'ait fini de se propager. Les gardes de route (`ProtectedRoute`/`AdminRoute`) lisaient parfois un contexte encore obsolète, renvoyant l'utilisateur vers `/login`.

**Impact utilisateur**
Utilisateur connecté avec succès mais renvoyé à tort vers l'écran de connexion — confusion, perception d'un bug de connexion alors que l'authentification a réussi côté serveur.

**Analyse / cause racine**
`setState` React asynchrone (mise à jour du contexte d'authentification) lu trop tôt par un appel `navigate()` synchrone exécuté juste après l'await de `login()`.

**Correctif appliqué**
La navigation est désormais déclenchée depuis un `useEffect` qui observe l'état d'authentification (`token`, `user`) une fois réellement commité, plutôt qu'en synchrone après l'appel à `login()`.

**Validation**
3 tests de non-régression ajoutés dans `Login.test.jsx` (confirmés verts dans la suite actuelle : 39/39 tests frontend).

---

## Fiche 4 — Incident ransomware sur le VPS staging (28/05/2026)

**Contexte**
- Environnement : VPS staging OVH (`51.210.15.118`)
- Date : 28/05/2026
- Gravité : **S1 — Critique** (compromission de données, bien que sans impact réel grâce aux sources locales)

**Étapes de reproduction / vecteur d'attaque**
1. `docker-compose.yml` publiait le port MySQL sur `0.0.0.0:3306` (accessible depuis Internet).
2. Mots de passe de base de données par défaut, insuffisamment robustes.
3. Un bot automatisé a scanné et trouvé le port ouvert, s'est connecté, puis a supprimé (`DROP`) l'ensemble des tables.
4. Une table de rançon `RECOVER_YOUR_DATA_info` a été laissée (demande de 0.016 BTC).

**Comportement attendu**
Aucun service de base de données ne doit être accessible directement depuis Internet ; seul le backend applicatif (réseau Docker interne) doit pouvoir s'y connecter.

**Comportement observé**
Toutes les tables de la base staging supprimées par l'attaquant. Rançon non payée.

**Impact utilisateur**
Aucune perte réelle de données : les données sources existaient en local (environnement de développement), la base staging a simplement été reconstituée. Aucun impact sur la production (jamais compromise) ni sur des données clients réelles.

**Analyse / cause racine**
- Cause directe : port 3306 publié dans `docker-compose.yml` (`ports: - "3306:3306"`).
- Cause aggravante découverte pendant l'investigation : `docker-compose.prod.yml` déclarait `db: ports: []`, dans l'intention de fermer le port en production — mais Docker Compose **concatène** les listes `ports` entre fichiers superposés au lieu de les remplacer, donc la prod restait, elle aussi, exposée (fermée dès le lendemain, jamais compromise).
- `ufw` ne bloque pas les ports publiés par Docker : Docker écrit directement dans `iptables`, contournant le firewall applicatif.

**Correctif et durcissement appliqués (sur les deux VPS, staging et prod)**
- Retrait complet du port 3306 de `docker-compose.yml` (commité sur `main`, source du déploiement).
- Rotation des mots de passe de base de données (utilisateur applicatif + `root@%`/`root@localhost`).
- Durcissement SSH (`/etc/ssh/sshd_config.d/00-hardening.conf`) : `PasswordAuthentication no`, `PermitRootLogin no` — préfixe `00-` pour s'appliquer avant `50-cloud-init.conf` qui réactive l'authentification par mot de passe.
- Pare-feu `ufw` : politique par défaut `deny incoming`, autorisation explicite des ports 22/80/443.

**Validation**
Vérification en conditions réelles (06/07/2026) : test de connexion TCP sur le port 3306 depuis l'extérieur, prod et staging — `TcpTestSucceeded: False` sur les deux VPS (`51.38.234.197` et `51.210.15.118`). Port confirmé non joignable depuis Internet.

**Dette restante à mentionner**
Le durcissement (ufw, SSH) vit directement sur les VPS et n'est pas versionné dans l'infra-as-code — à reproduire manuellement si un VPS est reconstruit. Amélioration proposée (C4.3.1) : script `setup-vps.sh` versionné.

---

## Fiche 5 — `Class "Redis" not found` détectée via Sentry

**Contexte**
- Environnement : Production / staging (détecté via Sentry, 41 occurrences sur 1 semaine, statut "Ongoing" au moment de la détection)
- Repo / fichier : `backend/config/database.php` (config Redis), `infra/docker-compose.yml`, `infra/.env.prod.example` / `.env.staging.example`
- Gravité : **S2 — Majeure** (dégrade les requêtes qui touchent le cache/session/queue redis, sans rendre le site totalement indisponible)

**Étapes de reproduction**
1. Déployer avec `CACHE_STORE=redis` / `SESSION_DRIVER=redis` / `QUEUE_CONNECTION=redis` (valeurs prévues dans `infra/.env.prod.example` et `.env.staging.example`, un service Docker `redis` existe bien dans `docker-compose.yml`).
2. Toute requête qui sollicite effectivement le cache, la session ou la queue redis lève `Class "Redis" not found`.

**Comportement attendu**
Le cache/session/queue redis fonctionne normalement, sans erreur.

**Comportement observé**
Erreur fatale `Class "Redis" not found` remontée par Sentry (`PHP-LARAVEL-6`), 41 événements sur une semaine, dernière occurrence 16 h avant détection, sur la route `/`.

**Impact utilisateur**
Dégradation silencieuse (session/cache/queue en échec) sur les requêtes concernées, sans page d'erreur visible pour l'utilisateur final dans la majorité des cas (le site restait globalement fonctionnel, confirmé par des tests `curl` sur prod et staging le jour de l'investigation).

**Analyse / cause racine**
Laravel résout le client Redis via `config('database.redis.client')`, dont la valeur par défaut du framework est `phpredis` (extension PHP native). Le `Dockerfile` backend n'installe pas l'extension `ext-redis`, et `predis/predis` (client Redis pur PHP, alternative à l'extension) n'était pas déclaré comme dépendance directe du projet — uniquement suggéré en dépendance optionnelle par des packages tiers (Sentry SDK notamment). Résultat : dès qu'un code path sollicitait réellement Redis, la classe `Redis` (extension native) était introuvable.

**Correctif appliqué**
- `composer require predis/predis` (client Redis pur PHP, aucune extension native ni changement d'image Docker nécessaire).
- `config/database.php` : valeur par défaut de `REDIS_CLIENT` changée de `phpredis` à `predis`.

**Validation**
Suite complète rejouée après le correctif : 164/164 tests backend toujours verts, `pint --test` toujours clean. **Nécessite un redéploiement** (rebuild de l'image incluant `composer install`) pour prendre effet en prod/staging — à valider avec le prochain `docker compose up -d --build` / pipeline de déploiement (GF31).

---

---

## Fiche 6 — Webhook `payment_intent.payment_failed` non écouté (staging)

**Contexte**
- Environnement : Staging, détecté en exécutant manuellement le scénario **PAY-12** (parcours 3DS Stripe, cahier de recettes C2.3.1)
- Repo : `infra` (configuration du endpoint webhook Stripe, hors code applicatif)
- Gravité : **S1 — Critique** (impact direct sur le suivi des commandes en cas de paiement refusé)

**Étapes de reproduction**
1. Jouer PAY-12 avec la carte de test 3DS refusée (`4000008400001629`) : le paiement échoue correctement côté Stripe (`payment_intent.payment_failed` généré, visible dans l'onglet "Événements" du Dashboard Stripe).
2. Observer la commande correspondante côté application : elle reste en `payment_status = pending` / statut "Nouvelle" au lieu de passer à `failed`.

**Comportement attendu**
Une commande dont le paiement est refusé doit voir son `payment_status` passer à `failed` (logique déjà présente et correcte dans `StripeController::webhook`).

**Comportement observé**
La commande reste indéfiniment en `pending`, alors que Stripe a bien généré l'événement d'échec.

**Analyse / cause racine**
Comparaison de l'onglet "Webhooks → Événements envoyés" du endpoint staging (`https://staging.gauthierfitness.fr/api/stripe/webhook`) avec le log global des événements Stripe : seul `payment_intent.succeeded` apparaissait dans les événements réellement envoyés à ce endpoint. Le endpoint webhook staging n'était tout simplement **pas configuré pour écouter** `payment_intent.payment_failed` — Stripe génère l'événement mais ne le transmet jamais à l'application si le type d'événement n'est pas sélectionné sur la destination. Le code applicatif n'était donc jamais en cause : il gère cet événement correctement dès qu'il le reçoit.

**Correctif appliqué**
Ajout de `payment_intent.payment_failed` à la liste des événements écoutés par la destination webhook staging (Stripe Dashboard → Webhooks → endpoint → Modifier la destination). Vérification croisée : l'endpoint de **production** écoutait déjà correctement les deux événements (`payment_intent.succeeded` + `payment_intent.payment_failed`) — la production n'était pas concernée par cette anomalie.

**Validation**
Rejeu du scénario PAY-12 (carte refusée) après correctif : l'événement `payment_intent.payment_failed` est désormais envoyé au endpoint staging (200 OK), et la commande passe bien en statut `failed` côté back-office — confirmé par Charles après retest.

**Leçon retenue**
La configuration des événements écoutés par un webhook Stripe n'est pas versionnée (elle vit uniquement dans le Dashboard Stripe), contrairement au code qui la traite — un écart peut donc exister silencieusement entre les deux environnements sans qu'aucun test automatisé ne le détecte, puisque les tests PHPUnit simulent directement l'appel webhook plutôt que de dépendre de la config Stripe réelle. Seule l'exécution manuelle du scénario PAY-12 (justement prévue au cahier de recettes) a permis de le détecter avant la mise en production définitive.

---

## Fiche 7 — `.env.docker.example` manquant : `docker compose up` échoue sur un clone frais

**Contexte**
- Environnement : local (test de démarrage sur un zip fraîchement téléchargé, hors dev habituel)
- Repo / commits : `backend`, `2715877`/`7831340` (08/07/2026) ; `gauthierfitness` (meta-repo), `c4ebeeb`/`b8fff28`
- Consignée sous forme d'issue GitHub réelle : [`gauthierfitness-backend#79`](https://github.com/CharlesGAUTHIER1999/gauthierfitness-backend/issues/79) (ouverte puis fermée le 08/07/2026, via le template `.github/ISSUE_TEMPLATE/bug_report.md`)
- Gravité : **S2 — Majeure** (un des deux chemins de démarrage documentés était bloquant, pas de contournement sans lire le code)

**Étapes de reproduction**
1. Cloner `gauthierfitness-backend` à neuf (ou extraire le zip de remise `scripts/build-release-zip.ps1 -Ref v1.0.0`).
2. Suivre le README § « Docker (optionnel) » : `cp .env.example .env` puis `docker compose up -d`.
3. La commande échoue immédiatement.

**Comportement attendu**
`docker compose up -d` démarre les 3 conteneurs (`app`, `nginx`, `db`) sans erreur, comme documenté dans le README.

**Comportement observé**
`env file .../backend/.env.docker not found`. `docker-compose.yml` référence `.env.docker` en `env_file` pour le service `app`, mais ce fichier n'existe que localement chez l'auteur (gitignored via `.env.*`) et aucun `.env.docker.example` n'était fourni pour le régénérer sur un clone vierge. Le contournement documenté dans `docs/02-deployment.md` (`cp .env.example .env.docker`) aurait de toute façon échoué au démarrage réel : `.env.example` définit `DB_HOST=127.0.0.1`, alors que depuis le conteneur `app` la base doit être jointe via le nom de service Docker `db`.

**Impact utilisateur**
Bloque tout jury/évaluateur ou nouveau développeur suivant le README à la lettre pour lancer l'app via Docker sur un clone 100 % vierge.

**Analyse / cause racine**
`.env` a son `.env.example` versionné, mais `.env.docker` n'avait pas d'équivalent — oubli lors de la mise en place du Docker Compose local, jamais détecté faute d'avoir testé un clone réellement vierge.

**Correctif appliqué**
`backend/.env.docker.example` créé (placeholders, `DB_HOST=db`) + exception ajoutée dans `.gitignore` (`!.env.docker.example`). README backend et `docs/02-deployment.md` (meta-repo) mis à jour avec la bonne commande.

**Validation**
Vérifié de bout en bout sur un zip `v1.0.0` fraîchement extrait : `docker compose up -d` → `migrate --seed` → `storage:link` → `GET /api/health` → `200 {"status":"ok"}`. Correctif poussé sur `main` sans réémettre de tag (le chemin de démarrage principal sans Docker était déjà vérifié fonctionnel, la section Docker restant explicitement « optionnelle »).

---

## Fiche 8 — CSP trop restrictive : configurateur 3D affiche une page blanche en production

**Contexte**
- Environnement : Production **et** staging (`gauthierfitness.fr` / `staging.gauthierfitness.fr`)
- Repo / fichiers : `infra/nginx/prod.conf` + `staging.conf`, `frontend/src/features/customization/components/CustomizationCanvas3D.jsx`
- Détecté via : audit Lighthouse authentifié sur la page `/products/:slug/customize` (jusque-là jamais auditée — seule la Home l'avait été)
- Gravité : **S1 — Critique** (fonctionnalité phare du produit totalement inutilisable en production)

**Étapes de reproduction**
1. Se connecter et naviguer vers la page de personnalisation d'un produit customisable (ex. `/products/hommes-tshirts-t-shirt-training-211/customize`).
2. Observer la console navigateur et le rendu de la page.

**Comportement attendu**
Le configurateur 3D (Three.js) se charge : modèle du vêtement affiché avec éclairage studio, texture, zones personnalisables.

**Comportement observé**
Page blanche. Score Lighthouse Performance = **0/100** sur cette page (contre 99/100 sur la Home). Console :
```
CompileError: WebAssembly.instantiate(): violates CSP — 'unsafe-eval' non autorisé dans script-src
Refused to connect to 'blob:https://gauthierfitness.fr/...' — connect-src ne liste pas blob:
Refused to connect to 'https://raw.githack.com/pmndrs/drei-assets/.../studio_small_03_1k.hdr' — domaine absent de connect-src
THREE.WebGLRenderer: Context Lost.
```

**Impact utilisateur**
Fonctionnalité centrale du produit (personnalisation 2D/3D avec génération IA) totalement inaccessible pour tout utilisateur en production et staging.

**Analyse / cause racine**
La politique CSP durcie (ajoutée pour couvrir OWASP Top 10 / A05, cf. Fiche sécurité) autorisait `script-src 'self' https://js.stripe.com` et `connect-src 'self' https://api.stripe.com https://*.sentry.io ...`, sans anticiper trois besoins du pipeline Three.js :
1. Le décodeur WASM (Draco/Meshopt) utilisé par `GLTFLoader` pour charger le mesh compressé nécessite la compilation WebAssembly, bloquée sans directive dédiée.
2. `GLTFLoader` charge les textures via des URLs `blob:` créées côté client (fetch), non couvertes par `connect-src 'self'`.
3. Le composant `<Stage environment="studio">` (`@react-three/drei`) va chercher par défaut une texture d'environnement HDR sur un CDN tiers (`raw.githack.com`), jamais whitelisté.
Ce bug n'avait jamais été détecté car le cahier de recettes (SEC-01/SEC-02) vérifiait seulement la **présence** du header CSP, pas son impact fonctionnel sur les pages qui en dépendent le plus — et aucun audit Lighthouse n'avait encore ciblé la page configurateur.

**Correctif appliqué**
- **Suppression de la dépendance externe** plutôt qu'élargissement de la CSP : le fichier HDR est désormais auto-hébergé (`frontend/public/hdri/studio_small_03_1k.hdr`, 1.6 Mo), `environment="studio"` remplacé par `environment={{ files: "/hdri/studio_small_03_1k.hdr" }}` — sert depuis `'self'`, aucune règle CSP supplémentaire requise pour ce point.
- CSP `script-src` : ajout de `'wasm-unsafe-eval'` (directive scoped WebAssembly, volontairement préférée à `'unsafe-eval'` qui aurait aussi autorisé `eval()`/`Function()` arbitraires — surface d'attaque XSS bien plus large).
- CSP `connect-src` et `img-src` : ajout de `blob:`.
- Commits : `frontend` `5d4eb20`/`f3066b1`, `infra` `940b762`/`2504e06`.

**Déploiement**
Staging (`workflow_dispatch`, run infra #28971976887) puis production (`workflow_dispatch` avec gate manuel d'approbation sur l'environnement GitHub « Production », run #28973278625) le 08/07/2026.

**Validation**
Audit Lighthouse authentifié rejoué sur la page configurateur après déploiement :

| | Avant correctif | Après correctif |
|---|---|---|
| Performance | **0** (page blanche) | **66** |
| Accessibilité | 93 | 94 |
| Bonnes pratiques | 92 | **100** |
| SEO | 100 | 100 |
| Erreurs console | 6+ (CSP, WebGL context lost) | **0** |

Capture d'écran avant/après dans `lighthouse/4-prod-configurateur-avant-fix-csp-page-blanche.png` et `lighthouse/4-prod-configurateur-apres-fix-csp.report.html`.

---

## Note — `guest_token` column not found (probable résidu déjà résolu)

Deux erreurs Sentry liées (`Illuminate\Database\QueryException` — colonne `guest_token` introuvable sur `/api/cart/items`, et `Cannot drop index 'carts_user_id_unique'` lors d'une migration locale), datées du 02-03/07/2026, coïncident exactement avec la création de la migration `2026_07_02_213224_make_carts_guest_capable.php`. Cette migration contient déjà le correctif exact de la seconde erreur (commentaire explicite : *"MySQL requires dropping the FK before dropping the unique index backing it"*), et la suite `GuestCartTest` (7 tests, dont l'usage du `guest_token`) est aujourd'hui intégralement verte. Conclusion : très probablement des événements résiduels de la phase d'écriture de la migration (avant qu'elle ne soit exécutée/corrigée sur l'environnement concerné), pas une anomalie encore active. Pas de nouveau correctif nécessaire — à mentionner dans le cahier de recettes comme anomalie détectée puis résolue (C4.2.1) plutôt qu'ignorée silencieusement.
