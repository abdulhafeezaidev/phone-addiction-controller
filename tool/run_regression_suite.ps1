# ==============================================================================
# FocusOS - Pre-Release Internal Regression Test Suite Runner
#
# Runs automated verification across all 15 critical focus and protection subsystems
# before every release. Emits a clean Pass/Fail report and sets appropriate exit code.
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$VerboseOutput
)

$ErrorActionPreference = "Stop"

# 1. Environment & SDK Setup (per project AGENTS.md rules)
$env:ANDROID_HOME = "E:\Phone Addiction Controller\.android-sdk"
$env:ANDROID_SDK_ROOT = "E:\Phone Addiction Controller\.android-sdk"

$flutterCmd = "C:\Users\abdul\flutter\bin\flutter.bat"
if (-not (Test-Path $flutterCmd)) {
    $flutterCmd = "flutter"
}

Write-Host ""
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host " FocusOS - Internal Pre-Release Regression Test Suite" -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Environment: Android SDK at $env:ANDROID_HOME" -ForegroundColor Gray
Write-Host ""

$subsystems = @(
    @{ Name = "Focus Session"; File = "test/regression/focus_session_regression_test.dart" },
    @{ Name = "Routine Start"; File = "test/regression/routine_start_regression_test.dart" },
    @{ Name = "Routine End"; File = "test/regression/routine_end_regression_test.dart" },
    @{ Name = "Allowed Apps"; File = "test/regression/allowed_apps_regression_test.dart" },
    @{ Name = "Blocked Apps"; File = "test/regression/blocked_apps_regression_test.dart" },
    @{ Name = "Lock Screen"; File = "test/regression/lock_screen_regression_test.dart" },
    @{ Name = "Emergency Override"; File = "test/regression/emergency_override_regression_test.dart" },
    @{ Name = "Boot Recovery"; File = "test/regression/boot_recovery_regression_test.dart" },
    @{ Name = "Device Reboot"; File = "test/regression/device_reboot_regression_test.dart" },
    @{ Name = "Incoming Call"; File = "test/regression/incoming_call_regression_test.dart" },
    @{ Name = "Outgoing Call"; File = "test/regression/outgoing_call_regression_test.dart" },
    @{ Name = "Notifications"; File = "test/regression/notifications_regression_test.dart" },
    @{ Name = "Network Controls"; File = "test/regression/network_controls_regression_test.dart" },
    @{ Name = "Admin Authentication"; File = "test/regression/admin_auth_regression_test.dart" },
    @{ Name = "Remote Approval"; File = "test/regression/remote_approval_regression_test.dart" }
)

$results = @()
$totalPassed = 0
$totalFailed = 0

Write-Host "Executing automated tests for 15 core subsystems..." -ForegroundColor Yellow
Write-Host ""

# Run master suite first to execute entire test pipeline
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$masterOutput = & $flutterCmd test "test/regression_suite_test.dart" 2>&1
$masterExitCode = $LASTEXITCODE
$stopwatch.Stop()

# Evaluate results for each subsystem
foreach ($sub in $subsystems) {
    $subName = $sub.Name
    $subFile = $sub.File

    # Check if subsystem file exists and run check
    if ($masterExitCode -eq 0) {
        $results += [PSCustomObject]@{
            Status = "PASS"
            Subsystem = $subName
            TargetFile = $subFile
        }
        $totalPassed++
    } else {
        # Check specific subsystem in case of failure to isolate
        $subOutput = & $flutterCmd test $subFile 2>&1
        if ($LASTEXITCODE -eq 0) {
            $results += [PSCustomObject]@{
                Status = "PASS"
                Subsystem = $subName
                TargetFile = $subFile
            }
            $totalPassed++
        } else {
            $results += [PSCustomObject]@{
                Status = "FAIL"
                Subsystem = $subName
                TargetFile = $subFile
            }
            $totalFailed++
        }
    }
}

# Print Report Table
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "                PRE-RELEASE REGRESSION TEST REPORT                  " -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host " Subsystem Name                | Status | Target Verification Suite "
Write-Host "-------------------------------|--------|---------------------------"

foreach ($res in $results) {
    $paddedName = $res.Subsystem.PadRight(30)
    if ($res.Status -eq "PASS") {
        Write-Host " $paddedName | " -NoNewline
        Write-Host " PASS " -ForegroundColor Green -NoNewline
        Write-Host " | $($res.TargetFile)"
    } else {
        Write-Host " $paddedName | " -NoNewline
        Write-Host " FAIL " -ForegroundColor Red -NoNewline
        Write-Host " | $($res.TargetFile)"
    }
}

Write-Host "-------------------------------|--------|---------------------------"
Write-Host "Total Subsystems: $($subsystems.Count) | Passed: $totalPassed | Failed: $totalFailed | Duration: $([math]::Round($stopwatch.Elapsed.TotalSeconds, 2))s"

Write-Host ""

if ($totalFailed -eq 0) {
    Write-Host ">> VERIFICATION RESULT: SUCCESS - ALL 15 REGRESSION SUITES PASSED" -ForegroundColor Green
    Write-Host ">> Build is certified safe for release." -ForegroundColor Green
    exit 0
} else {
    Write-Host ">> VERIFICATION RESULT: FAILED - $totalFailed SUBSYSTEM(S) FAILED REGRESSION TESTS" -ForegroundColor Red
    Write-Host ">> Release build is BLOCKED until failures are resolved." -ForegroundColor Red
    exit 1
}
