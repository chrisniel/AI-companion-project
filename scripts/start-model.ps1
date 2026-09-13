<#
.SYNOPSIS
    Starts a standalone diagnostic llama.cpp model server for testing (Isolated from Core port 8085).
.DESCRIPTION
    Diagnostic probe utility. Launches llama-server.exe targeting models in models/vision
    using Vulkan acceleration on the AMD Radeon RX 580.
    Default port is 8086 to prevent collision with FastAPI Core's production router on port 8085.
#>

[CmdletBinding()]
param (
    [string]$ModelDir = "models\vision",
    [int]$Port = 8086,
    [int]$GpuLayers = 28,
    [int]$ContextSize = 4096,
    [int]$Threads = 6
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$ServerExe = Join-Path $ProjectRoot "runtime\llama.cpp\llama-server.exe"
$FullModelDir = Join-Path $ProjectRoot $ModelDir

if (-not (Test-Path $ServerExe)) {
    Write-Error "llama-server.exe not found at $ServerExe. Please ensure runtime/llama.cpp/ contains llama.cpp binaries."
    exit 1
}

if (-not (Test-Path $FullModelDir)) {
    Write-Error "Model directory not found at $FullModelDir."
    exit 1
}

# Production collision guard: Do not hijack port 8085
if ($Port -eq 8085) {
    $occupied = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -eq 8085 }
    if ($occupied) {
        Write-Error "Port 8085 is currently occupied by FastAPI Core production router. Standalone diagnostic probes must use port 8086 (or another unassigned port) to prevent dual-process collision."
        exit 1
    }
}

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " Diagnostic Standalone Router Probe (AMD RX 580) " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " Models Dir:  $FullModelDir" -ForegroundColor White
Write-Host " Port:        $Port (Isolated diagnostic port)" -ForegroundColor Green
Write-Host " GPU Offload: $GpuLayers layers to Vulkan (AMD RX 580)" -ForegroundColor Green
Write-Host " Context:     $ContextSize tokens" -ForegroundColor White
Write-Host " Endpoint:    http://127.0.0.1:$Port/v1" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop the diagnostic server.`n" -ForegroundColor DarkGray

& $ServerExe --models-dir $FullModelDir --port $Port -ngl $GpuLayers -c $ContextSize -t $Threads --host 127.0.0.1 --models-max 1 --no-webui
