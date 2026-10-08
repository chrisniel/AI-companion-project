# PowerShell Native Windows Visual Evidence Capture Script
# Milestone M1 Batch 3: SoftGlass Desktop Design System, Navigation Shell & Storage Diagnostics
# Captures 7 canonical views + 1 alternate accent view into $env:TEMP\ai_companion_visual_review

$ErrorActionPreference = "Stop"

$exePath = "frontend\flutter\apps\desktop\build\windows\x64\runner\Debug\ai_companion_desktop.exe"
if (-not (Test-Path $exePath)) {
    Write-Error "Executable not found at $exePath. Run 'flutter build windows --debug' first."
}

$outputDir = Join-Path $env:TEMP "ai_companion_visual_review"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Write-Host "============================================================"
Write-Host "M1 BATCH 3 VISUAL EVIDENCE CAPTURE"
Write-Host "Executable: $exePath"
Write-Host "Output Directory: $outputDir"
Write-Host "============================================================"

# Launch real compiled binary with --capture-visual-evidence harness flag
Write-Host "`nLaunching desktop binary to render all 8 visual review views..."
$proc = Start-Process -FilePath $exePath -ArgumentList "--capture-visual-evidence --output-dir=$outputDir" -PassThru

# Wait for capture sequence to complete
$timeoutSec = 30
$sw = [System.Diagnostics.Stopwatch]::StartNew()
while (-not $proc.HasExited -and $sw.Elapsed.TotalSeconds -lt $timeoutSec) {
    Start-Sleep -Milliseconds 500
}

if (-not $proc.HasExited) {
    Stop-Process -Id $proc.Id -Force
    Write-Error "Visual capture process timed out after $timeoutSec seconds."
}

Write-Host "Visual capture process completed with exit code: $($proc.ExitCode)"

$expectedViews = @(
    "01_dark_oceansky_chat_expanded_1280x800.png",
    "02_light_oceansky_chat_expanded_1280x800.png",
    "03_dark_settings_appearance_1280x800.png",
    "04_dark_settings_diagnostics_1280x800.png",
    "05_dark_chat_collapsed_1280x800.png",
    "06_dark_chat_expanded_1024x640.png",
    "07_light_settings_1024x640.png",
    "08_dark_amethyst_chat_1280x800.png"
)

Write-Host "`n============================================================"
Write-Host "VERIFYING GENERATED SCREENSHOTS"
Write-Host "============================================================"

$allPresent = $true
foreach ($view in $expectedViews) {
    $filePath = Join-Path $outputDir $view
    if (Test-Path $filePath) {
        $item = Get-Item $filePath
        Write-Host "  [OK] $view ($($item.Length) bytes)"
    } else {
        Write-Host "  [MISSING] $view"
        $allPresent = $false
    }
}

if (-not $allPresent) {
    Write-Error "One or more expected visual review screenshots are missing."
}

Write-Host "`nAll 8 visual review screenshots verified in $outputDir (strictly outside Git)."
Write-Host "============================================================"
