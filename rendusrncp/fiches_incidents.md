# Incident Reports - GauthierFitness

---

## Report 1: Scramble incompatible with `php artisan config:cache`

**Context**
- Environment: Production (deployment)
- Repo / commits: `backend`, `95c595d` + `4a53741` (2026-06-19)
- Severity: **S1 - Critical** (blocks production deployment)

**Steps to reproduce**
1. Define the Scramble `SecurityScheme` directly in `config/scramble.php`.
2. Run `php artisan config:cache` (used by the prod deployment pipeline).
3. The config cache fails because Laravel tries to serialize the config with `var_export()`

**Expected behavior**
The deployment runs without error; `config:cache` succeeds and serves a cached configuration for better
performance.

**Observed behavior**
`php artisan config:cache` fails: Scramble's `SecurityScheme` object is not serializable by `var_export()`. The
prod deployment stops with a failure.

**User impact**
No direct end-user impact (failure caught before traffic cutover), but blocks any production release until
resolved - risk of a delivery freeze.

**Analysis / root cause**
The security scheme definition lived in a static config file (`config/scramble.php`), while it holds a complex
PHP object incompatible with the `var_export()` serialization used by `config:cache`.

**Fix applied**
Moved the `SecurityScheme` definition into `AppServiceProvider` (code executed at application boot). Two commits:
the initial move (`95c595d`) then a cleanup (`4a53741`).

**Validation**
`config:cache` runs without error, redeployment succeeded, Swagger/OpenAPI documentation still generated
correctly (`swagger/openapi.json` regenerated in the same commit).

---

## Report 2: Price mismatch between the displayed amount and the amount actually charged (customized products)

**Context**
- Environment: Found during code review (pre-V1 quality control), before any real production impact
- Repo / file: `backend/app/Http/Controllers/Payments/StripeController.php`
- Severity: **S1 - Critical** (payment, financial integrity)

**Steps to reproduce**
1. Add a customized product to the cart with a customization session whose `unit_price_snapshot` differs from
   the product's/option's base price.
2. Start the payment (`createPaymentIntent`): the amount charged to Stripe uses the session's price snapshot.
3. Observe the order line (`OrderItem`) created in parallel.

**Expected behavior**
The amount charged by Stripe and the price recorded on the order line (`OrderItem.unit_price`) must be strictly
identical.

**Observed behavior**
2 separate loops recalculated the unit price differently for the same item: one for the total sent to Stripe
(with the snapshot), the other for recording the order line (without the same priority order) - risk of a
mismatch between the amount actually charged and the amount recorded.

**User impact**
Risk of inconsistent billing versus the order history shown to the customer (amount charged ≠ amount shown on
the order).

**Analysis / root cause**
Duplicated price calculation logic in two separate code blocks of the same method, with no single source of
truth.

**Fix applied**
Merged into a single calculation logic, now isolated in `App\Services\Pricing\CartPricingCalculator`
(`unitPrice()`, `lineTotal()`, `round()`) and reused both for the Stripe total and for creating the `OrderItem`.

**Validation**
Regression test `StripeIntentTest::test_order_item_price_matches_the_amount_charged_for_customized_products` -
red on the old code, green after the fix (confirmed in the current suite: 164/164 backend tests green).
Complemented by 6 pure unit tests on `CartPricingCalculatorTest`.

---

## Report 3: Random redirect after login (frontend race condition)

**Context**
- Environment: Found in E2E (Cypress), reproduced manually
- Repo / file: `frontend/src/pages/Login.jsx`
- Status: fix ready on the current branch (to be merged with GF31)
- Severity: **S2 - Major** (workaround possible: manually reload/renavigate)

**Steps to reproduce**
1. Log in with valid credentials.
2. Observe the redirect immediately after the `login()` promise resolves.
3. Repeat several times: the landing page varies randomly between the expected destination and `/login`.

**Expected behavior**
After a successful login, the user is consistently redirected to the intended destination (page requested via
`?redirect=`, or `/admin`/`/` depending on role).

