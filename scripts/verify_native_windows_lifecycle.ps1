# PowerShell Native Windows Lifecycle Verification Harness
# Tests live HWND discovery, WM_CLOSE interception, close-to-tray, and tray menu termination

$ErrorActionPreference = "Stop"

$code = @"
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class Win32Helper {
    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    public static List<IntPtr> GetProcessWindows(uint pid) {
        List<IntPtr> windows = new List<IntPtr>();
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            uint windowPid;
            GetWindowThreadProcessId(hWnd, out windowPid);
            if (windowPid == pid) {
                windows.Add(hWnd);
            }
            return true;
        }, IntPtr.Zero);
        return windows;
    }
}
"@

if (-not ([System.Management.Automation.PSTypeName]'Win32Helper').Type) {
    Add-Type -TypeDefinition $code -Language CSharp
}

$exePath = "frontend\flutter\apps\desktop\build\windows\x64\runner\Debug\ai_companion_desktop.exe"
if (-not (Test-Path $exePath)) {
    Write-Error "Executable not found at $exePath"
}

Write-Host "============================================================"
Write-Host "TEST 1: LIVE HWND WM_CLOSE INTERCEPTION & CLOSE-TO-TRAY"
Write-Host "============================================================"

$proc = Start-Process -FilePath $exePath -PassThru
Write-Host "[1.1] Process started with PID: $($proc.Id)"

# Wait for top-level window to become visible
$targetHwnd = [IntPtr]::Zero
$windowTitle = ""
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 500
    $hwnds = [Win32Helper]::GetProcessWindows($proc.Id)
    foreach ($h in $hwnds) {
        if ([Win32Helper]::IsWindowVisible($h)) {
            $sb = New-Object System.Text.StringBuilder 256
            [Win32Helper]::GetWindowText($h, $sb, 256) | Out-Null
            $targetHwnd = $h
            $windowTitle = $sb.ToString()
            break
        }
    }
    if ($targetHwnd -ne [IntPtr]::Zero) { break }
}

if ($targetHwnd -eq [IntPtr]::Zero) {
    Stop-Process -Id $proc.Id -Force
    Write-Error "FATAL: Could not locate visible window for process $($proc.Id)"
}

Write-Host "[1.2] Live window located: HWND = $targetHwnd, Title = '$windowTitle'"
$initialVis = [Win32Helper]::IsWindowVisible($targetHwnd)
Write-Host "[1.3] Initial window visibility: $initialVis (Must be True)"
Write-Host "[1.4] Initial process running: $(-not $proc.HasExited) (Must be True)"

Write-Host "`n[1.5] Delivering native WM_CLOSE (0x0010) message directly to HWND $targetHwnd..."
$postResult = [Win32Helper]::PostMessage($targetHwnd, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
Write-Host "[1.6] PostMessage returned: $postResult"

Start-Sleep -Milliseconds 1500

$visAfterClose = [Win32Helper]::IsWindowVisible($targetHwnd)
$procRunningAfterClose = -not $proc.HasExited

Write-Host "[1.7] Window visibility after WM_CLOSE: $visAfterClose (Must be False - hidden to tray)"
Write-Host "[1.8] Process running after WM_CLOSE: $procRunningAfterClose (Must be True - survived)"

Write-Host "`n[1.9] Restoring window from tray via ShowWindowAsync..."
[Win32Helper]::ShowWindowAsync($targetHwnd, 1) | Out-Null
Start-Sleep -Milliseconds 1000

$visAfterRestore = [Win32Helper]::IsWindowVisible($targetHwnd)
Write-Host "[1.10] Window visibility after restore: $visAfterRestore (Must be True - restored from tray)"

# Verify assertions for Test 1
if ($initialVis -ne $true -or $visAfterClose -ne $false -or $procRunningAfterClose -ne $true -or $visAfterRestore -ne $true) {
    Stop-Process -Id $proc.Id -Force
    Write-Error "FAIL: WM_CLOSE interception or restore failed!"
}
Write-Host ">>> TEST 1 RESULT: PASSED (WM_CLOSE delivered to live HWND, window hidden, process survived in tray, restored)"

# Clean up Test 1 process
Stop-Process -Id $proc.Id -Force
Start-Sleep -Milliseconds 1000

Write-Host "`n============================================================"
Write-Host "TEST 2: TRAY-MENU-TRIGGERED TERMINATION (--test-tray-exit)"
Write-Host "============================================================"

$trayProc = Start-Process -FilePath $exePath -ArgumentList "--test-tray-exit" -PassThru
Write-Host "[2.1] Process started with PID: $($trayProc.Id)"
$exited = $trayProc.WaitForExit(10000)
Write-Host "[2.2] Process exited within timeout: $exited"
Write-Host "[2.3] Process ExitCode: $($trayProc.ExitCode) (Must be 0)"

if (-not $exited -or $trayProc.ExitCode -ne 0) {
    if (-not $trayProc.HasExited) { Stop-Process -Id $trayProc.Id -Force }
    Write-Error "FAIL: Tray exit handler failed!"
}
Write-Host ">>> TEST 2 RESULT: PASSED (Tray menu 'Exit Companion' cleanly terminated process with exit code 0)"

Write-Host "`n============================================================"
Write-Host "TEST 3: DIRECT GRACEFUL TERMINATION (--test-graceful-exit)"
Write-Host "============================================================"

$graceProc = Start-Process -FilePath $exePath -ArgumentList "--test-graceful-exit" -PassThru
Write-Host "[3.1] Process started with PID: $($graceProc.Id)"
$exitedGrace = $graceProc.WaitForExit(10000)
Write-Host "[3.2] Process exited within timeout: $exitedGrace"
Write-Host "[3.3] Process ExitCode: $($graceProc.ExitCode) (Must be 0)"

if (-not $exitedGrace -or $graceProc.ExitCode -ne 0) {
    if (-not $graceProc.HasExited) { Stop-Process -Id $graceProc.Id -Force }
    Write-Error "FAIL: Graceful exit handler failed!"
}
Write-Host ">>> TEST 3 RESULT: PASSED (Graceful shutdown completed with exit code 0)"

Write-Host "`n============================================================"
Write-Host "ALL NATIVE WINDOWS LIFECYCLE ACCEPTANCE TESTS PASSED"
Write-Host "============================================================"
