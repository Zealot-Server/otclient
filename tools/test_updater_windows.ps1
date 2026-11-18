$ErrorActionPreference = 'Stop'
$root = Join-Path $env:RUNNER_TEMP ('zealot-updater-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
try {
    $target = Join-Path $root 'installed'
    New-Item -ItemType Directory -Path $target | Out-Null
    Set-Content -LiteralPath (Join-Path $target 'init.lua') -Value 'old'

    $source = Join-Path $root 'source'
    $package = Join-Path $source 'Zealot Client'
    New-Item -ItemType Directory -Path $package | Out-Null
    Set-Content -LiteralPath (Join-Path $package 'init.lua') -Value 'new'
    Set-Content -LiteralPath (Join-Path $package 'Zealot Client.exe') -Value 'fixture'
    $archive = Join-Path $root 'release.zip'
    Compress-Archive -LiteralPath $package -DestinationPath $archive
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant()

    $global:zealotUpdaterStarted = $false
    function global:Start-Process {
        param([string]$FilePath, [string]$WorkingDirectory)
        $global:zealotUpdaterStarted = Test-Path -LiteralPath $FilePath
    }
    & "$PSScriptRoot/../modules/client_update/apply-windows.ps1" -ClientPid 999999 `
        -Archive $archive -WorkDir $target -ExpectedSha256 $hash

    if ((Get-Content -LiteralPath (Join-Path $target 'init.lua') -Raw).Trim() -ne 'new') {
        throw 'Updated package was not installed.'
    }
    if (-not $global:zealotUpdaterStarted) { throw 'Updated executable was not launched.' }
    if (-not (Get-ChildItem -Path $root -Directory -Filter 'installed.previous.*')) {
        throw 'Previous version backup was not retained.'
    }
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force
}
