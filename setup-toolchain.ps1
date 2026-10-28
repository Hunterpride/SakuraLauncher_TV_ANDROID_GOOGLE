# One-time setup: unpack JDK + Android build tools locally (no admin needed).
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$tc   = "$root\toolchain"
$sdk  = "$tc\android-sdk"

if (-not (Test-Path "$tc\jdk17")) {
    if (-not (Test-Path "$tc\jdk17.zip")) { throw "toolchain\jdk17.zip missing (download still running?)" }
    Write-Host "== unpacking JDK"
    Expand-Archive "$tc\jdk17.zip" "$tc\_jdktmp" -Force
    $jd = (Get-ChildItem "$tc\_jdktmp" -Directory | Select-Object -First 1)
    Move-Item $jd.FullName "$tc\jdk17"
    Remove-Item "$tc\_jdktmp" -Recurse -Force
}

if (-not (Test-Path "$sdk\cmdline-tools\latest")) {
    if (-not (Test-Path "$tc\cmdtools.zip")) { throw "toolchain\cmdtools.zip missing (download still running?)" }
    Write-Host "== unpacking Android cmdline-tools"
    Expand-Archive "$tc\cmdtools.zip" "$tc\_cttmp" -Force
    New-Item -ItemType Directory -Force "$sdk\cmdline-tools" | Out-Null
    Move-Item "$tc\_cttmp\cmdline-tools" "$sdk\cmdline-tools\latest"
    Remove-Item "$tc\_cttmp" -Recurse -Force
}

$env:JAVA_HOME = "$tc\jdk17"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$sdkm = "$sdk\cmdline-tools\latest\bin\sdkmanager.bat"

if (-not (Test-Path "$sdk\platforms\android-34")) {
    Write-Host "== accepting licenses"
    (1..40 | ForEach-Object { 'y' }) | & $sdkm --licenses | Out-Null
    Write-Host "== installing platform-tools, android-34 platform, build-tools 34 (few minutes)"
    & $sdkm "platform-tools" "platforms;android-34" "build-tools;34.0.0"
}

if (-not (Test-Path "$sdk\platforms\android-34\android.jar")) { throw "platform install failed" }
Write-Host "toolchain ready -> $sdk"
