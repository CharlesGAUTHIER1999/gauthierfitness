# Changelog

All notable changes to the GauthierFitness meta-repo (cross-project documentation, recette proofs, RNCP
submissions) are documented here.

Format inspired by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [v1.0.6] - 2026-07-15

### Removed

- `.gitignore`: removed an obsolete exclusion rule referencing a local tooling folder, irrelevant to the submission zip.

## [v1.0.5] - 2026-07-13

### Fixed

- `README.md` and `docs/02-deployment.md`: the Docker quickstart (recommended path) never mentioned
  `php artisan key:generate`, unlike the Docker-free path which was already correct. `APP_KEY` stayed empty in
  `.env.docker`, breaking everything relying on encryption on a fresh install. Found while testing the submission zip
  end to end (fresh extraction + local build). See also the twin fix on `gauthierfitness-backend` (v1.0.6).

## [v1.0.4] - 2026-07-13

### Changed

- `rendusrncp/cahier_recettes.xlsx`: harmonized test counters (166 PHPUnit / 40 Jest) with the code and the Bloc 2
  dossier.
- `preuves_recettes/ui06-protectedroute-test.png` updated.

### Fixed

- `preuves_recettes/a11y-01.mp4`: file size fixed after an initial oversized replacement (92 MB → 12 MB).

## [v1.0.3] - 2026-07-12

### Added

- `rendusrncp/BLOC2_DOSSIER.docx` finalized for the RNCP submission (full proofread, cover page, table of contents
  trimmed to main headings, resized images).

### Changed

- Renamed `preuves_recettes/` to lowercase and synced the paths (`docs/05-api.md`, `FICHES_INCIDENTS.md`) after the
  backend controller reorganization.

### Removed

- Duplicates `BLOC2RNCP.docx`, `BLOC4RNCP.docx`, `BLOC4_DOSSIER.docx` (obsolete versions).

## [v1.0.2] - 2026-07-10

### Fixed

- Quickstart (README + docs/02-deployment.md): Docker becomes the recommended path for local startup, the Docker-free
  option required an undocumented local MySQL.

## [v1.0.1] - 2026-07-10

### Added

- Incident report 9 (AI generation timeout) with real-conditions validation.
- Lighthouse audit of production pages, including the CSP/3D configurator bug report.
- Scenario CONT-03 (support channel proof) and full closure of the recette test book.

### Fixed

- Corrected Docker environment setup instructions in the documentation.

### Changed

- Compressed A11Y-01.mp4 (90 MB → 3 MB, same quality).
- Synced the Bloc 2 / Bloc 4 dossiers with the recette test book and the incident count.

## [v1.0.0] - 2026-07-08

First tagged release of the meta-repo, aligned with the application's V1 (backend, frontend, infra).

### Added

- Cross-project documentation (`docs/`): architecture, deployment, user guide, upgrade, API.
- Before/after Lighthouse reports, recette proofs, recette test book.
- RNCP Bloc 2 and Bloc 4 submissions (v2): `rendusrncp/BLOC2_DOSSIER.docx`, `rendusrncp/BLOC4_DOSSIER.docx`.

### Changed

- README: HTTPS clone instructions, `storage:link` step added to the quickstart.
- Formatting cleanup (tables, headings) in `docs/README.md`, `docs/02-deployment.md`.

### Fixed

- Fixed a typo in `docs/03-user-guide.md` (checkout flow).

> The RNCP submissions (`rendusrncp/`) are at v2 at this stage. A final v3 (full proofread, screenshots) will be
> submitted separately before the deadline, with Bloc 4 removed (to be submitted separately in August).
