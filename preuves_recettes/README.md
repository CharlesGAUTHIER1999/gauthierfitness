# Preuves de recette

Captures d'écran et vidéos à l'appui du cahier de recettes (voir `rendusrncp/CAHIER_RECETTES_BLOC2.xlsx`).

## Modération et génération IA (customisation produit)

| Fichier | Contenu |
|---|---|
| `ia-moderation-4-niveaux.png` | Récapitulatif des 4 niveaux de modération (blocklist, prompt OpenAI, sécurité native gpt-image-1, image générée) |
| `ia-blocklist-rejet-frontend.png` | Rejet immédiat côté front par la blocklist locale (prompt "arme de destruction massive") |
| `ia-moderation-texte-ok-backend-1.png` / `-2.png` | `OpenAIModerationService::moderateText()` sur un prompt propre → `flagged: false` |
| `ia-moderation-texte-rejet-backend-1.png` / `-2.png` | `OpenAIModerationService::moderateText()` sur un prompt interdit → `flagged: true` (illicit/violence) |
| `ia-moderation-rejet-frontend.png` | Message de rejet affiché côté front pour une demande hors règles |
| `ia-generation-image-ok-backend.png` | `OpenAIImageService::generate()` réussi côté backend (tinker) |
| `ia-generation-succes-frontend-logo.png` | Génération réussie d'un logo (bouclier/aigle) sur T-shirt Oversize |
| `ia-generation-succes-frontend-aigle-training.png` | Génération réussie d'un aigle stylisé sur T-shirt Training |
| `ia-generation-succes-logo-bouclier.png` | Autre génération réussie (logo bouclier) sur T-shirt Oversize |
| `ia-generation-succes-ours.png` | Génération réussie d'un petit ours sur T-shirt Oversize |
| `ia-generation-service-indisponible.png` | Cas d'erreur : service de génération IA temporairement indisponible |

## Monitoring Sentry

| Fichier | Contenu |
|---|---|
| `sentry-test-backend-erreur-ignition.png` | Page d'erreur Laravel (route `/debug-sentry`) déclenchant l'exception de test |
| `sentry-test-backend-dashboard.png` | Issue correspondante capturée dans le dashboard Sentry |
| `erreursentryfront-1.png` | Issue Sentry frontend (test) dans le dashboard |
| `erreursentryfront-2.png` | Erreur de test capturée dans la console navigateur |
| `sentrybackend-1.png` … `sentrybackend-4.png` | Incident réel : timeout `/api/ai/designs/generate` (cf. `rendusrncp/FICHES_INCIDENTS.md`) |

## Tests, pipeline, accessibilité, paiement

| Fichier | Contenu |
|---|---|
| `backendtests-1.png` / `-2.png` | Suite de tests backend (PHPUnit) |
| `frontendtests-1.png` | Suite de tests frontend (Jest) |
| `tests-1.png` / `-2.png` | Résultats de tests complémentaires |
| `pipeline-1.png` … `-3.png` | Pipeline CI/CD (GitHub Actions) |
| `A11Y-01.png` / `A11Y-01.mp4` | Démonstration accessibilité (navigation clavier/lecteur d'écran) |
| `uptime-1.png` | Supervision de disponibilité |
| `payment-success-1.png` … `-4.png` | Parcours de paiement Stripe réussi |
| `payment-failed-1.png` … `-3.png` | Parcours de paiement Stripe en échec |
