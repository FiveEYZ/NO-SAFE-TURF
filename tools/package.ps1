$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
& node (Join-Path $PSScriptRoot 'build-update.js')
if ($LASTEXITCODE -ne 0) { throw 'Update bundle build failed.' }
$releaseName = 'no-safe-turf-0.7.2-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$releaseRoot = Join-Path $projectRoot ('dist/' + $releaseName)
New-Item -ItemType Directory -Path $releaseRoot | Out-Null
function Copy-ReleaseFile([string]$relative) {
    $source = Join-Path $projectRoot $relative
    $target = Join-Path $releaseRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath $source -Destination $target
}
foreach ($relative in @('README.md','LICENSE','AGENTS.md','package.json','package-lock.json','recipe.yaml','server.example.cfg','secrets.example.cfg','deploy/recipe-server.cfg','deploy/txadmin-resource.cfg','deploy/mariadb.example.json','tools/database.js','database/mariadb/000_recipe_preflight.sql','database/mariadb/001_initial.sql')) {
    Copy-ReleaseFile $relative
}
foreach ($directory in @('resource','database_config','updater','docs','tests','tools')) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot $directory) -File -Recurse) {
        if ($file.Name -match '\.private\.|\.py[c]?$|^\.env$|\.backup\.json(?:\.pending)?$') { continue }
        if ($directory -eq 'docs' -and $file.Name -eq 'promt.md') { continue } # Preserve the user's Swedish prompt locally, not in English delivery.
        if ($directory -eq 'updater' -and $file.Extension -notin @('.js','.lua')) { continue }
        if ($directory -eq 'resource') {
            $relativeResource = [IO.Path]::GetRelativePath((Join-Path $projectRoot 'resource'),$file.FullName).Replace('\','/')
            if ($relativeResource -notmatch '^((client|server|shared)/.*\.(lua|js)$|web/.*\.(html|css|js)$|node_modules/|update-state\.json$|fxmanifest\.lua$|package(?:-lock)?\.json$)') { continue }
        }
        Copy-ReleaseFile ([IO.Path]::GetRelativePath($projectRoot,$file.FullName))
    }
}
if (!(Test-Path -LiteralPath (Join-Path $releaseRoot 'resource/node_modules/mysql2/promise.js'))) { throw 'Install resource dependencies before packaging.' }
$privatePath = Join-Path $projectRoot 'deploy/mariadb.private.json'
if (Test-Path -LiteralPath $privatePath) {
    $privateConfig = Get-Content -LiteralPath $privatePath -Raw | ConvertFrom-Json
    foreach ($file in Get-ChildItem -LiteralPath $releaseRoot -File -Recurse) {
        if ([IO.File]::ReadAllText($file.FullName).Contains([string]$privateConfig.password)) { throw 'Private credential detected; package refused.' }
    }
}
$archive = $releaseRoot + '.zip'
Compress-Archive -LiteralPath $releaseRoot -DestinationPath $archive
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    if ($zip.Entries.FullName -match '\.private\.|\.py[c]?$|/service/|\.backup\.json') { throw 'Excluded content detected in archive.' }
    Write-Output ('Verified archive entries: ' + $zip.Entries.Count)
} finally { $zip.Dispose() }
Get-FileHash -LiteralPath $archive -Algorithm SHA256 | Select-Object Path,Hash
$recipeArchive = Join-Path $projectRoot 'dist/no-safe-turf-txadmin.zip'
Compress-Archive -Path (Join-Path $releaseRoot '*') -DestinationPath $recipeArchive -Force
$zip = [IO.Compression.ZipFile]::OpenRead($recipeArchive)
try {
    foreach ($required in @('resource/fxmanifest.lua','database_config/fxmanifest.lua','resource/node_modules/mysql2/promise.js','database/mariadb/000_recipe_preflight.sql','database/mariadb/001_initial.sql','deploy/recipe-server.cfg')) {
        if (!($zip.Entries | Where-Object { $_.FullName.Replace('\','/') -eq $required })) { throw ('Missing recipe path: '+$required) }
    }
    if ($zip.Entries.FullName -match '\.private\.|\.py[c]?$|/service/|\.backup\.json') { throw 'Excluded content detected in recipe archive.' }
    Write-Output ('Verified recipe archive: '+$recipeArchive)
} finally { $zip.Dispose() }
