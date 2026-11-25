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
    # Set-Location changes the PowerShell runspace, not the process-wide native
    # working directory. An inherited handle to $target would block its rename.
    [System.Environment]::CurrentDirectory = $env:TEMP
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
    # Keep installed version directories only when absent from the package.
    foreach ($kind in @('things', 'sounds')) {
        $sourceRoot = Join-Path $target "data/$kind"
        $destRoot = Join-Path $new "data/$kind"
        if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) { continue }
        $rootItem = Get-Item -LiteralPath $sourceRoot -Force
        if ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
        foreach ($dir in Get-ChildItem -LiteralPath $sourceRoot -Directory -Force) {
            if ($dir.Name -notmatch '^[0-9]+$' -or ($dir.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
            $destination = Join-Path $destRoot $dir.Name
            if (-not (Test-Path -LiteralPath $destination)) {
                Copy-Item -LiteralPath $dir.FullName -Destination $destination -Recurse
            }
        }
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
