# Recette Proofs

Screenshots and videos supporting the recette test book (see `rendusrncp/cahier_recettes.xlsx`).

## Moderation and AI generation (product customization)

| File                                                 | Content                                                                                                                                                                               |
|------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `ia-moderation-4-niveaux-schema.png`                 | Summary diagram of the 4 moderation layers (blocklist, OpenAI prompt moderation, gpt-image-1 native safety, generated image) — **explanatory summary, not an application screenshot** |
| `ia-blocklist-rejet-frontend.png`                    | Immediate rejection on the front end by the local blocklist (prompt "weapon of mass destruction")                                                                                     |
| `ia-moderation-texte-ok-backend-1.png` / `-2.png`    | `OpenAIModerationService::moderateText()` on a clean prompt → `flagged: false`                                                                                                        |
| `ia-moderation-texte-rejet-backend-1.png` / `-2.png` | `OpenAIModerationService::moderateText()` on a forbidden prompt → `flagged: true` (illicit/violence)                                                                                  |
| `ia-moderation-rejet-frontend-2.png`                 | Rejection message shown on the front end for an out-of-policy request (prompt "explicit +18 content")                                                                                 |
| `ia-generation-image-ok-backend.png`                 | Successful `OpenAIImageService::generate()` on the backend (tinker)                                                                                                                   |
| `ia-generation-succes-frontend-aigle-training.png`   | Successful generation of a stylized eagle on the Training T-shirt                                                                                                                     |
| `ia-generation-succes-logo-bouclier.png`             | Successful generation of a shield/eagle logo on the Oversize T-shirt                                                                                                                  |
| `ia-generation-succes-ours.png`                      | Successful generation of a small bear on the Oversize T-shirt                                                                                                                         |
| `ia-generation-service-indisponible.png`             | Error case: AI generation service temporarily unavailable                                                                                                                             |

## Sentry monitoring

| File                                      | Content                                                                                                                              |
|-------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| `sentry-test-backend-erreur-ignition.png` | Laravel error page (`/debug-sentry` route) triggering the test exception                                                             |
| `sentry-test-backend-dashboard.png`       | Corresponding issue captured in the Sentry dashboard                                                                                 |
| `erreursentryfront-1.png`                 | Frontend Sentry issue (test) in the dashboard                                                                                        |
| `erreursentryfront-2.png`                 | Test error captured in the browser console                                                                                           |
| `sentrybackend-1.png`, `-2.png`, `-4.png` | Real incident: `/api/ai/designs/generate` timeout (30s exceeded) — **no dedicated report in `FICHES_INCIDENTS.md` yet, to be added** |
| `sentrybackend-3.png`                     | Separate real incident: `Class "Redis" not found` - Report 5 in `rendusrncp/FICHES_INCIDENTS.md`                                     |

## Tests, pipeline, accessibility, payment

| File                               | Content                                                                    |
|------------------------------------|----------------------------------------------------------------------------|
| `backendtests-1.png` / `-2.png`    | Backend test suite (PHPUnit, 200 passed)                                   |
| `frontendtests.png`                | Frontend test suite (Jest, 40 passed)                                      |
| `tests-coverage.png`               | Backend code coverage by file (`php artisan test --coverage`, total 84.1%) |
| `pipeline-1.png` … `-3.png`        | CI/CD pipeline (GitHub Actions)                                            |
| `A11Y-01.png` / `A11Y-01.mp4`      | Accessibility demonstration (keyboard navigation/screen reader)            |
| `uptime-1.png`                     | Uptime monitoring                                                          |
| `payment-success-1.png` … `-4.png` | Successful Stripe payment journey                                          |
| `payment-failed-1.png` … `-3.png`  | Failed Stripe payment journey                                              |

## Infra, security and tests

| File                                         | Content                                                                                        |
|----------------------------------------------|------------------------------------------------------------------------------------------------|
| `auth03-adm03-adm07-adm11-backend-tests.png` | AUTH-03, ADM-03, ADM-07, ADM-11: targeted PHPUnit tests (Admin + Auth), replayed on 08/07/2026 |
| `ui06-protectedroute-test.png`               | UI-06: `ProtectedRoute.test.jsx` (3/3), replayed on 08/07/2026                                 |
| `sec01-sec02-headers-hsts-csp-prod.png`      | SEC-01, SEC-02: HSTS and CSP headers verified live on `gauthierfitness.fr`                     |
| `infra02-ci-backend-pr.png`                  | INFRA-02: backend CI green on pull request (GitHub Actions)                                    |
| `infra03-ci-frontend-pr.png`                 | INFRA-03: frontend CI green on pull request (GitHub Actions)                                   |
| `infra04-pipeline-staging-e2e.png`           | INFRA-04: staging pipeline + Cypress E2E green (GitHub Actions)                                |
| `infra05-pipeline-production.png`            | INFRA-05: production deployment with manual approval gate validated (GitHub Actions)           |

## Closing out the recette test book, second pass (96 → 100 scenarios, 21/07/2026)

Four new Customization scenarios, found and closed during a manual browser walkthrough of the guard rails
(player number format, text blocklist, upload moderation, blocklist evasion) that had automated test coverage
but no recette entry yet.

| File                                  | Content                                                                                                                                                                                                                     |
|---------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `cust11-cust12-backend-tests.png`     | CUST-11, CUST-12: targeted PHPUnit tests (player number format + text blocklist), 3 passed (4 assertions)                                                                                                                   |
| `cust11-numero-invalide-frontend.png` | CUST-11: rejection message shown in the 3D configurator for a non-numeric player number ("ABC")                                                                                                                             |
| `cust12-blocklist-frontend.png`       | CUST-12: rejection message shown in the 3D configurator for a blocklisted term in the player name field                                                                                                                     |
| `cust13-backend-tests.png`            | CUST-13: targeted PHPUnit tests (logo/image upload rejected for flagged content), 2 passed (7 assertions)                                                                                                                   |
| `cust13-moderation-frontend.png`      | CUST-13: rejection message shown in the 3D configurator for an uploaded image containing prohibited visual content (weapons, drugs, hate symbols) - dedicated vision-model check added after this scenario was first closed |
| `cust14-leetspeak-backend-tests.png`  | CUST-14: `PromptBlocklistTest::test_detects_leetspeak_character_substitution` - blocklist now normalizes common character substitutions (e.g. "H!TLER") before matching                                                     |
| `cust14-leetspeak-frontend.png`       | CUST-14: rejection message shown in the 3D configurator for a blocklisted term disguised with character substitution                                                                                                        |