**Observed behavior**
Navigation was triggered right after `login()` resolved, before the React authentication context (`token`/`user`)
had finished propagating. The route guards (`ProtectedRoute`/`AdminRoute`) sometimes read a still-stale context,
sending the user back to `/login`.

**User impact**
User successfully logged in but wrongly sent back to the login screen - confusion, perceived as a login bug even
though server-side authentication succeeded.

**Analysis / root cause**
Asynchronous React `setState` (authentication context update) read too early by a synchronous `navigate()` call
executed right after awaiting `login()`.

**Fix applied**
Navigation is now triggered from a `useEffect` that watches the authentication state (`token`, `user`) once it's
actually committed, rather than synchronously right after the `login()` call.

**Validation**
3 regression tests added in `Login.test.jsx` (confirmed green in the current suite: 39/39 frontend tests).

---

## Report 4: Ransomware incident on the staging VPS (2026-05-28)

**Context**
- Environment: OVH staging VPS (`51.210.15.118`)
- Date: 2026-05-28
- Severity: **S1 - Critical** (data compromise, though with no real impact thanks to local sources)

**Steps to reproduce / attack vector**
1. `docker-compose.yml` published the MySQL port on `0.0.0.0:3306` (reachable from the Internet).
2. Default database passwords, insufficiently strong.
3. An automated bot scanned and found the open port, connected, then dropped (`DROP`) all the tables.
4. A ransom table `RECOVER_YOUR_DATA_info` was left behind (demanding 0.016 BTC).

**Expected behavior**
No database service should be directly reachable from the Internet; only the application backend (internal
Docker network) should be able to connect to it.

**Observed behavior**
All tables in the staging database were deleted by the attacker. Ransom not paid.

**User impact**
No real data loss: the source data existed locally (development environment), the staging database was simply
rebuilt. No impact on production (never compromised) nor on real customer data.

**Analysis / root cause**
- Direct cause: port 3306 published in `docker-compose.yml` (`ports: - "3306:3306"`).
- Aggravating cause found during the investigation: `docker-compose.prod.yml` declared `db: ports: []`, intending
  to close the port in production - but Docker Compose **concatenates** `ports` lists across overlaid files
  instead of replacing them, so production was, in fact, also exposed (closed the very next day, never
  compromised).
- `ufw` doesn't block ports published by Docker: Docker writes directly to `iptables`, bypassing the application
  firewall.

**Fix and hardening applied (on both VPS, staging and prod)**
- Fully removed port 3306 from `docker-compose.yml` (committed to `main`, the deployment source).
- Rotated database passwords (application user + `root@%`/`root@localhost`).
- SSH hardening (`/etc/ssh/sshd_config.d/00-hardening.conf`): `PasswordAuthentication no`,
  `PermitRootLogin no` — `00-` prefix so it applies before `50-cloud-init.conf`, which re-enables password
  authentication.
- `ufw` firewall: default policy `deny incoming`, explicit allow for ports 22/80/443.

**Validation**
Verified under real conditions (2026-07-06): TCP connection test on port 3306 from the outside, prod and staging
- `TcpTestSucceeded: False` on both VPS (`51.38.234.197` and `51.210.15.118`). Port confirmed unreachable from
the Internet.

**Remaining debt to mention**
The hardening (ufw, SSH) lives directly on the VPS and isn't versioned as infrastructure-as-code — it would need
to be reproduced manually if a VPS is rebuilt. Proposed improvement (C4.3.1): a versioned `setup-vps.sh` script.

---

## Report 5: `Class "Redis" not found` detected via Sentry

**Context**
- Environment: Production / staging (detected via Sentry, 41 occurrences over 1 week, status "Ongoing" at time of
  detection)
- Repo / file: `backend/config/database.php` (Redis config), `infra/docker-compose.yml`,
  `infra/.env.prod.example` / `.env.staging.example`
- Severity: **S2 - Major** (degrades requests touching the redis cache/session/queue, without making the site
  fully unavailable)

