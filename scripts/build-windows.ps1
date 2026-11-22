[CmdletBinding()]
param(
    [string]$DefinesFile = 'secrets.json',
    [ValidateSet('Release', 'Debug')]
    [string]$Mode = 'Debug'
)

$ErrorActionPreference = 'Stop'

# Resolve the config path before switching to the repository root for Flutter.
$definesPath = (Resolve-Path -LiteralPath $DefinesFile).ProviderPath
$repoRoot = Split-Path -Parent $PSScriptRoot

Push-Location -LiteralPath $repoRoot
try {
    $buildFlag = '--' + $Mode.ToLowerInvariant()
    & flutter build windows $buildFlag "--dart-define-from-file=$definesPath"
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter build failed (exit code $LASTEXITCODE)."
    }

    $executablePath = Join-Path 'build\windows\x64\runner' "$Mode\tavli.exe"
    $executable = (Resolve-Path -LiteralPath $executablePath).ProviderPath
    $protocol = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Classes\tavli')
    try {
        $command = $protocol.CreateSubKey('shell\open\command')
        try {
            $command.SetValue('', ('"{0}" "%1"' -f $executable))
        } finally {
            $command.Dispose()
        }
        $protocol.SetValue('', 'URL:Tavli Protocol')
        $protocol.SetValue('URL Protocol', '')
    } finally {
        $protocol.Dispose()
    }

    Write-Host "Registered tavli:// for $executable"
} finally {
    Pop-Location
}
