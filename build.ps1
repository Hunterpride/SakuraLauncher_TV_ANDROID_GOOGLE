# SakuraOS build — pure Android toolchain, no Gradle, no dependencies.
# Requires: toolchain\ (run setup-toolchain.ps1 once first)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$tc   = "$root\toolchain"
$bt   = "$tc\android-sdk\build-tools\34.0.0"
$plat = "$tc\android-sdk\platforms\android-34"
$out  = "$root\build"

if (-not (Test-Path "$bt\aapt2.exe")) { throw "Android build-tools missing. Run setup-toolchain.ps1 first." }

# locate a JDK 17+ installed by setup
$jdk = Get-ChildItem $tc -Directory | Where-Object { $_.Name -match '^jdk' } | Select-Object -First 1
if (-not $jdk) { throw "JDK not found in toolchain. Run setup-toolchain.ps1 first." }
$env:JAVA_HOME = $jdk.FullName
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

foreach ($sub in 'res.zip','base.apk','aligned.apk','SakuraOS.apk') { Remove-Item "$out\$sub" -ErrorAction SilentlyContinue }
Remove-Item "$out\gen","$out\classes","$out\dex" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$out\gen","$out\classes","$out\dex" | Out-Null

Write-Host "== aapt2: compile + link resources"
& "$bt\aapt2.exe" compile --dir "$root\src\res" -o "$out\res.zip"
if ($LASTEXITCODE -ne 0) { throw "aapt2 compile failed" }
& "$bt\aapt2.exe" link -o "$out\base.apk" -I "$plat\android.jar" `
    --manifest "$root\src\AndroidManifest.xml" `
    --min-sdk-version 22 --target-sdk-version 34 `
    --version-code 1 --version-name 1.0 `
    --java "$out\gen" `
    "$out\res.zip"
if ($LASTEXITCODE -ne 0) { throw "aapt2 link failed" }

Write-Host "== javac: compile java"
$srcFiles = @(Get-ChildItem -Recurse "$root\src\java","$out\gen" -Filter *.java).FullName
& javac.exe -encoding UTF-8 -source 8 -target 8 -nowarn `
    -bootclasspath "$plat\android.jar" -d "$out\classes" $srcFiles
if ($LASTEXITCODE -ne 0) { throw "javac failed" }

Write-Host "== d8: dex"
$cls = @(Get-ChildItem -Recurse "$out\classes" -Filter *.class).FullName
& "$bt\d8.bat" --release --min-api 22 --lib "$plat\android.jar" --output "$out\dex" $cls
if ($LASTEXITCODE -ne 0) { throw "d8 failed" }

Write-Host "== merge classes.dex into apk"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open("$out\base.apk", 'Update')
try {
    $e = $zip.GetEntry('classes.dex'); if ($e) { $e.Delete() }
    $ne = $zip.CreateEntry('classes.dex', [System.IO.Compression.CompressionLevel]::Optimal)
    $db = [System.IO.File]::ReadAllBytes("$out\dex\classes.dex")
    $s = $ne.Open(); $s.Write($db, 0, $db.Length); $s.Close()
} finally { $zip.Dispose() }

Write-Host "== zipalign"
& "$bt\zipalign.exe" -f 4 "$out\base.apk" "$out\aligned.apk"
if ($LASTEXITCODE -ne 0) { throw "zipalign failed" }

Write-Host "== sign"
$ks = "$root\signing.jks"
if (-not (Test-Path $ks)) {
    & keytool.exe -genkeypair -keystore $ks -storepass sakuraos -keypass sakuraos `
        -alias sakura -keyalg RSA -keysize 2048 -validity 10950 `
        -dname "CN=SakuraOS, O=SakuraTV, C=JP"
    if ($LASTEXITCODE -ne 0) { throw "keytool failed" }
}
& "$bt\apksigner.bat" sign --ks $ks --ks-pass pass:sakuraos --key-pass pass:sakuraos `
    --out "$out\SakuraOS.apk" "$out\aligned.apk"
if ($LASTEXITCODE -ne 0) { throw "apksigner failed" }
& "$bt\apksigner.bat" verify "$out\SakuraOS.apk"

$kb = [math]::Round((Get-Item "$out\SakuraOS.apk").Length / 1KB)
Write-Host ""
Write-Host "OK  ->  SakuraOS\build\SakuraOS.apk  ($kb KB)"
