[CmdletBinding()]
param(
    [string]$Path,
    [string[]]$ExpectedLanguages = @('de-DE', 'en-US', 'es-ES', 'fr-FR')
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    throw $Message
}

if (-not $Path) {
    $dist = Join-Path $PSScriptRoot '..\dist'
    $candidates = @(Get-ChildItem -LiteralPath $dist -Filter '*.appx' -File -ErrorAction SilentlyContinue)
    if ($candidates.Count -ne 1) {
        Fail "Genau eine .appx in $dist erwartet, gefunden: $($candidates.Count)."
    }
    $Path = $candidates[0].FullName
}

$Path = (Resolve-Path -LiteralPath $Path).Path
if ([IO.Path]::GetExtension($Path) -ne '.appx') {
    Fail "Erwartet wird eine .appx-Datei, erhalten: $Path"
}

$packageJsonPath = Join-Path $PSScriptRoot '..\package.json'
$storeConfigPath = Join-Path $PSScriptRoot '..\store\store.config.json'
$packageJson = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
$storeConfig = Get-Content -LiteralPath $storeConfigPath -Raw | ConvertFrom-Json

$temp = Join-Path ([IO.Path]::GetTempPath()) ('toolbox-appx-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null

try {
    # Expand-Archive erwartet eine .zip-Endung; die .appx ist technisch ein ZIP.
    $zipPath = Join-Path $temp 'package.zip'
    Copy-Item -LiteralPath $Path -Destination $zipPath
    Expand-Archive -LiteralPath $zipPath -DestinationPath $temp -Force

    $manifestPath = Join-Path $temp 'AppxManifest.xml'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        Fail 'AppxManifest.xml fehlt im Paket.'
    }

    [xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
    $ns = New-Object System.Xml.XmlNamespaceManager -ArgumentList $manifest.NameTable
    $ns.AddNamespace('appx', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')

    $identity = $manifest.SelectSingleNode('/appx:Package/appx:Identity', $ns)
    if ($null -eq $identity) {
        Fail 'Identity fehlt im AppxManifest.xml.'
    }

    $resources = @($manifest.SelectNodes('/appx:Package/appx:Resources/appx:Resource', $ns) |
        ForEach-Object { $_.GetAttribute('Language').Trim() })
    $uniqueResources = @($resources | Sort-Object -Unique)
    $expected = @($ExpectedLanguages | ForEach-Object { $_.Trim() } | Sort-Object -Unique)
    $missing = @($expected | Where-Object { $uniqueResources -notcontains $_ })
    $extra = @($uniqueResources | Where-Object { $expected -notcontains $_ })

    if ($resources.Count -ne $uniqueResources.Count) {
        Fail "Doppelte Spracheinträge im Manifest: $($resources -join ', ')"
    }
    if ($missing.Count -gt 0) {
        Fail "Fehlende Sprachen im AppX: $($missing -join ', ')"
    }
    if ($extra.Count -gt 0) {
        Fail "Unerwartete Sprachen im AppX: $($extra -join ', ')"
    }
    $identityName = $identity.GetAttribute('Name')
    $identityPublisher = $identity.GetAttribute('Publisher')
    $identityArchitecture = $identity.GetAttribute('ProcessorArchitecture')
    $identityVersion = $identity.GetAttribute('Version')

    if ($identityName -ne $storeConfig.identityName) {
        Fail "Identity.Name stimmt nicht: $identityName statt $($storeConfig.identityName)"
    }
    if ($identityPublisher -ne $storeConfig.publisher) {
        Fail "Identity.Publisher stimmt nicht: $identityPublisher statt $($storeConfig.publisher)"
    }
    if ($identityArchitecture -ne 'x64') {
        Fail "ProcessorArchitecture ist $identityArchitecture, erwartet x64."
    }
    if (-not $identityVersion.StartsWith("$($packageJson.version).")) {
        Fail "Paketversion $identityVersion passt nicht zu package.json $($packageJson.version)."
    }

    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host 'AppX-Manifest OK'
    Write-Host "  Datei: $Path"
    Write-Host "  Identity: $identityName"
    Write-Host "  Version: $identityVersion"
    Write-Host "  Architektur: $identityArchitecture"
    Write-Host "  Sprachen: $($uniqueResources -join ', ')"
    Write-Host "  SHA256: $hash"
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
