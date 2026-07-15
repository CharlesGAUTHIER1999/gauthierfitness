# Changelog

Toutes les évolutions notables du meta-repo GauthierFitness (documentation transverse, preuves de recette, rendus
RNCP) sont documentées ici.

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

## [v1.0.6] - 2026-07-15

### Removed
- `.gitignore` : suppression d'une règle d'exclusion obsolète référençant un dossier d'outillage local, sans intérêt pour le zip de rendu.

## [v1.0.5] - 2026-07-13

### Fixed
- `README.md` et `docs/02-deployment.md` : le quickstart Docker (chemin recommandé) ne mentionnait jamais `php artisan key:generate`, contrairement au chemin sans Docker déjà correct. `APP_KEY` restait vide dans `.env.docker`, cassant tout ce qui dépend de l'encryption sur une installation fraîche. Repéré en testant le zip de rendu de bout en bout (extraction vierge + build local). Voir aussi le correctif jumeau sur `gauthierfitness-backend` (v1.0.6).

## [v1.0.4] - 2026-07-13

### Changed
- `rendusrncp/cahier_recettes.xlsx` : harmonisation des compteurs de tests (166 PHPUnit / 40 Jest) avec le code et le dossier Bloc 2.
- `preuves_recettes/ui06-protectedroute-test.png` mise à jour.

### Fixed
- `preuves_recettes/a11y-01.mp4` : taille corrigée après un premier remplacement surdimensionné (92 Mo → 12 Mo).

## [v1.0.3] - 2026-07-12

### Added
- `rendusrncp/BLOC2_DOSSIER.docx` finalisé pour le rendu RNCP (relecture complète, page de garde, sommaire réduit aux titres principaux, images redimensionnées).

### Changed
- Renommage en minuscules de `preuves_recettes/` et synchronisation des chemins (`docs/05-api.md`, `FICHES_INCIDENTS.md`) après la réorganisation des contrôleurs backend.

### Removed
- Doublons `BLOC2RNCP.docx`, `BLOC4RNCP.docx`, `BLOC4_DOSSIER.docx` (versions obsolètes).

## [v1.0.2] - 2026-07-10

### Fixed
- Quickstart (README + docs/02-deployment.md) : Docker devient le chemin recommandé pour le démarrage local, l'option sans Docker nécessitait un MySQL local non documenté.

## [v1.0.1] - 2026-07-10

### Added
- Fiche d'incident 9 (timeout génération IA) avec validation en conditions réelles.
- Audit Lighthouse des pages de production, dont la fiche du bug CSP/configurateur 3D.
- Scénario CONT-03 (preuve du canal support) et clôture complète du cahier de recettes.

### Fixed
- Instructions de configuration de l'environnement Docker corrigées dans la documentation.

### Changed
- Compression de A11Y-01.mp4 (90 Mo -> 3 Mo, qualité équivalente).
- Synchronisation des dossiers Bloc 2 / Bloc 4 avec le cahier de recettes et le décompte d'incidents.

## [v1.0.0] - 2026-07-08

Première release taguée du meta-repo, alignée avec la V1 de l'application (backend, frontend, infra).

### Added
- Documentation transverse du projet (`docs/`) : architecture, déploiement, guide utilisateur, mise à jour, API.
- Rapports Lighthouse avant/après correctifs, preuves de recette, cahier de recettes.
- Rendus RNCP Bloc 2 et Bloc 4 (v2) : `rendusrncp/BLOC2_DOSSIER.docx`, `rendusrncp/BLOC4_DOSSIER.docx`.

### Changed
- README : instructions de clonage en HTTPS, étape `storage:link` ajoutée au démarrage rapide.
- Nettoyage de mise en forme (tableaux, titres) dans `docs/README.md`, `docs/02-deployment.md`.

### Fixed
- Correction d'une coquille dans `docs/03-user-guide.md` (parcours checkout).

> Les rendus RNCP (`rendusrncp/`) sont en v2 à ce stade. Une v3, définitive (relecture complète, captures d'écran),
> sera déposée séparément avant l'échéance, avec retrait du Bloc 4 (à rendre en août dans un dossier dédié).
