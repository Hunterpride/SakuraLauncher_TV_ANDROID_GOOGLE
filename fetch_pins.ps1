$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Drawing

$project = "C:\Users\ARNAV\Documents\Default Project"
$out = Join-Path $project "SakuraOS\src\res\drawable-nodpi"
$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
$curl = "C:\Windows\System32\curl.exe"

$pinIds = @(
    "731060952053738738",
    "1142647736735637602",
    "426082814768969417",
    "978970037772913444",
    "1038431626636420695"
)

$n = 0
$failed = @()

$api = "https://widgets.pinterest.com/v3/pidgets/pins/info/?pin_ids=" + ($pinIds -join ",")
$pinsBy = @{}
try {
    $r = Invoke-RestMethod -Uri $api -UserAgent $UA -TimeoutSec 30
    if ($r.data -is [array]) { foreach ($p in $r.data) { $pinsBy[[string]$p.id] = $p } }
    elseif ($r.data.pins) { foreach ($p in $r.data.pins) { $pinsBy[[string]$p.id] = $p } }
    Write-Host ("pidgets returned " + $pinsBy.Count + " pins")
} catch { Write-Host ("PINGETS FAIL: " + $_.Exception.Message) }

foreach ($id in $pinIds) {
    $n = $n + 1
    $name = "wp_pin$n"
    $dest = Join-Path $out ($name + ".jpg")
    if (Test-Path $dest) { Write-Host ("HAVE " + $name); continue }

    $desc = ""; $u = $null
    if ($pinsBy.ContainsKey($id)) {
        $p = $pinsBy[$id]
        if ($p.description) { $desc = ([string]$p.description).Substring(0, [Math]::Min(90, ([string]$p.description).Length)) }
        $img = $p.images.orig
        if (-not $img) { $img = $p.images."736x" }
        if (-not $img) { $img = $p.images."564x" }
        if (-not $img) { $img = $p.images."236x" }
        if ($img) { $u = [string]$img.url }
    }
    if (-not $u) {
        try {
            $html = (& $curl -s -L -A $UA --max-time 30 ("https://www.pinterest.com/pin/" + $id + "/"))
            $m = [regex]::Match(($html | Out-String), '<meta[^>]+property="og:image"[^>]+content="([^"]+)"')
            if ($m.Success) { $u = $m.Groups[1].Value -replace "&amp;", "&" }
        } catch {}
    }
    if (-not $u) { Write-Host ("FAIL pin " + $id + ": no image url"); $failed += $id; continue }

    # Resolution ladder — same hex path serves at bigger sizes; originals is full-res.
    $variants = New-Object System.Collections.Generic.List[string]
    $m2 = [regex]::Match($u, 'i\.pinimg\.com/[0-9]+x/([0-9a-f]{2}/[0-9a-f]{2}/[0-9a-f]{2}/[0-9a-f]+)\.(jpg|jpeg|png|gif|webp)')
    if ($m2.Success) {
        $hex = $m2.Groups[1].Value; $ext = $m2.Groups[2].Value
        $variants.Add("https://i.pinimg.com/originals/" + $hex + "." + $ext)
        $variants.Add("https://i.pinimg.com/1200x/" + $hex + "." + $ext)
        $variants.Add("https://i.pinimg.com/736x/" + $hex + "." + $ext)
        $variants.Add($u)
    } else {
        $variants.Add($u)
    }
    Write-Host ("== pin " + $id + "  variants: " + $variants.Count)
    if ($desc) { Write-Host ("   desc: " + $desc) }

    $ok = $false
    foreach ($u2 in $variants) {
        if ($ok) { break }
        $tmp = Join-Path $env:TEMP ($name + ".raw")
        try {
            Write-Host ("   GET " + $u2)
            $code = (& $curl -s -o $tmp -w "%{http_code}" -L -A $UA -H "Referer: https://www.pinterest.com/" --max-time 90 $u2)
            if ($LASTEXITCODE -ne 0 -or "$code" -ne "200") { throw ("curl failed code=" + $code + " exit=" + $LASTEXITCODE) }
            $rawSz = (Get-Item $tmp).Length
            Write-Host ("      -> HTTP 200, " + $rawSz + " bytes")
            if ($rawSz -lt 20000) { throw "suspiciously small file" }

            $img = [System.Drawing.Image]::FromFile($tmp)
            $iw = $img.Width; $ih = $img.Height
            $img.Dispose()
            Write-Host ("      dims " + $iw + "x" + $ih)
            if ($iw -lt 700 -and $u2 -ne $variants[$variants.Count - 1]) { throw ("too small " + $iw + "x" + $ih) }

            $scale = [Math]::Min(1.0, 1920.0 / [Math]::Max($iw, $ih))
            $nw = [int]($iw * $scale); $nh = [int]($ih * $scale)
            $img = [System.Drawing.Image]::FromFile($tmp)
            $bmp = New-Object System.Drawing.Bitmap($nw, $nh)
            $gfx = [System.Drawing.Graphics]::FromImage($bmp)
            $gfx.InterpolationMode = 'HighQualityBicubic'
            $gfx.DrawImage($img, 0, 0, $nw, $nh)
            $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
            $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
            $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 82L)
            $bmp.Save($dest, $enc, $ep)
            $gfx.Dispose(); $bmp.Dispose(); $img.Dispose()
            Remove-Item $tmp -ErrorAction SilentlyContinue
            Write-Host ("   SAVED $name.jpg  " + (Get-Item $dest).Length + " bytes")
            Write-Host ("   SOURCE " + $u2)
            $ok = $true
        } catch {
            Write-Host ("   retry-next (" + $_.Exception.Message + ")")
            Remove-Item $tmp -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }
    }
    if (-not $ok) { Write-Host ("   DLFAIL pin " + $id); $failed += $id }
    Start-Sleep -Seconds 2
}
Write-Host "--- directory:"
Get-ChildItem $out | ForEach-Object { Write-Host ("   " + $_.Name + "  " + $_.Length) }
if ($failed.Count -gt 0) { Write-Host ("FAILED PIN IDS: " + ($failed -join ",")) }
