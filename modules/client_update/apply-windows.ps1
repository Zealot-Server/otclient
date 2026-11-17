param(
    [Parameter(Mandatory=$true)][int]$ClientPid,
    [Parameter(Mandatory=$true)][string]$Archive,
    [Parameter(Mandatory=$true)][string]$WorkDir,
    [Parameter(Mandatory=$true)][string]$ExpectedSha256
)
$ErrorActionPreference = 'Stop'
$Log = Join-Path (Split-Path $Archive -Parent) 'install.log'
try {
    $process = Get-Process -Id $ClientPid -ErrorAction SilentlyContinue
    if ($process) { $process.WaitForExit(120000) | Out-Null }
    if (Get-Process -Id $ClientPid -ErrorAction SilentlyContinue) {
        throw 'The client did not exit in time.'
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Archive).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedSha256.ToLowerInvariant()) { throw 'Package checksum mismatch.' }

    $target = $WorkDir.TrimEnd([char[]]@('/', '\'))
    $parent = Split-Path $target -Parent
    Set-Location -LiteralPath $env:TEMP
    $stage = Join-Path $parent ('.zealot-update.' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage | Out-Null
    Expand-Archive -LiteralPath $Archive -DestinationPath $stage
    $new = Join-Path $stage 'Zealot Client'
    if (-not (Test-Path -LiteralPath (Join-Path $new 'Zealot Client.exe')) -or
        -not (Test-Path -LiteralPath (Join-Path $new 'init.lua'))) {
        throw 'The package is incomplete.'
    }
    if (-not (Test-Path -LiteralPath $target -PathType Container)) {
        throw 'The current installation was not found.'
    }
    $backup = $target + '.previous.' + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    Move-Item -LiteralPath $target -Destination $backup
    try {
        Move-Item -LiteralPath $new -Destination $target
        Start-Process -FilePath (Join-Path $target 'Zealot Client.exe') -WorkingDirectory $target
    } catch {
        if (Test-Path -LiteralPath $target) { Move-Item -LiteralPath $target -Destination (Join-Path $stage 'failed-client') }
        Move-Item -LiteralPath $backup -Destination $target
        throw
    }
} catch {
    $_ | Out-File -FilePath $Log -Append
    exit 1
} finally {
    if ($stage -and (Test-Path -LiteralPath $stage)) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
