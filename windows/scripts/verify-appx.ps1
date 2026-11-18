[CmdletBinding()]
param(
    [string]$Path,
    [string[]]$ExpectedLanguages = @('en-US', 'de-DE', 'es-ES', 'fr-FR')
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    throw $Message
}

if (-not $Path) {
    $dist = Join-Path $PSScriptRoot '..\dist'
    $candidates = @(Get-ChildItem -LiteralPath $dist -Filter '*.appx' -File -ErrorAction SilentlyContinue)
    if ($candidates.Count -ne 1) {
        Fail "Expected exactly one .appx in $dist, found: $($candidates.Count)."
    }
    $Path = $candidates[0].FullName
}

$Path = (Resolve-Path -LiteralPath $Path).Path
if ([IO.Path]::GetExtension($Path) -ne '.appx') {
    Fail "Expected a .appx file, got: $Path"
}

$packageJsonPath = Join-Path $PSScriptRoot '..\package.json'
$storeConfigPath = Join-Path $PSScriptRoot '..\store\store.config.json'
$packageJson = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
$storeConfig = Get-Content -LiteralPath $storeConfigPath -Raw | ConvertFrom-Json

$temp = Join-Path ([IO.Path]::GetTempPath()) ('toolbox-appx-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null

try {
    # Expand-Archive expects a .zip extension; the .appx is technically a ZIP.
    $zipPath = Join-Path $temp 'package.zip'
    Copy-Item -LiteralPath $Path -Destination $zipPath
    Expand-Archive -LiteralPath $zipPath -DestinationPath $temp -Force

    $manifestPath = Join-Path $temp 'AppxManifest.xml'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        Fail 'AppxManifest.xml is missing from the package.'
    }

    [xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
    $ns = New-Object System.Xml.XmlNamespaceManager -ArgumentList $manifest.NameTable
    $ns.AddNamespace('appx', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')

    $identity = $manifest.SelectSingleNode('/appx:Package/appx:Identity', $ns)
    if ($null -eq $identity) {
        Fail 'Identity is missing from AppxManifest.xml.'
    }

    $resources = @($manifest.SelectNodes('/appx:Package/appx:Resources/appx:Resource', $ns) |
        ForEach-Object { $_.GetAttribute('Language').Trim() })
    $uniqueResources = @($resources | Sort-Object -Unique)
    $expected = @($ExpectedLanguages | ForEach-Object { $_.Trim() } | Sort-Object -Unique)
    $missing = @($expected | Where-Object { $uniqueResources -notcontains $_ })
    $extra = @($uniqueResources | Where-Object { $expected -notcontains $_ })

    if ($resources.Count -ne $uniqueResources.Count) {
        Fail "Duplicate language entries in the manifest: $($resources -join ', ')"
    }
    if ($resources.Count -eq 0 -or $resources[0] -ne 'en-US') {
        Fail "English (en-US) must be the first language in the manifest, found: $($resources[0])"
    }
    if ($missing.Count -gt 0) {
        Fail "Missing languages in the AppX: $($missing -join ', ')"
    }
    if ($extra.Count -gt 0) {
        Fail "Unexpected languages in the AppX: $($extra -join ', ')"
    }
    $identityName = $identity.GetAttribute('Name')
    $identityPublisher = $identity.GetAttribute('Publisher')
    $identityArchitecture = $identity.GetAttribute('ProcessorArchitecture')
    $identityVersion = $identity.GetAttribute('Version')

    if ($identityName -ne $storeConfig.identityName) {
        Fail "Identity.Name does not match: $identityName instead of $($storeConfig.identityName)"
    }
    if ($identityPublisher -ne $storeConfig.publisher) {
        Fail "Identity.Publisher does not match: $identityPublisher instead of $($storeConfig.publisher)"
    }
    if ($identityArchitecture -ne 'x64') {
        Fail "ProcessorArchitecture is $identityArchitecture, expected x64."
    }
    if (-not $identityVersion.StartsWith("$($packageJson.version).")) {
        Fail "Package version $identityVersion does not match package.json $($packageJson.version)."
    }

    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host 'AppX manifest OK'
    Write-Host "  File: $Path"
    Write-Host "  Identity: $identityName"
    Write-Host "  Version: $identityVersion"
    Write-Host "  Architecture: $identityArchitecture"
    Write-Host "  Languages: $($uniqueResources -join ', ')"
    Write-Host "  SHA256: $hash"
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
