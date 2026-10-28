# SakuraOS clean-exit: removes the launcher and restores everything it touched.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File SakuraOS\unship.ps1
#        (optional) -Target 192.168.31.113 -Port 33905
param(
    [string]$Target = "192.168.31.113",
    [int]$Port = 0
)
$ErrorActionPreference = 'Continue'
$adb = Join-Path $PSScriptRoot 'toolchain\android-sdk\platform-tools\adb.exe'

$ports = if ($Port -gt 0) { @($Port) } else { @(33905, 5555) }
$connected = $null
foreach ($p in $ports) {
    $addr = "${Target}:$p"
    Write-Host "== connect $addr   (watch the TV: press OK on the debug prompt)"
    & $adb connect $addr
    Start-Sleep -Seconds 2
    $line = (@(& $adb devices) -like "$addr*") -join ''
    if ($line -match '\bdevice\b') { $connected = $addr; break }
    Write-Host "-- $addr not ready yet"
}
if (-not $connected) {
    Write-Host 'Could not connect - re-run when the TV debug prompt is up.'
    exit 1
}

Write-Host "== clearing SakuraOS's granted overlay op"
& $adb shell appops set tv.sakura.launcher SYSTEM_ALERT_WINDOW default

Write-Host "== restoring system defaults (animation scales)"
& $adb shell settings put global window_animation_scale 1.0
& $adb shell settings put global transition_animation_scale 1.0
& $adb shell settings put global animator_duration_scale 1.0

Write-Host "== re-enabling the components SakuraOS disabled"
& $adb shell pm enable com.google.android.apps.tv.launcherx
& $adb shell pm enable com.google.android.katniss
& $adb shell pm enable com.android.adservices.api
& $adb shell pm enable com.google.android.tungsten.setupwraith

Write-Host "== uninstalling SakuraOS"
& $adb uninstall tv.sakura.launcher

Write-Host ''
Write-Host 'Done - the TV is back to stock. One last step, on the remote:'
Write-Host '  Press HOME once and pick "Google TV launcher" as Always'
Write-Host '  (Android shows the home picker after a home app is removed).'
Write-Host 'Re-install any time with SakuraOS\ship.ps1 - zero residue either way.'