**Steps to reproduce**
1. Deploy with `CACHE_STORE=redis` / `SESSION_DRIVER=redis` / `QUEUE_CONNECTION=redis` (values set in
   `infra/.env.prod.example` and `.env.staging.example`, a `redis` Docker service does exist in
   `docker-compose.yml`).
2. Any request that actually uses the redis cache, session, or queue throws `Class "Redis" not found`.

**Expected behavior**
The redis cache/session/queue works normally, without error.

**Observed behavior**
Fatal error `Class "Redis" not found` reported by Sentry (`PHP-LARAVEL-6`), 41 events over one week, last
occurrence 16 hours before detection, on the `/` route.

**User impact**
Silent degradation (session/cache/queue failing) on the affected requests, with no visible error page for the
end user in most cases (the site remained broadly functional, confirmed by `curl` tests on prod and staging on
the day of the investigation).

**Analysis / root cause**
Laravel resolves the Redis client via `config('database.redis.client')`, whose framework default is `phpredis`
(native PHP extension). The backend `Dockerfile` doesn't install the `ext-redis` extension, and `predis/predis`
(a pure-PHP Redis client, an alternative to the extension) wasn't declared as a direct project dependency - only
suggested as an optional dependency by third-party packages (notably the Sentry SDK). Result: as soon as any code
path actually used Redis, the `Redis` class (native extension) couldn't be found.

**Fix applied**
- `composer require predis/predis` (pure-PHP Redis client, no native extension or Docker image change needed).
- `config/database.php`: default value of `REDIS_CLIENT` changed from `phpredis` to `predis`.

**Validation**
Full suite replayed after the fix: 164/164 backend tests still green, `pint --test` still clean. **Requires a
redeploy** (image rebuild including `composer install`) to take effect in prod/staging — to be validated with
the next `docker compose up -d --build` / deployment pipeline run (GF31).

---

## Report 6: `payment_intent.payment_failed` webhook not listened to (staging)

**Context**
- Environment: Staging, found while manually running scenario **PAY-12** (Stripe 3DS flow, recette test book
  C2.3.1)
- Repo: `infra` (Stripe webhook endpoint configuration, outside application code)
- Severity: **S1 — Critical** (direct impact on order tracking when a payment is declined)

**Steps to reproduce**
1. Run PAY-12 with the declined 3DS test card (`4000008400001629`): the payment correctly fails on Stripe's side
   (`payment_intent.payment_failed` generated, visible under the "Events" tab of the Stripe Dashboard).
2. Observe the corresponding order on the application side: it stays at `payment_status = pending` / status "New"
   instead of moving to `failed`.

**Expected behavior**
An order whose payment is declined should have its `payment_status` move to `failed` (logic already present and
correct in `StripeController::webhook`).

**Observed behavior**
The order stays at `pending` indefinitely, even though Stripe did generate the failure event.

**Analysis / root cause**
Comparing the "Webhooks → Events sent" tab of the staging endpoint (`https://staging.gauthierfitness.fr/api/stripe/webhook`)
with Stripe's global event log: only `payment_intent.succeeded` appeared among the events actually sent to that
endpoint. The staging webhook endpoint simply **wasn't configured to listen** for `payment_intent.payment_failed`
— Stripe generates the event but never forwards it to the application if the event type isn't selected on the
destination. The application code was therefore never at fault: it handles this event correctly as soon as it
receives it.

**Fix applied**
Added `payment_intent.payment_failed` to the list of events listened to by the staging webhook destination
(Stripe Dashboard → Webhooks → endpoint → Edit destination). Cross-check: the **production** endpoint was already
correctly listening to both events (`payment_intent.succeeded` + `payment_intent.payment_failed`) - production
was not affected by this issue.

**Validation**
Replayed the PAY-12 scenario (declined card) after the fix: the `payment_intent.payment_failed` event is now sent
to the staging endpoint (200 OK), and the order correctly moves to `failed` status in the back-office — confirmed
by Charles after retesting.

