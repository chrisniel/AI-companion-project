<#
.SYNOPSIS
    Runs or builds the AI Companion Windows desktop application from repository root.

.DESCRIPTION
    Validates Flutter SDK and Windows desktop tooling, constructs necessary
    runtime parameters (--dart-define), and launches the desktop client.

.PARAMETER HostUrl
    Optional backend host URL (e.g. http://127.0.0.1:8000). Passed as COMPANION_HOST_URL.

.PARAMETER Token
    Optional pairing token. Passed as COMPANION_PAIRING_TOKEN.

.PARAMETER Config
    Optional custom configuration profile name.

.PARAMETER Mode
    Build mode: 'debug' (default), 'profile', or 'release'.

.PARAMETER BuildOnly
    Compile the Windows desktop application without launching it.

.EXAMPLE
    .\scripts\run-desktop.ps1
    .\scripts\run-desktop.ps1 -HostUrl "http://127.0.0.1:8000"
    .\scripts\run-desktop.ps1 -Mode release
    .\scripts\run-desktop.ps1 -BuildOnly
#>

[CmdletBinding()]
param(
    [string]$HostUrl = "",
    [string]$Token = "",
    [string]$Config = "",
    [ValidateSet("debug", "profile", "release")]
    [string]$Mode = "debug",
    [switch]$BuildOnly
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$desktopDir = Join-Path $repoRoot "frontend\flutter\apps\desktop"

if (-not (Test-Path $desktopDir)) {
    Write-Error "Desktop directory not found at: $desktopDir"
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "AI COMPANION - WINDOWS DESKTOP LAUNCHER" -ForegroundColor Cyan
Write-Host "Repository Root: $repoRoot"
Write-Host "Desktop Path:    $desktopDir"
Write-Host "Mode:            $Mode"
if ($HostUrl) { Write-Host "Host URL:        $HostUrl" }
if ($Config)  { Write-Host "Config:          $Config" }
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Check Flutter SDK availability
$flutterCmd = Get-Command "flutter" -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    Write-Error "Flutter SDK not found in PATH. Please install Flutter or add it to PATH."
}
Write-Host "`n[1/3] Flutter SDK located: $($flutterCmd.Source)" -ForegroundColor Green

# 2. Build runtime arguments
$extraArgs = @()
if ($HostUrl) {
    $extraArgs += "--dart-define=COMPANION_HOST_URL=$HostUrl"
}
if ($Token) {
    $extraArgs += "--dart-define=COMPANION_PAIRING_TOKEN=$Token"
}
if ($Config) {
    $extraArgs += "--dart-define=COMPANION_CONFIG=$Config"
}

Push-Location $desktopDir
try {
    if ($BuildOnly) {
        Write-Host "`n[2/3] Building Windows Desktop application ($Mode mode)..." -ForegroundColor Yellow
        $buildArgs = @("build", "windows", "--$Mode") + $extraArgs
        & flutter @buildArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Flutter build failed with exit code $LASTEXITCODE."
        }
        Write-Host "`n[3/3] Windows Desktop build completed successfully." -ForegroundColor Green
    } else {
        Write-Host "`n[2/3] Launching Windows Desktop client ($Mode mode)..." -ForegroundColor Yellow
        $runArgs = @("run", "-d", "windows", "--$Mode") + $extraArgs
        & flutter @runArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Flutter run exited with error code $LASTEXITCODE."
        }
        Write-Host "`n[3/3] Desktop session terminated cleanly." -ForegroundColor Green
    }
} finally {
    Pop-Location
}
