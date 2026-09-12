<#
.SYNOPSIS
    Starts the local llama.cpp model server with Vulkan GPU offload for AMD RX 580.
.DESCRIPTION
    Launches llama-server.exe targeting the downloaded GGUF model in models/
    using Vulkan acceleration on the AMD Radeon RX 580 (Section 11-13).
#>

[CmdletBinding()]
param (
    [string]$ModelFile = "Qwen2.5-7B-Instruct-Q4_K_M.gguf",
    [int]$Port = 8080,
    [int]$GpuLayers = 28,
    [int]$ContextSize = 4096,
    [int]$Threads = 6
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$ServerExe = Join-Path $ProjectRoot "bin\llama-server.exe"
$ModelPath = Join-Path $ProjectRoot "models\$ModelFile"

if (-not (Test-Path $ServerExe)) {
    Write-Error "llama-server.exe not found at $ServerExe. Please ensure bin/ contains llama-server."
    exit 1
}

if (-not (Test-Path $ModelPath)) {
    # Check if any .gguf exists in models/
    $Fallback = Get-ChildItem -Path (Join-Path $ProjectRoot "models") -Filter "*.gguf" | Where-Object { $_.Name -ne "lfs-test.gguf" -and $_.Length -gt 100MB } | Select-Object -First 1
    if ($Fallback) {
        $ModelPath = $Fallback.FullName
        Write-Host "Default model not found; using detected model: $($Fallback.Name)" -ForegroundColor Yellow
    } else {
        Write-Error "No model found at $ModelPath. Please place your .gguf file into models/."
        exit 1
    }
}

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " Starting Local AI Model Server (Track B4)       " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " Model:       $ModelPath" -ForegroundColor White
Write-Host " GPU Offload: $GpuLayers layers to Vulkan0 (AMD RX 580)" -ForegroundColor Green
Write-Host " Context:     $ContextSize tokens" -ForegroundColor White
Write-Host " Endpoint:    http://127.0.0.1:$Port/v1" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop the model server.`n" -ForegroundColor DarkGray

& $ServerExe -m $ModelPath --port $Port -ngl $GpuLayers -c $ContextSize -t $Threads --host 127.0.0.1
