# SakuraOS ship — connect, install, set as default home, launch.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File SakuraOS\ship.ps1
#        (optional) -Target 192.168.31.113 -Port 33905
param(
    [string]$Target = "192.168.31.113",
    [int]$Port = 0
)
$ErrorActionPreference = 'Continue'
$adb = Join-Path $PSScriptRoot 'toolchain\android-sdk\platform-tools\adb.exe'
$apk = Join-Path $PSScriptRoot 'build\SakuraOS.apk'

# Try the wireless-debugging port first, then classic network ADB.
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
    Write-Host ''
    Write-Host 'Could not connect. One of these fixes it:'
    Write-Host '  1. TV shows "Allow network debugging?" -> navigate to OK, press center, re-run this script.'
    Write-Host '  2. Android 11+: Developer options -> Wireless debugging -> "Pair device with pairing code",'
    Write-Host '     then:  & this-adb pair <tv-ip>:<pair-port> <6-digit-code>   and re-run with -Port <port>.'
    exit 1
}

Write-Host "== install SakuraOS"
& $adb install -r $apk
if ($LASTEXITCODE -ne 0) { Write-Host 'Install failed - see the error above.'; exit 1 }

# Verified Oct 27: every `install -r` resets SYSTEM_ALERT_WINDOW back to
# "default", which silently blocks the boot-salvage background starts.
# The op must be re-granted after every install.
Write-Host "== re-grant SYSTEM_ALERT_WINDOW (every reinstall resets it)"
& $adb shell appops set tv.sakura.launcher SYSTEM_ALERT_WINDOW allow

Write-Host "== set SakuraOS as default home"
& $adb shell cmd package set-home-activity tv.sakura.launcher/.HomeActivity

# The firmware re-arms its setup wizard at every power-on; disable it for this
# session whenever the install lands while it is enabled again (idempotent).
Write-Host "== disable vendor setup wizard for this session"
& $adb shell pm disable-user --user 0 com.google.android.tungsten.setupwraith

Write-Host "== open the home screen"
& $adb shell am start -n tv.sakura.launcher/.HomeActivity

Write-Host ''
Write-Host 'If the TV did not switch automatically:'
Write-Host '  Press HOME on the remote  ->  pick SakuraOS  ->  Always.'
Write-Host 'Fallback inside the app: Sakura Settings -> Choose default home app.'
