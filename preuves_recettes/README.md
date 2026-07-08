# Preuves de recette

Captures d'écran et vidéos à l'appui du cahier de recettes (voir `rendusrncp/cahier_recettes.xlsx`).

## Modération et génération IA (customisation produit)

| Fichier | Contenu |
|---|---|
| `ia-moderation-4-niveaux-schema.png` | Schéma récapitulatif des 4 niveaux de modération (blocklist, prompt OpenAI, sécurité native gpt-image-1, image générée) — **synthèse explicative, pas une capture de l'application** |
| `ia-blocklist-rejet-frontend.png` | Rejet immédiat côté front par la blocklist locale (prompt "arme de destruction massive") |
| `ia-moderation-texte-ok-backend-1.png` / `-2.png` | `OpenAIModerationService::moderateText()` sur un prompt propre → `flagged: false` |
| `ia-moderation-texte-rejet-backend-1.png` / `-2.png` | `OpenAIModerationService::moderateText()` sur un prompt interdit → `flagged: true` (illicit/violence) |
| `ia-moderation-rejet-frontend-2.png` | Message de rejet affiché côté front pour une demande hors règles (prompt "contenu explicite +18") |
| `ia-generation-image-ok-backend.png` | `OpenAIImageService::generate()` réussi côté backend (tinker) |
| `ia-generation-succes-frontend-aigle-training.png` | Génération réussie d'un aigle stylisé sur T-shirt Training |
| `ia-generation-succes-logo-bouclier.png` | Génération réussie d'un logo bouclier/aigle sur T-shirt Oversize |
| `ia-generation-succes-ours.png` | Génération réussie d'un petit ours sur T-shirt Oversize |
| `ia-generation-service-indisponible.png` | Cas d'erreur : service de génération IA temporairement indisponible |

## Monitoring Sentry

| Fichier | Contenu |
|---|---|
| `sentry-test-backend-erreur-ignition.png` | Page d'erreur Laravel (route `/debug-sentry`) déclenchant l'exception de test |
| `sentry-test-backend-dashboard.png` | Issue correspondante capturée dans le dashboard Sentry |
| `erreursentryfront-1.png` | Issue Sentry frontend (test) dans le dashboard |
| `erreursentryfront-2.png` | Erreur de test capturée dans la console navigateur |
| `sentrybackend-1.png`, `-2.png`, `-4.png` | Incident réel : timeout `/api/ai/designs/generate` (30s dépassées) — **pas encore de fiche dédiée dans `FICHES_INCIDENTS.md`, à ajouter** |
| `sentrybackend-3.png` | Incident réel distinct : `Class "Redis" not found` — Fiche 5 de `rendusrncp/FICHES_INCIDENTS.md` |

## Tests, pipeline, accessibilité, paiement

| Fichier | Contenu |
|---|---|
| `backendtests-1.png` / `-2.png` | Suite de tests backend (PHPUnit) |
| `frontendtests-1.png` | Suite de tests frontend (Jest) |
| `tests-1.png` / `-2.png` | Couverture de code backend par fichier (`php artisan test --coverage`, total 79.8 %) |
| `pipeline-1.png` … `-3.png` | Pipeline CI/CD (GitHub Actions) |
| `A11Y-01.png` / `A11Y-01.mp4` | Démonstration accessibilité (navigation clavier/lecteur d'écran) |
| `uptime-1.png` | Supervision de disponibilité |
| `payment-success-1.png` … `-4.png` | Parcours de paiement Stripe réussi |
| `payment-failed-1.png` … `-3.png` | Parcours de paiement Stripe en échec |

## Clôture du cahier de recettes (94 → 95 scénarios, 08-09/07/2026)

| Fichier | Contenu |
|---|---|
| `auth03-adm03-adm07-adm11-backend-tests.png` | AUTH-03, ADM-03, ADM-07, ADM-11 : tests PHPUnit ciblés (Admin + Auth), rejoués le 08/07/2026 |
| `ui06-protectedroute-test.png` | UI-06 : `ProtectedRoute.test.jsx` (3/3), rejoué le 08/07/2026 |
| `sec01-sec02-headers-hsts-csp-prod.png` | SEC-01, SEC-02 : headers HSTS et CSP vérifiés en direct sur `gauthierfitness.fr` |
| `infra02-ci-backend-pr.png` | INFRA-02 : CI backend verte sur pull request (GitHub Actions) |
| `infra03-ci-frontend-pr.png` | INFRA-03 : CI frontend verte sur pull request (GitHub Actions) |
| `infra04-pipeline-staging-e2e.png` | INFRA-04 : pipeline staging + E2E Cypress verts (GitHub Actions) |
| `infra05-pipeline-production.png` | INFRA-05 : déploiement production avec gate d'approbation manuelle validé (GitHub Actions) |
