<#
.SYNOPSIS
  Assemble un zip de remise unique à partir des 4 repos publics GauthierFitness
  (meta-repo + backend + frontend + infra), clonés à neuf depuis GitHub.

.PARAMETER Ref
  Branche ou tag à cloner pour les 3 repos applicatifs (backend/frontend/infra).
  Le meta-repo est toujours cloné sur `main`.

.PARAMETER Org
  Compte/organisation GitHub hébergeant les 4 repos.

.PARAMETER OutDir
  Dossier de travail où le zip est produit (créé s'il n'existe pas, vidé s'il existe déjà).

.EXAMPLE
  ./scripts/build-release-zip.ps1 -Ref v1.0.0
#>
param(
    [string]$Ref = "main",
    [string]$Org = "CharlesGAUTHIER1999",
    [string]$OutDir = "$PSScriptRoot/../../gauthierfitness-release"
)

$ErrorActionPreference = "Stop"

if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
$staging = Join-Path $OutDir "gauthierfitness"
New-Item -ItemType Directory -Path $staging -Force | Out-Null

Write-Host "→ Clonage du meta-repo (docs, preuves de recette, rendus RNCP)..."
git clone --depth 1 --branch main "https://github.com/$Org/gauthierfitness.git" $staging

foreach ($repo in @("backend", "frontend", "infra")) {
    Write-Host "→ Clonage de gauthierfitness-$repo ($Ref)..."
    git clone --depth 1 --branch $Ref "https://github.com/$Org/gauthierfitness-$repo.git" (Join-Path $staging $repo)
    Remove-Item (Join-Path $staging "$repo/.git") -Recurse -Force
}
Remove-Item (Join-Path $staging ".git") -Recurse -Force

$zipPath = Join-Path $OutDir "gauthierfitness-$Ref.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path $staging -DestinationPath $zipPath

Write-Host ""
Write-Host "Zip de remise prêt : $zipPath"