**Lesson learned**
The configuration of events listened to by a Stripe webhook isn't versioned (it lives only in the Stripe
Dashboard), unlike the code that processes it - a silent gap can therefore exist between environments without any
automated test catching it, since the PHPUnit tests simulate the webhook call directly rather than depending on
the real Stripe config. Only manually running the PAY-12 scenario (which was precisely planned in the recette
test book) allowed this to be caught before the final production release.

---

## Report 7: Missing `.env.docker.example`, `docker compose up` fails on a fresh clone

**Context**
- Environment: local (startup test on a freshly downloaded zip, outside normal dev usage)
- Repo / commits: `backend`, `2715877`/`7831340` (2026-07-08); `gauthierfitness` (meta-repo), `c4ebeeb`/`b8fff28`
- Logged as a real GitHub issue: [`gauthierfitness-backend#79`](https://github.com/CharlesGAUTHIER1999/gauthierfitness-backend/issues/79)
  (opened then closed on 2026-07-08, via the `.github/ISSUE_TEMPLATE/bug_report.md` template)
- Severity: **S2 - Major** (one of the two documented startup paths was blocking, no workaround without reading
  the code)

**Steps to reproduce**
1. Clone `gauthierfitness-backend` fresh (or extract the submission zip
   `scripts/build-release-zip.ps1 -Ref v1.0.0`).
2. Follow the README § "Docker (optional)": `cp .env.example .env` then `docker compose up -d`.
3. The command fails immediately.

**Expected behavior**
`docker compose up -d` starts the 3 containers (`app`, `nginx`, `db`) without error, as documented in the README.

**Observed behavior**
`env file .../backend/.env.docker not found`. `docker-compose.yml` references `.env.docker` as the `env_file` for
the `app` service, but this file only exists locally on the author's machine (gitignored via `.env.*`), and no
`.env.docker.example` was provided to regenerate it on a fresh clone. The workaround documented in
`docs/02-deployment.md` (`cp .env.example .env.docker`) would have failed at actual startup anyway:
`.env.example` sets `DB_HOST=127.0.0.1`, whereas from within the `app` container the database must be reached via
the Docker service name `db`.

**User impact**
Blocks any jury member/evaluator or new developer following the README to the letter to start the app via Docker
on a 100% fresh clone.

**Analysis / root cause**
`.env` has its `.env.example` versioned, but `.env.docker` had no equivalent — an oversight when local Docker
Compose was set up, never caught because a genuinely fresh clone had never been tested.

**Fix applied**
Created `backend/.env.docker.example` (placeholders, `DB_HOST=db`) + added an exception in `.gitignore`
(`!.env.docker.example`). Backend README and `docs/02-deployment.md` (meta-repo) updated with the correct
command.

**Validation**
Verified end to end on a freshly extracted `v1.0.0` zip: `docker compose up -d` → `migrate --seed` →
`storage:link` → `GET /api/health` → `200 {"status":"ok"}`. Fix pushed to `main` without re-cutting a tag (the
main, Docker-free startup path was already verified working, the Docker section remaining explicitly
"optional").

---

## Report 8: Overly restrictive CSP, 3D configurator shows a blank page in production

**Context**
- Environment: Production **and** staging (`gauthierfitness.fr` / `staging.gauthierfitness.fr`)
- Repo / files: `infra/nginx/prod.conf` + `staging.conf`,
  `frontend/src/features/customization/components/CustomizationCanvas3D.jsx`
- Found via: authenticated Lighthouse audit on the `/products/:slug/customize` page (never audited until then —
  only the Home page had been)
- Severity: **S1 - Critical** (the product's flagship feature completely unusable in production)

**Steps to reproduce**
1. Log in and navigate to the customization page of a customizable product (e.g.
   `/products/hommes-tshirts-t-shirt-training-211/customize`).
2. Observe the browser console and the page rendering.

**Expected behavior**
The 3D configurator (Three.js) loads: garment model shown with studio lighting, texture, customizable zones.

**Observed behavior**
Blank page. Lighthouse Performance score = **0/100** on this page (vs. 99/100 on Home). Console:
```
CompileError: WebAssembly.instantiate(): violates CSP — 'unsafe-eval' not allowed in script-src
Refused to connect to 'blob:https://gauthierfitness.fr/...' — connect-src does not list blob:
Refused to connect to 'https://raw.githack.com/pmndrs/drei-assets/.../studio_small_03_1k.hdr' — domain missing from connect-src
THREE.WebGLRenderer: Context Lost.
```

**User impact**
The product's core feature (2D/3D customization with AI generation) completely unreachable for any user in
production and staging.

**Analysis / root cause**
The hardened CSP policy (added to cover OWASP Top 10 / A05, cf. security report) allowed
`script-src 'self' https://js.stripe.com` and `connect-src 'self' https://api.stripe.com https://*.sentry.io ...`,
without anticipating three needs of the Three.js pipeline:
1. The WASM decoder (Draco/Meshopt) used by `GLTFLoader` to load the compressed mesh requires WebAssembly
   compilation, blocked without a dedicated directive.
2. `GLTFLoader` loads textures via client-created `blob:` URLs (fetch), not covered by `connect-src 'self'`.
3. The `<Stage environment="studio">` component (`@react-three/drei`) fetches an HDR environment texture by
   default from a third-party CDN (`raw.githack.com`), never whitelisted.
This bug had never been caught because the recette test book (SEC-01/SEC-02) only checked for the CSP header's
**presence**, not its functional impact on the pages that depend on it most - and no Lighthouse audit had yet
targeted the configurator page.

**Fix applied**
- **Removed the external dependency** rather than widening the CSP: the HDR file is now self-hosted
  (`frontend/public/hdri/studio_small_03_1k.hdr`, 1.6 MB), `environment="studio"` replaced with
  `environment={{ files: "/hdri/studio_small_03_1k.hdr" }}` — served from `'self'`, no extra CSP rule needed for
  this point.
- CSP `script-src`: added `'wasm-unsafe-eval'` (a scoped WebAssembly directive, deliberately preferred over
  `'unsafe-eval'`, which would also have allowed arbitrary `eval()`/`Function()` calls — a much larger XSS attack
  surface).
- CSP `connect-src` and `img-src`: added `blob:`.
- Commits: `frontend` `5d4eb20`/`f3066b1`, `infra` `940b762`/`2504e06`.

**Deployment**
Staging (`workflow_dispatch`, infra run #28971976887) then production (`workflow_dispatch` with a manual approval
gate on the GitHub "Production" environment, run #28973278625) on 2026-07-08.

**Validation**
Authenticated Lighthouse audit replayed on the configurator page after deployment:

|                | Before fix                   | After fix |
|----------------|------------------------------|-----------|
| Performance    | **0** (blank page)           | **66**    |
| Accessibility  | 93                           | 94        |
| Best practices | 92                           | **100**   |
| SEO            | 100                          | 100       |
| Console errors | 6+ (CSP, WebGL context lost) | **0**     |

Before/after screenshots in `lighthouse/4-prod-configurateur-avant-fix-csp-page-blanche.png` and
`lighthouse/4-prod-configurateur-apres-fix-csp.report.html`.

---

## Report 9: AI generation timeout (`Maximum execution time of 30 seconds exceeded`) on `/api/ai/designs/generate`

**Context**
- Environment: local (first detected 2026-06-27), later confirmed in staging/production
- Repo / files: `backend/app/Http/Controllers/AI/AIDesignController.php`,
  `frontend/src/features/customization/services/customizationService.js`,
  `infra/nginx/{nginx.conf,prod.conf,staging.conf}`
- Found via: Sentry (`PHP-LARAVEL-3`, 4 occurrences, status "Ongoing")
- Severity: **S2 - Major** (AI generation systematically fails past a certain delay, without making the rest of
  the site unavailable)

**Steps to reproduce**
1. Start an AI design generation (`POST /api/ai/designs/generate`) with a prompt that takes a while to process
   (OpenAI moderation + `gpt-image-1` call).
2. If processing exceeds 30 seconds, PHP kills the request:
   `Symfony\Component\ErrorHandler\Error\FatalError: Maximum execution time of 30 seconds exceeded`.

**Expected behavior**
AI generation, whose real observed duration is 20 to 40 seconds (moderation + provider call), completes normally
without a timeout, regardless of the layer (PHP, nginx proxy, frontend HTTP client).

**Observed behavior**
Fatal error reported by Sentry on the `/api/ai/designs/generate` transaction, with the stack trace pointing to
`vendor/guzzlehttp/guzzle/src/Handler/CurlFactory.php` — the outgoing request to the OpenAI moderation/generation
API hadn't finished before PHP's default execution time limit (30 seconds) expired. Sentry breadcrumbs confirm
the exact sequence: SQL query on the product, then an HTTP call to `https://api.openai.com/v1/moderations`, then
the timeout before processing finished.

**User impact**
Silent failure of AI generation in the configurator for any request whose processing exceeds the actually
available delay — a differentiating product feature made intermittent with no explicit error message for the
user at the time of first detection.

**Analysis / root cause**
An earlier fix (before this report) had aligned two of the three layers with the real processing duration:
`set_time_limit(180)` on the controller side (`AIDesignController.php:43`) and `{timeout: 180000}` on the
dedicated Axios call (`customizationService.js:73`). But while auditing the entire HTTP chain to write this
report, the `fastcgi_read_timeout` of the three nginx files (`nginx.conf`, `prod.conf`, `staging.conf`) had stayed
at its default value of **120 seconds** — lower than the 180 seconds now allowed by PHP and the frontend.
Concretely, nginx would have cut the connection between the client and PHP-FPM before either of those two layers
reached their own limit, for any generation whose processing fell between 120 and 180 seconds: the initial fix
was therefore incomplete, and this went undetected because the three layers had never been audited together.

**Fix applied**
`fastcgi_read_timeout` raised from 120 to **200 seconds** across the 8 relevant `location` blocks in the three
nginx files (`nginx.conf`: local/dev; `prod.conf`: same-origin API + `api.gauthierfitness.fr` subdomain;
`staging.conf`: same-origin API + `api-staging.gauthierfitness.fr` subdomain), to give a 20-second margin above
the PHP/frontend limit rather than a strict match at 180. Additional check: the outgoing HTTP call to the OpenAI
images API (`OpenAIImageService::generate()`) has its own Guzzle timeout of 120 seconds, deliberately shorter than
the other three layers — it's meant to be the limit that fires first in case of abnormal provider slowness, since
it's caught by a dedicated `catch` and returns a clean 503 JSON response (`AiServiceUnavailableException`), rather
than letting nginx or PHP abruptly cut the connection. This timeout was therefore left unchanged.

**Validation**
Nginx fix deployed to staging (`Deploy Pipeline` workflow, success) then to production after the `develop` →
`main` PR and the manual approval gate (run on 2026-07-09, success, `/api/health` 200 on both environments). The
manual generation test on staging first revealed an unrelated issue, unconnected to the timeout: a systematic 503
error caused by a stale `OPENAI_API_KEY` in the VPS's `.env`, diagnosed via Sentry then fixed (updated `.env` +
`docker compose up -d --force-recreate backend` + `php artisan config:cache`, required because Docker doesn't
reload an `env_file` on a plain `restart`). Once that issue was fixed, a real generation with a deliberately
detailed prompt completed without error end to end on staging (design generated, applied to the product in the 3D
configurator).

Screenshots in `preuves_recettes/`: `sentrybackend-1.png` (Sentry issue overview, 4 events), `sentrybackend-2.png`
(breadcrumbs: OpenAI moderation then timeout), `sentrybackend-4.png` (Sentry alert email).

---

## Report 10: SSH key path broken by a hidden major bump in `appleboy/scp-action` (v0.1.7 → v1.0.0)

**Context**
- Environment: CI/CD (GitHub Actions, staging and production deploy workflow)
- Repo / commits: `infra`, `144ce85` (2026-07-13)
- Severity: **S1 - Critical** (blocks every deployment, staging and production alike)

**Steps to reproduce**
1. A Dependabot grouped update bumps the `github-actions` dependencies (7 updates bundled in a single PR),
   including `appleboy/scp-action` going from `v0.1.7` to `v1.0.0` — a major version bump hidden inside what
   looked like a routine grouped update.
2. Merge the PR, then trigger `deploy.yml` (staging or production).
3. The SCP step fails with `ssh: unable to authenticate`.

**Expected behavior**
`deploy.yml` copies `docker-compose.yml`/`nginx/`/scripts to the VPS over SCP using the SSH key written to
`runner.temp`, without error.

**Observed behavior**
SSH authentication failure on both the staging and production SCP steps, blocking every deployment.

**Analysis / root cause**
`deploy.yml` hardcoded `key_path: /github/runner_temp/{staging,prod}_key` for the `appleboy/scp-action` step.
Version `v1.0.0` of that action changed its internal handling of the temp directory, invalidating this hardcoded
path — while the neighboring `appleboy/ssh-action` step in the same workflow already correctly used the dynamic
`${{ runner.temp }}` expression instead of a hardcoded path.

**Fix applied**
Replaced the hardcoded path with `${{ runner.temp }}/{staging,prod}_key` on both the staging and production SCP
steps, matching what the working `ssh-action` step already did.

**Validation**
Verified via a real staging deployment plus the full Cypress E2E suite, both green.

**Lesson learned**
A Dependabot "grouped update" can bundle a major version bump for one dependency inside what otherwise looks like
a routine minor/patch batch — the PR diff for the workflow file itself showed no red flag, only the version
number buried in `package`/action references. Worth spot-checking each action's own changelog for major bumps
before merging a grouped GitHub Actions update, rather than trusting CI green alone (this one broke deployment,
not the CI checks that ran on the PR itself).

---

## Report 11: Missing `issues: write` permission silently failing the ZAP baseline scan job

**Context**
- Environment: CI/CD (GitHub Actions, `security-scan.yml`, ZAP Baseline Scan against staging)
- Repo / commit: `infra`, `4744642` (2026-07-13)
- Severity: **S3 - Minor** (CI job noise / false alarm — no actual vulnerability was ever at play)

**Steps to reproduce**
1. Trigger the ZAP Baseline Scan job (`security-scan.yml`) against staging.
2. The scan itself completes with `FAIL-NEW: 0` (no new blocking findings, only minor `WARN-NEW` items such as
   CSP/Permissions-Policy headers to harden).
3. Despite the clean scan result, the job as a whole is reported as failed.

**Expected behavior**
The job succeeds whenever the ZAP scan itself finds no blocking (`FAIL-NEW`) vulnerabilities.

**Observed behavior**
The job failed almost systematically, which at first glance looked like a security problem rather than a CI
plumbing issue.

**Analysis / root cause**
`zaproxy/action-baseline` tries to file a summary GitHub Issue with the scan results. That call requires
`issues: write` on the job's `GITHUB_TOKEN`. The job had no explicit `permissions` block (falling back to the
repo's restricted default), so the issue-creation API call returned a 403
(`Resource not accessible by integration`), failing the whole job — entirely unrelated to what the scan actually
found.

**Fix applied**
Added an explicit `permissions: {contents: read, issues: write}` block to the job in `security-scan.yml`.

**Validation**
Manually triggered a run on `develop` before merging: success, and the summary GitHub Issue ("ZAP Scan Baseline
Report") was actually created.

**Lesson learned**
A red CI job doesn't automatically mean a real vulnerability — worth checking the actual scan output
(`FAIL-NEW`/`WARN-NEW`) before assuming the worst. What looked like an alarming, systematically-failing security
scan was really an S3 permissions/plumbing gap, not a finding about the application itself.

---

## Report 12: Blocklist bypass via character substitution, and no dedicated weapon detection on uploaded images

**Context**
- Environment: Production and staging (both confirmed affected)
- Repo / files: `backend/app/Services/AI/PromptBlocklist.php`, `backend/app/Services/AI/OpenAIModerationService.php`,
  `backend/app/Http/Controllers/Customization/CustomizationAssetController.php`
- Found via: manual testing of the customization guard rails on the live configurator
- Severity: **S1 - Critical** (illegal/hateful content could be printed on a physical product sold to the public)

**Steps to reproduce**
1. In the customizer, enter `H!TLER` in the player name field (or any blocklisted term with a digit/symbol
   substituted for a letter) and submit → accepted instead of rejected.
2. Upload a neutral photo of a firearm as a free image/logo → accepted instead of rejected.

**Expected behavior**
Both inputs should be rejected by the existing content-moderation guard rails, the same way a plain blocklisted
word or an explicitly graphic image already is.

**Observed behavior**
1. `PromptBlocklist::matches()` normalizes case and accents (`Str::ascii`) before comparing against the blocklist,
   but not common leetspeak substitutions - `H!TLER` normalizes to `h!tler`, which doesn't match the `\bhitler\b`
   word-boundary regex.
2. The existing image moderation only calls OpenAI's standard `/v1/moderations` endpoint, whose categories
   (sexual, hate, graphic violence, self-harm, illicit) don't include "depicts a weapon" as such - a neutral,
   non-violent photo of a firearm scores near-zero on every category and is never flagged.

**Analysis / root cause**
Both guard rails were built to catch what their respective classifiers are actually designed to catch (exact
blocklisted words; OpenAI's fixed moderation categories), but neither was hardened against a determined user
deliberately working around the classifier itself - a text obfuscation technique in one case, a content category
gap in the other.

**Fix applied**
1. `PromptBlocklist::normalize()`: added a leetspeak substitution map (`0→o, 1→i, 3→e, 4→a, 5→s, 7→t, @→a, $→s,
   !→i, |→i`) applied to both the input text and the blocklist terms before the word-boundary match.
2. `OpenAIModerationService::detectProhibitedVisualContent()`: added a second, independent moderation pass using
   a vision-capable chat model (`gpt-4o-mini`) with a dedicated classification prompt (weapons/firearms, illegal
   drugs, extremist/hate symbols), run in addition to the standard categorical moderation on every logo/image
   upload.

**Validation**
Dedicated unit test (`PromptBlocklistTest::test_detects_leetspeak_character_substitution`) and two Feature tests
(`CustomizationAssetTest::test_logo_upload_rejects_prohibited_visual_content` /
`test_image_upload_rejects_prohibited_visual_content`), full suite replayed (200/200 backend tests green). Both
original bypasses retested manually in the browser after the fix: both now rejected with an explicit message
before the item can be added to the cart.

**Lesson learned**
A content-moderation guard rail is only as strong as what its classifier was actually built to detect - a
whole-word blocklist doesn't survive basic obfuscation, and a general-purpose moderation API doesn't necessarily
cover every category a specific business considers unacceptable. Worth periodically testing guard rails
adversarially (trying to break them on purpose), not just confirming they fire on the exact input they were
designed for.

---

## Note: `guest_token` column not found (likely already-resolved leftover)

Two related Sentry errors (`Illuminate\Database\QueryException` — `guest_token` column not found on
`/api/cart/items`, and `Cannot drop index 'carts_user_id_unique'` during a local migration), dated 2026-07-02/03,
coincide exactly with the creation of the `2026_07_02_213224_make_carts_guest_capable.php` migration. This
migration already contains the exact fix for the second error (explicit comment: *"MySQL requires dropping the FK
before dropping the unique index backing it"*), and the `GuestCartTest` suite (7 tests, including usage of
`guest_token`) is now fully green. Conclusion: most likely residual events from the migration's authoring phase
(before it was run/fixed on the affected environment), not a still-active issue. No new fix needed — worth
mentioning in the recette test book as an anomaly detected then resolved (C4.2.1) rather than silently ignored.
