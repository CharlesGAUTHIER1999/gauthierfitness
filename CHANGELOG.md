# Changelog

Toutes les évolutions notables du meta-repo GauthierFitness (documentation transverse, preuves de recette, rendus
RNCP) sont documentées ici.

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

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
